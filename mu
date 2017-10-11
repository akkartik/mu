#!/bin/sh
# Run interpreter, first compiling if necessary.

./build  &&  ./mu_bin "$@"

# Scenarios considered:
#   mu
#   mu --help
#   mu test
#   mu test file1.mu
