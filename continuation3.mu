# Example program showing that a function call can be 'paused' multiple times,
# creating different continuation values.
#
# To run:
#   $ git clone https://github.com/akkartik/mu
#   $ cd mu
#   $ ./mu continuation3.mu
#
# Expected output:
#   caller 0
#   callee 0
#   caller 1
#   callee 1
#   caller 2
#   callee 2

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
