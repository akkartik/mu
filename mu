#!/bin/bash
# Run this from the mu directory.
#
# Wrapper to allow selectively running parts of the mu codebase/tests.
#
# Usage:
#  mu [mu files]
#  mu test [arc files]

if [[ $1 == "test" ]]
then
  shift
  ./anarki/arc load.arc "$@"  # test currently assumed to be arc files rather than mu files
else
  ./anarki/arc load.arc mu.arc -- "$@"  # mu files from args
fi
