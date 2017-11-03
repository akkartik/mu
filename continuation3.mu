# example program showing that a function call can be 'paused' multiple times,
# creating different continuation values

def main [
  local-scope
  $print [caller 0] 10/newline
  k:continuation <- call-with-continuation-mark f
  $print [caller 1] 10/newline
  k <- call k
  $print [caller 2] 10/newline
  call k
]

def f [
  local-scope
  $print [callee 0] 10/newline
  return-continuation-until-mark
  $print [callee 1] 10/newline
  return-continuation-until-mark
  $print [callee 2] 10/newline
]
