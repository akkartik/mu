# example program: constructing functions out of order
#
# We construct a factorial function with separate base and recursive cases.
# Compare factorial.mu.
#
# This isn't a very tasteful example, just a basic demonstration of
# possibilities.

def factorial n:num -> result:num [
  local-scope
  load-inputs
  <factorial-cases>
]

after <factorial-cases> [
  # if n=0 return 1
  return-unless n, 1
]

after <factorial-cases> [
  # return n * factorial(n - 1)
  {
    break-unless n
    x:num <- subtract n, 1
    subresult:num <- factorial x
    result <- multiply subresult, n
    return result
  }
]

def main [
  1:num <- factorial 5
  # trailing space in next line is to help with syntax highlighting
  $print [result: ], 1:num, [ 
]
]
