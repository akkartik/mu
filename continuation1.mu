# example program showing that 'return-continuation-until-mark' can 'pause' a
# function call, returning a continuation, and that calling the continuation
# can 'resume' the paused function call.

def main [
  local-scope
  k:continuation <- call-with-continuation-mark create-yielder
  {
    x:num, done?:bool <- call k  # should return 1
    break-if done?
    $print x 10/newline
    loop
  }
]

def create-yielder -> n:num, done?:bool [
  local-scope
  load-ingredients
  n <- copy 0
  return-continuation-until-mark
  done?:bool <- greater-or-equal n, 3
  n <- add n, 1
]
