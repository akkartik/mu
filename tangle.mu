# example program: constructing functions out of order
#
# We construct a factorial function with separate base and recursive cases.
# Compare factorial.mu.
#
# This isn't a very tasteful example, just a simple demonstration of
# possibilities.

def factorial n:num -> result:num [
  local-scope
  load-ingredients
  {
    <base-case>
  }
  <recursive-case>
]

after <base-case> [
  # if n=0 return 1
  zero?:boolean <- equal n, 0
  break-unless zero?
  return 1
]

after <recursive-case> [
  # return n * factorial(n - 1)
  x:num <- subtract n, 1
  subresult:num <- factorial x
  result <- multiply subresult, n
]

def main [
  1:num <- factorial 5
  # trailing space in next line is to help with syntax highlighting
  $print [result: ], 1:num, [ 
]
]
