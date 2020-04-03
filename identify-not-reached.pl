#!/usr/bin/env perl
use 5.14.0;
use warnings;
use Data::Dumper;$Data::Dumper::Indent=1;
use Data::Dump ( qw| dd pp| );
use Carp;
use Cwd;
use File::Spec;
use Path::Tiny;
use JSON;
use Text::CSV_XS;
use List::Compare;

my $verbose = 1;
my $sep_char = '|';
my $cwd = cwd();

my $workdir = "$ENV{HOMEDIR}/learn/perl/p5p/module-install-revdeps";
my $request_file = 'ghi-16300-modules-for-cpanm.txt';
my $frequest_file = File::Spec->catfile($workdir, $request_file);

my %distros = (); # key is Some-Distro; value is Some::Distro
open my $IN, '<', $frequest_file or croak "Unable to open for reading";
while (my $module = <$IN>) {
    chomp $module;
    my ($dis) = $module =~ s{::}{-}gr;
    $distros{$dis} = $module;
}
close $IN or croak "Unable to close";
dd(\%distros);

my %reached; # key Some-Distro reached and .json created; value: presumptive module
my $psvfile = 'module-install-dsl-attempt.psv';
my $fpsvfile = File::Spec->catfile($workdir, $psvfile);
my $psv = Text::CSV_XS->new({ binary => 1, auto_diag => 1, sep_char => $sep_char, eol => $/ });
open my $INPSV, "<:encoding(utf8)", $fpsvfile
    or croak "Unable to open $fpsvfile for writing";
while (my $row = $psv->getline ($INPSV)) {
    my ($presumptive_module) = $row->[0] =~ s{-}{::}rg;
    $reached{$row->[0]} = $presumptive_module;
}
close $INPSV or croak "Unable to close $fpsvfile after writing";

my $lc = List::Compare->new([ keys %distros], [keys %reached] );
my @unique = $lc->get_unique();
my @int = $lc->get_intersection;
my @complement = $lc->get_complement;
say join("\t" => scalar(@unique), scalar(@int), scalar(@complement));

#say "\nModule were requested in $request_file but these corresponding distros apparently not reached during testing";
#dd(\@unique);

=pod

say "\nBoth requested and .json generated (may be PASS FAIL or NA)";
dd(\@int);
say "\nNot requested but .json generated (presumably these were prereqs)";
say "(Not shown)";
dd(\@complement);

=cut

# Remaining questions:
#
# 1. Of those distros not reached (@unique), how many were not reached because
# their prerequisites failed specifically due to inc-module-install-dsl?

=pod

my @notreached = map { $distros{$_} } @unique;
say "Examine build.log for why not reached (prereqs?)";
dd(\@notreached);
say scalar @notreached;

=cut

# 2. Of those distros that were reached (@int), how many were graded FAIL or NA
# specifically because of inc-module-install-dsl?

say "Examine build.log for why reached but not PASS";
dd(\@int);
say scalar @int;

# Need to parse the .json file, which is found in e.g.,
# testing/20200402/ADAMK.Algorithm-Dependency-MapReduce-0.03.log.json
# ... for the 'grade' element
# Do not want to examine: grade => "PASS"
# In both cases, I have to manually inspect the build.log.
# Will first need to identify the relevant .json file,
# then convert its json to Perl hash, then filter for grade other than PASS
# print out in Some-Module form (as that's more efficient in grepping through
# build.log ( "$workdir/build.1585792610.34356.log" )


my $testingdir = "testing/20200402";
opendir my $DIRH, $testingdir
    or croak "Unable to open directory for reading";
my %json_files = map { $_ => 1 } grep { ! m/^\./ } readdir $DIRH;
my %distros2jsons = ();
closedir $DIRH or croak;
#dd(\%json_files);
for my $distro (@int) {
    my @possible_jsons = ();
    for my $json (keys %json_files) {
        if ($json =~ m/\Q$distro\E/) {
            #            say "$distro likely reported in $json";
            push @possible_jsons, $json;
            next;
        }
    }
    if (! @possible_jsons) {
        say "$distro does not have corresponding .json";
        $distros2jsons{$distro} = '';
    }
    elsif (@possible_jsons == 1) {
        say "$distro reported in $possible_jsons[0]";
        $distros2jsons{$distro} = $possible_jsons[0];
    }
    else {
        #say "$distro may be reported in any of @possible_jsons";
        my $minimum_length;
        my $shortest_less;
        for my $json (@possible_jsons) {
            my ($less) = $json =~ s{^.*?\.(.*)$}{$1}r;
            #say "$distro: $json: $less";
            my $l = length($less);
            if (! defined $minimum_length) {
                $minimum_length = length($less);
                $shortest_less = $json;
            }
            else {
                if (length($less) < $minimum_length) {
                    $minimum_length = length($less);
                    $shortest_less = $json;
                }
            }
        }
        say "$distro probably reported in $shortest_less";
        $distros2jsons{$distro} = $shortest_less;
    }
}
#dd(\%distros2jsons);
# In %distros2jsons, read the JSON found in the value
# into Perl hash.  Examine 'grade' KVP for non-PASS.

my %distros_for_inspection;
my %distros_now_succeed;
for my $distro (sort keys %distros2jsons) {
    my $json_file = File::Spec->catfile($workdir, $testingdir, $distros2jsons{$distro});
    #say $json_file;
    my $utf8_encoded_json_text = Path::Tiny::path($json_file)->slurp_utf8;
    my $perl_hashref  = decode_json $utf8_encoded_json_text;
    if ($perl_hashref->{grade} ne 'PASS') {
        $distros_for_inspection{$distro} = $perl_hashref->{grade};
    }
    else {
        $distros_now_succeed{$distro} =  $perl_hashref->{grade};
    }
}
dd(\%distros_for_inspection);
dd(\%distros_now_succeed);

# Result of inspection: On zareason see end of
# /home/jkeenan/learn/perl/p5p/module-install-revdeps/inspections.txt
# 13 FAIL due to missing prereqs, failing unit tests, build-time error
# 1 NA due to missing external dependency

say "\nFinished";
