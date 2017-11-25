# Example program showing that 'return-continuation-until-mark' can 'pause' a
# function call, returning a continuation, and that calling the continuation
# can 'resume' the paused function call.
#
# To run:
#   $ git clone https://github.com/akkartik/mu
#   $ cd mu
#   $ ./mu continuation1.mu
#
# Expected output:
#   1

def main [
  local-scope
  k:continuation <- call-with-continuation-mark create-yielder
  x:num <- call k  # should return 1
  $print x 10/newline
]

def create-yielder -> n:num [
  local-scope
  load-ingredients
  return-continuation-until-mark
  return 1
]
