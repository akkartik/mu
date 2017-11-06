# Example program showing that a 'paused' continuation can be 'resumed' with
# ingredients.
#
# Print out a list of numbers, first adding 0 to the first, 1 to the second, 2
# to the third, and so on.
#
# Expected output:
#   1
#   3
#   5

def main [
  local-scope
  l:&:list:num <- copy 0
  l <- push 3, l
  l <- push 2, l
  l <- push 1, l
  k:continuation, x:num, done?:bool <- call-with-continuation-mark create-yielder, l
  a:num <- copy 1
  {
    break-if done?
    $print x 10/newline
    k, x:num, done?:bool <- call k, a  # resume; x = a + next l value
    a <- add a, 1
    loop
  }
]

def create-yielder l:&:list:num -> n:num, done?:bool [
  local-scope
  load-ingredients
  a:num <- copy 0
  {
    done? <- equal l, 0
    break-if done?
    n <- first l
    l <- rest l
    n <- add n, a
    a <- return-continuation-until-mark n, done?  # pause/resume
    loop
  }
  return-continuation-until-mark -1, done?
  assert 0/false, [called too many times, ran out of continuations to return]
]
