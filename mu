#!/bin/bash
#
# Compile mu if necessary before running it.

# show make output only if something needs doing
make -q || make >&2 || exit 1

# Little bit of cleverness: If I'm setting flags at the commandline I'm often
# disabling optimizations. In that case don't run all tests if I load any app
# files.
# Might be too clever..
if [[ $CXXFLAGS && $# -gt 0 && $1 != '--help' ]]  # latter two conditions are to continue printing the help message
then
  ./mu_bin --test-only-app "$@"
  exit 1
fi

./mu_bin "$@"

# Scenarios considered:
#   mu
#   mu --help
#   mu test
#   mu test file1.mu
#   CXXFLAGS=-g mu test file1.mu  # run only tests in file1.mu
