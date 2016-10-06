#!/bin/sh
#
# Compile mu if necessary before running it.

./build

./mu_bin $FLAGS "$@"

# Scenarios considered:
#   mu
#   mu --help
#   mu test
#   mu test file1.mu
