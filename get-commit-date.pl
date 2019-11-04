#!/usr/bin/env perl
use 5.14.0;
use warnings;
use Carp;

# Provided that you are bisecting for the purpose of finding the "first bad
# commit", run this program from the directory in which you have just run
# Porting/bisect.pl.

# Try to identify date when bad commit was committed to blead
# (as distinct from date patch was written).

my $HEAD = '';
my $default_log = "./.git/BISECT_LOG"; 
my $blog = (-f $default_log) ? $default_log : shift(@ARGV);
open my $IN, '<', $blog or die "Unable to open $blog for reading";
while (my $l = <$IN>) {
    chomp $l;
    next unless $l =~ m{^#\sfirst\sbad\scommit:\s\[([^\]]+)\]};
    $HEAD = $1;
    last;
}
close $IN or die "Unable to close $blog after reading";
my $message = <<EOM;
Unable to extract HEAD position from $blog.
This may be either because the objective in this bisection
was something other than 'find the first bad commit', or
because the program could not parse $blog to extract the
SHA for the first bad commit.
EOM

croak($message) unless length $HEAD;

my @git_log_output = `git log --format=fuller $HEAD`;
chomp(@git_log_output);
unless (@git_log_output >= 5) {
    croak "Unable to capture output of 'git log --format=fuller'";
}
else {
    say $_ for @git_log_output[0..4];
}

