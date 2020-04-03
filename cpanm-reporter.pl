#!/usr/bin/env perl
use 5.14.0;
use warnings;
use Data::Dumper;$Data::Dumper::Indent=1;
use Carp;
use Getopt::Long;
use CPAN::cpanminus::reporter::RetainReports;
use Data::Dump ( qw| dd pp| );

=head1 NAME

cpanm-reporter.pl - Parse F<cpanm> F<build.log> into JSON files

=head1 SYNOPSIS

TK

=head1 DESCRIPTION

This is a program which simulates the C<analyze_cpanm_build_logs()> method of
CPAN module F<Test::Against::Dev>.  It assumes that you have used F<cpanm> to
install a list of CPAN modules agai nst a given F<perl> executable and that
you have access to the F<build.log> file generated by running F<cpanm >.  The
program parses that log into one F<.json> file for each CPAN distribution
reached during F<cpanm>.  T he files are written to a user-specified directory
for further processing.

=head1 PREREQUISITES

Uses the following non-core CPAN modules:

    CPAN::cpanminus::reporter::RetainReports
    Data::Dump

=cut

my $cpanmdir                        = "$ENV{HOMEDIR}/.cpanm";
my $log                             = "$cpanmdir/build.log";
local $ENV{PERL_CPANM_HOME}         = $cpanmdir;
local $ENV{PERL_CPAN_REPORTER_DIR}  = "$ENV{HOMEDIR}/.cpanreporter";

my $reporter = CPAN::cpanminus::reporter::RetainReports->new(
    force               => 1,           # ignore mtime check on cpanm build.log
    build_dir           => $cpanmdir,
    build_logfile       => $log,
    'ignore-versions' => 1,
);

my $analysisdir = "$ENV{HOMEDIR}/learn/perl/p5p/module-install-revdeps/testing/20200402";
$reporter->set_report_dir($analysisdir);
$reporter->run;

