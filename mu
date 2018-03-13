#!/bin/sh
# Run interpreter, first compiling if necessary.
set -e

./build3  &&  ./mu_bin "$@"

# Scenarios considered:
#   ./mu
#   ./mu --help
#   ./mu test
#   ./mu test file1.mu
