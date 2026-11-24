#!/bin/sh

# Run this program from a checkout of the Perl 5 core distribution

# This program is a tool for approaching the evaluation of pull requests in a
# Test-Driven Development (TDD) way.  It asks, "Suppose we were to apply
# a given pull request's changes to test files (so far, limited to t/*.t) to
# the main development branch of Perl.  If we ran those tests, would they show
# failures?  When we run the test suite in the branch underlying the pull
# request, do those failures disappear?"

# Takes two command-line arguments:
#
#   sh ./pr-tests-only <PULL_REQUEST NUMBER> <PULL_REQUEST_BRANCH>
#
# Example:
#
#   sh ./pr-tests-only 25067 pp_subst_bugs_n_speed

# Thanks to Tony Cook for guidance:
# https://github.com/Perl/perl5/issues/25100

# Don't let me use uninit vars, and any error is a problem
set -u
set -e
# Print expanded commands
set -x

git clean -dfxq
git checkout blead
PR=$1
BRANCH=$2
TESTS_ONLY_BRANCH=gh-${PR}-tests-only
git fetch origin pull/$PR/head:$BRANCH
git checkout -q $BRANCH -- t/
git checkout -qb $TESTS_ONLY_BRANCH
git commit -m "New branch $TESTS_ONLY_BRANCH with test from pull request $PR"
#git show | grep '^diff'
#sh ./Configure -des -Dusedevel && make test_harness
