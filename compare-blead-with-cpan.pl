#!/usr/bin/env perl
use strict;
use warnings;
our $VERSION = 0.01;
use Carp;
use File::Spec;
use Getopt::Long;
use Data::Dump ( qw| dd pp| );
use Parse::CPAN::Packages;

=head1 NAME

compare-blead-with-cpan.pl - Identify differences in module versions between core and CPAN

=head1 SYNOPSIS

    perl compare-blead-with-cpan.pl \
        --packages_dir /home/username/minicpan/modules \
        --perl_git_dir /home/username/gitwork/perl

=head1 DESCRIPTION

This is a crude program useful for identifying modules shipped with the Perl 5
core distribution which (a) have been released to CPAN and (b) have a different
C<$VERSION> in core from that found on CPAN.

=head1 USAGE

As in L</"SYNOPSIS">.  Two required command-line switches:

=over 4

=item * C<packages_dir>

Path to a directory holding a (presumably updated) F<02packages.details.txt.gz>
file.

=item * C<perl_git_dir>

Path to a directory holding a F<git> checkout of the Perl 5 core distribution.
Underneath this directory there should be a directory called F<Porting/>
holding F<Maintainers.pl>.

=back

=head1 RESULTS

Prints to F<STDOUT> a hashref whose keys are the names of modules (I<e.g.>, F<Alpha::Beta> -- not F<Alpha-Beta>) and whose values are hashref with these three elements:

=over 4

=item * C<cpan_version>

The module's C<$VERSION> as found on CPAN and as recorded in F<02packages.details.txt.gz>.

=item * C<cpanid_filename>

String in which a C</> character joins the CPANID of the module's most recent
CPAN releasor with the name of the file's tarball (including the distribution's version).

=item * C<DISTRIBUTION>

Like C<cpanid_filename>, a string in which a C</> character joins a CPANID and
a tarball file's name -- only in this case as recorded in the core
distribution's F<Porting/Maintainers.pl>.

=back

    {
      "Carp"        => {
                         cpan_version    => "1.50",
                         cpanid_filename => "XSAWYERX/Carp-1.50.tar.gz",
                         DISTRIBUTION    => "RJBS/Carp-1.38.tar.gz",
                       },
      "CPAN"        => {
                         cpan_version    => 2.16,
                         cpanid_filename => "ANDK/CPAN-2.16.tar.gz",
                         DISTRIBUTION    => "ANDK/CPAN-2.20-TRIAL.tar.gz",
                       },
      ...
    }

=head2 PREREQUISITES

Two non-core CPAN modules:  F<Data::Dump> and F<Parse::CPAN::Packages>.

=head1 AUTHOR

Copyright 2018 James E Keenan (CPANID: JKEENAN)

This is alpha code; YMMV.

This is free software and is distributed under the same terms as Perl itself.

=cut

my ($packages_dir, $perl_git_dir) = ('') x 2;
GetOptions(
    "packages_dir=s"    => \$packages_dir,
    "perl_git_dir=s"    => \$perl_git_dir,
) or croak "Unable to process command-line options";
for my $d ($packages_dir, $perl_git_dir) {
    croak "Could not locate directory '$d'" unless -d $d;
}

my $pkgs = File::Spec->catfile($packages_dir, '02packages.details.txt.gz');
croak "Could not locate $pkgs" unless -f $pkgs;
my $p = Parse::CPAN::Packages->new($pkgs);

my $maint = File::Spec->catfile($perl_git_dir, qw| Porting Maintainers.pl |);
croak "Could not locate $maint" unless -f $maint;

do $maint or croak "Unable to require $maint";

my %overall = ();
no warnings 'once';
for my $module (sort keys %Maintainers::Modules) {
    my $distro = $Maintainers::Modules{$module}{DISTRIBUTION} || '';
    # The following will skip: I18::LangTags warnings _PERLLIB
    next unless $distro;
    my $m = $p->package($module);
    if (defined $m) {
        my $d = $m->distribution();
        $overall{$m->package}{cpan_version} = $d->version;
        $overall{$m->package}{cpanid_filename} = join('/' => $d->cpanid, $d->filename);
        $overall{$m->package}{DISTRIBUTION} = $distro;
    }
}
use warnings;

my %diffs = ();
for my $module (keys %overall) {
    $diffs{$module} = $overall{$module}
        if ($overall{$module}{cpanid_filename} ne $overall{$module}{DISTRIBUTION});
}
dd(\%diffs);
