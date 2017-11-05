# example program showing 'return-continuation-until-mark' return other values
# alongside continuations

def main [
  local-scope
  l:&:list:num <- copy 0
  l <- push 3, l
  l <- push 2, l
  l <- push 1, l
  k:continuation, x:num, done?:bool <- call-with-continuation-mark create-yielder, l
  {
    break-if done?
    $print x 10/newline
    k, x:num, done?:bool <- call k
    loop
  }
]

def create-yielder l:&:list:num -> n:num, done?:bool [
  local-scope
  load-ingredients
  {
    done? <- equal l, 0
    # Our current primitives can lead to gnarly code to ensure that we always
    # statically match a continuation call with a 'return-continuation-until-mark'.
    # Try to design functions to either always return or always return continuation.
    {
      # should we have conditional versions of return-continuation-until-mark
      # analogous to return-if and return-unless? Names get really long.
      break-unless done?
      return-continuation-until-mark 0, done?
      return 0, done?  # just a guard rail; should never execute
    }
    n <- first l
    l <- rest l
    return-continuation-until-mark n, done?
    loop
  }
]
