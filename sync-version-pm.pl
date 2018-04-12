#!/usr/bin/env perl
use 5.14.0;
use warnings;
use Data::Dump ( qw| dd pp| );
use Carp;
use Cwd;
use File::Basename;
use File::Copy ( qw| copy | );
use File::Path ( qw| make_path | );
use File::Spec;
use Getopt::Long;

=head1 NAME

sync-version-pm.pl - Synchronize Perl 5 git repo with latest version.pm from CPAN

=head1 SYNOPSIS

    perl sync-version-pm.pl \
        --url http://search.cpan.org/CPAN/authors/id/J/JP/JPEACOCK/version-0.9921.tar.gz \
        --gitdir=/home/<username>/gitwork/perl \
        --workdir=/home/<username>/tmp \
        --verbose

=head1 DESCRIPTION

The F<version> distribution is included in the Perl 5 core distribution but is maintained upstream on CPAN, currently by John Peacock.

Most "cpan-upstream" distributions can be easily merged into Perl 5 blead by
using the F<Porting/sync-with-cpan> program found in the core distribution.
However, certain distributions are more problematic, particularly those whose
entries in C<%Modules> in F<Porting/Maintainers.pl> have a C<CUSTOMIZED> element.

In April 2018 a new version of F<version> was uploaded to CPAN.  I tried to
merge this into blead but failed twice.  Instead, I wrote this program, which
appeared to do the trick.

=head1 USAGE

Call the program as suggested in the SYNOPSIS.

=head2 Command-Line Switches

=over 4

=item * C<url>

Required: Full URL to a tarball on CPAN of the latest release of F<version>.

=item * C<gitdir>

Required: Absolute path to a directory where you have a F<git> checkout of the
Perl 5 core distribution.  The current branch should be F<blead> or a branch
which you have just created from F<blead> and intend to merge back into
F<blead>.

=item * C<workdir>

Optional: The directory under which you will download the tarball and perform other work.  Defaults to the current working directory.

=item * C<verbose>

Optional but strongly recommended.  Extra output in your terminal.

=back

B<NOTE: Pay careful attention to the output at the end of the program!> You
will almost certainly have to perform edits on one file and have to run one or
more additional programs to get F<make test_porting> to C<PASS>.  YMMV!

=head1 AUTHOR

Copyright 2018 James E Keenan / jkeenan at cpan dot org

=head1 LICENSE

L<MIT License|https://github.com/jkeenan/scripts-misc/blob/master/LICENSE>

=cut

my $cwd = cwd();
my $workdir = $cwd;
my ($tarball_url, $gitdir, $verbose);
GetOptions(
	"url=s"			=> \$tarball_url,
	"gitdir=s"		=> \$gitdir,
	"workdir=s"		=> \$workdir,
    "verbose"       => \$verbose,
) or die("Error in command line arguments\n");
if ($verbose) {
    say sprintf("%-16s%s" => ('url:', $tarball_url));
    say sprintf("%-16s%s" => ('git checkout:', $gitdir));
    say sprintf("%-16s%s" => ('workdir:', $workdir));
}

my ($tarball, $distversion);
my @lt = localtime(time);
my $timestamp = sprintf("%4d%02d%02d-%02d%02d%02d" => (
    $lt[5] + 1900,
    $lt[4] + 1,
    $lt[3],
    $lt[2],
    $lt[1],
    $lt[0],
));
say sprintf("%-16s%s" => ('timestamp:', $timestamp)) if $verbose;

$workdir = File::Spec->catdir('.', 'sync-version-pm', $timestamp);
if (-d $workdir) {
    croak "$workdir already exists -- which is puzzling";
}
else {
    make_path($workdir, { chmod => 0711 });
    croak "$workdir not created" unless -d $workdir;
}

system(qq|wget -P $workdir $tarball_url|)
    and croak "Unable to wget tarball";

chdir $workdir or croak "Unable to change to $workdir";
$tarball = basename($tarball_url);
($distversion) = $tarball =~ s{\.tar\.gz$}{}r;
say sprintf("%-16s%s" => ('distversion:', $distversion)) if $verbose;

system(qq|tar xzf $tarball|)
    and croak "Unable to extract $tarball";
chdir $distversion or croak "Unable to change to $distversion";

my @all_files = `find . -type f`;
say "Count of all_files: ", scalar(@all_files);
chomp(@all_files);
s{^\./}{} for @all_files;
#dd([ sort @all_files ]);

=pod

From Porting/Maintainers.pl (20180412):

           qr{^vutil/lib/},
            'vutil/Makefile.PL',
            'vutil/ppport.h',
            'vutil/vxs.xs',
            't/00impl-pp.t',
            't/survey_locales',
            'vperl/vpp.pm',

=cut

my $EXCLUDED_REGEX = qr{^vutil/lib/};
my %SPECIFIC_EXCLUDES = map {$_ => 1} (
    'vutil/Makefile.PL',
    'vutil/ppport.h',
    'vutil/vxs.xs',
    't/00impl-pp.t',
    't/survey_locales',
    'vperl/vpp.pm',
);
my %OTHER_EXCLUDES = map {$_ => 1} ( qw|
    CHANGES
    Makefile.PL
    MANIFEST
    MANIFEST.SKIP
    META.json
    META.yml
    README
|);

my @process = ();
for my $f (@all_files) {
    next if $f =~ $EXCLUDED_REGEX;
    next if $SPECIFIC_EXCLUDES{$f};
    next if $OTHER_EXCLUDES{$f};
    push @process, $f;
}
dd( [ sort @process ] );
say "Count to be processed: ", scalar(@process) if $verbose;

my %mappings = ();
for my $f (@process) {
    if ($f =~ m/^vutil/) {
        my ($g) = $f =~ s{^vutil/}{}r;
        $mappings{File::Spec->catfile($cwd, $workdir, $distversion, $f)} = File::Spec->catfile($gitdir, $g);
    }
    else {
        $mappings{File::Spec->catfile($cwd, $workdir, $distversion, $f)} = File::Spec->catfile($gitdir, 'cpan', 'version', $f);
    }
}
dd(\%mappings);
for my $f (sort keys %mappings) {
    copy $f => $mappings{$f}
        or croak "Unable to copy $f to $mappings{$f}";
    chmod 0664 => $mappings{$f}
        or croak "Unable to chmod $mappings{$f}";
}

say "";
say "ATTENTION! ATTENTION! ATTENTION!";
say "You must now edit $gitdir/cpan/version/lib/version.pm";
say "  to remove the block of code following:";
say " # !!!!Delete this next block completely when adding to Perl core!!!!";
say "";
say "Then, try:";
say "  make test_prep; cd t; ./perl harness -v ../cpan/version/t/*.t; cd -";
say "You will probably have to say:";
say "  cd t; ./perl -I../lib porting/customized.t --regen; cd -";
say "  ... then, re-run 'make test_porting'";
say "If that passes, do 'git add' as needed,";
say "  'make test_harness', 'git push origin <branch>'";


