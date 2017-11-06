# Example program showing that a 'paused' continuation can be 'resumed'
# multiple times from the same point (but with changes to data).
#
# Expected output:
#   1
#   2
#   3

def main [
  local-scope
  l:&:list:num <- copy 0
  l <- push 3, l
  l <- push 2, l
  l <- push 1, l
  k:continuation <- call-with-continuation-mark create-yielder, l
  {
    x:num, done?:bool <- call k
    break-if done?
    $print x 10/newline
    loop
  }
]

def create-yielder l:&:list:num -> n:num, done?:bool [
  local-scope
  load-ingredients
  return-continuation-until-mark
  done? <- equal l, 0
  return-if done?, 0
  n <- first l
  l <- rest l
]
