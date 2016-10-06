#!/bin/sh
#
# Compile mu if necessary before running it.

# I try to keep this script working even on a minimal OpenBSD without bash.
# In such situations you might sometimes need GNU make.
which gmake >/dev/null 2>&1 && export MAKE=gmake || export MAKE=make

# show make output only if something needs doing
$MAKE -q || $MAKE >&2 || exit 1

./mu_bin $FLAGS "$@"

# Scenarios considered:
#   mu
#   mu --help
#   mu test
#   mu test file1.mu
