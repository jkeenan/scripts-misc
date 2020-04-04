#!/usr/bin/env perl
use 5.14.0;
use warnings;
use Carp;
use Cwd;
use File::Spec;
use Getopt::Long;
use Data::Dump ( qw| dd pp| );
use Path::Tiny;
use JSON;
use Text::CSV_XS;

=head1 NAME

analyze-json-logs.pl - Create delimiter-separated value file from directory of JSON files

=head1 SYNOPSIS

    $ perl analyze-json-logs.pl \
        --json_dir=/path/to/directory/for/json/files \
        --verbose

=head1 DESCRIPTION

This is a program which simulates the C<analyze_json_logs()> method of CPAN
module F<Test::Against::Dev>.  It assumes that you have used
F<CPAN::cpanminus::reporter::RetainReports> to parse a F<cpanm> F<build.log>
into individual F<.json> files, one for each module actually reached during a
F<cpanm> run.  The program processes the JSON to create a Perl data structure
and then write a PSV file tabulating the test results.  That PSV file is
similar to the one generated during the monthly CPAN-River-3000 run.

Assumes each F<.json> file has a single JSON hash that looks like this:

    {
      author => "ABH",
      dist => "Mozilla-CA",
      distname => "Mozilla-CA-20180117",
      distversion => 20180117,
      grade => "PASS",
      prereqs => undef,
      test_output => [
        "Building and testing Mozilla-CA-20180117",
        "cp lib/Mozilla/CA.pm blib/lib/Mozilla/CA.pm",
        "cp lib/Mozilla/CA/cacert.pem blib/lib/Mozilla/CA/cacert.pem",
        "cp mk-ca-bundle.pl blib/lib/Mozilla/mk-ca-bundle.pl",
        "PERL_DL_NONLAZY=1 \"/usr/home/jkeenan/testing/smoke-me/jkeenan/gh-16300-module-install/bin/perl\" \"-MExtUtils::Command::MM\" \"-MTest::Harness\" \"-e\" \"undef *Test::Harness::Switches; test_harness(0, 'blib/lib', 'blib/arch')\" t/*.t",
        "t/locate-file.t .. ok",
        "All tests successful.",
        "Files=1, Tests=3,  0 wallclock secs ( 0.01 usr  0.01 sys +  0.02 cusr  0.00 csys =  0.04 CPU)",
        "Result: PASS",
      ],
      via => "App::cpanminus::reporter 0.17 (1.7044)",
    }

The program is currently hard-coded to utilize these 5 elements of the JSON hash:

      author => "ABH",
      dist => "Mozilla-CA",
      distname => "Mozilla-CA-20180117",
      distversion => 20180117,
      grade => "PASS",

The program is currently hard-coded to output these fields in this order:

    dist author distname distversion grade

=head1 PREQREQUISITES

Uses the following non-core CPAN modules:

    Data::Dump
    JSON
    Path::Tiny
    Text::CSV_XS

=head1 USAGE

Call this program with command-line switches.  At the present time there are 5
such switches.

=over 4

=item * C<--json_dir>

Full path to directory holding F<.json> files needing parsing.  Required.

=item * C<--output_dir>

Full path to directory in which output file will be written.  Optional;
defaults to current working directory.

=item * C<--output_label>

String holding the stem of the basename of the output file, I<i.e.,> the part
preceding C<.psv> or C<.csv>.  Optional; defaults to:
C<cpanm_report_YYYYMMDD> (datestamp).

=item * C<--sep_char>

String holding the column-separator character in the output file.  Optional;
defaults to pipe (C<|>); comma may (C<,>) be used.  This also determines the
file extension:  C<.psv> for pipe-delimited; C<.csv> for comma-delimited.

=item * C<--verbose>

Currently a flag turning on verbose output -- but I may switch this to a
number to accommodate different levels of verbosity.

=back

=cut

my ($verbose, $sep_char, $json_dir, $output_dir, $output_label);

GetOptions(
    "json_dir=s"        => \$json_dir,
    "output_dir=s"      => \$output_dir,
    "output_label=s"    => \$output_label,
    "sep_char=s"        => \$sep_char,
    "verbose"           => \$verbose,
) or croak("Error in command-line arguments\n");

$output_dir //= cwd();
for my $dir ($json_dir, $output_dir) {
    croak "Unable to locate $dir" unless -d $dir;
}
unless (defined $output_label) {
    my $stem = 'cpanm_report';
    my @lt = localtime(time);
    my $YYYY = $lt[5] + 1900;
    my $MM = sprintf("%02d" => $lt[4] + 1);
    my $DD = sprintf("%02d" => $lt[3]);
    $output_label = join('_' => $stem, "$YYYY$MM$DD");
}

$sep_char //= '|';
croak "'sep_char' must be either pipe or comma"
    unless ($sep_char eq '|' or $sep_char eq ',');
$verbose //= 0;
my $ext = ($sep_char eq ',') ? '.csv' : '.psv';
my $output_file = "$output_label$ext";
my $foutput_file = File::Spec->catfile($output_dir, $output_file);

if ($verbose) {
    say <<MESSAGE;
JSON files in:      $json_dir
Output in:          $foutput_file
MESSAGE
}

opendir my $DIRH, $json_dir or croak "Unable to open $json_dir for reading";
my @json_log_files = sort map { File::Spec->catfile($json_dir, $_) }
    grep { m/\.log\.json$/ } readdir $DIRH;
closedir $DIRH or croak "Unable to close $json_dir after reading";
#dd(\@json_log_files) if $verbose;

my %data = ();
for my $log (@json_log_files) {
    my %this = ();
    my $f = Path::Tiny::path($log);
    my $decoded;
    {
        local $@;
        eval { $decoded = decode_json($f->slurp_utf8); };
        if ($@) {
            say STDERR "JSON decoding problem in $log: <$@>";
            eval { $decoded = JSON->new->decode($f->slurp_utf8); };
        }
    }
    map { $this{$_} = $decoded->{$_} } ( qw| author dist distname distversion grade | );
    $data{$decoded->{dist}} = \%this;
}
#dd(\%data) if $verbose;

my @fields = ( qw| dist author distname distversion grade | );
my $columns = [ @fields ];
my $psv = Text::CSV_XS->new({ binary => 1, auto_diag => 1, sep_char => $sep_char, eol => $/ });
open my $OUT, ">:encoding(utf8)", $foutput_file
    or croak "Unable to open $foutput_file for writing";
$psv->print($OUT, $columns), "\n" or $psv->error_diag;
for my $dist (sort keys %data) {
    $psv->print($OUT, [
       @{$data{$dist}}{@fields},
    ]) or $psv->error_diag;
}
close $OUT or croak "Unable to close $output_file after writing";
croak "$foutput_file not created" unless (-f $foutput_file);
say "Examine ", (($sep_char eq ',') ? 'comma' : 'pipe'), "-separated values in $foutput_file" if $verbose;

say "\nFinished";
