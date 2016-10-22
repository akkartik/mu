#!/bin/sh
#
# Compile Mu if necessary before running it.

./build || exit 1

./mu_bin $FLAGS "$@"

# Scenarios considered:
#   mu
#   mu --help
#   mu test
#   mu test file1.mu
