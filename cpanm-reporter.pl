#!/usr/bin/env perl
use 5.14.0;
use warnings;
use Data::Dumper;$Data::Dumper::Indent=1;
use Data::Dump ( qw| dd pp| );
use Carp;
use CPAN::cpanminus::reporter::RetainReports;

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

