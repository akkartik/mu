#!/bin/bash
#
# To run a program:
#   $ mu [mu files]
# To run a file of tests (in arc):
#   $ mu test [arc files]
# To start an interactive session:
#   $ mu repl
#
# To mess with load levels and selectively run parts of the codebase, skip
# this script and call load.arc directly.

if [[ $1 == "test" ]]
then
  shift
  ./anarki/arc load.arc "$@"  # test currently assumed to be arc files rather than mu files
elif [[ $1 == "repl" ]]
then
  if [ "$(type rlwrap)" ]
  then
    rlwrap -C mu ./anarki/arc mu.arc
  else
    ./anarki/arc mu.arc
  fi
else
  ./anarki/arc load.arc mu.arc -- "$@"  # mu files from args
fi
