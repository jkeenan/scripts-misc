#!/usr/bin/env perl
use strict;
use warnings;
# rmtree1.pl # from Perl Cookbook, 2nd ed., p. 362, Recipe 9.8

use File::Find;
die "usage: $0 dir ..\n" unless @ARGV;

find {
    bydepth   => 1,
    no_chdir  => 1,
    wanted    => sub {
        if (! -l && -d _) {
            rmdir  or warn "Couldn't rmdir $_: $!";
        } else {
            unlink or warn "Couldn't unlink $_: $!";
        }
    }
} => @ARGV;


