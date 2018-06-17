# Example program showing that a 'paused' continuation can be 'resumed'
# multiple times from the same point (but with changes to data).
#
# To run:
#   $ git clone https://github.com/akkartik/mu
#   $ cd mu
#   $ ./mu continuation2.mu
#
# Expected output:
#   1
#   2
#   3

def main [
  local-scope
  l:&:list:num <- copy null
  l <- push 3, l
  l <- push 2, l
  l <- push 1, l
  k:continuation <- call-with-continuation-mark 100/mark, create-yielder, l
  {
    x:num, done?:bool <- call k
    break-if done?
    $print x 10/newline
    loop
  }
]

def create-yielder l:&:list:num -> n:num, done?:bool [
  local-scope
  load-inputs
  return-continuation-until-mark 100/mark
  done? <- equal l, null
  return-if done?, 0/dummy
  n <- first l
  l <- rest l
]
