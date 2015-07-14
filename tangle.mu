# example program: constructing recipes out of order
#
# We construct a factorial function with separate base and recursive cases.
# Compare factorial.mu.
#
# This isn't a very tasteful example, just a simple demonstration of
# possibilities.

recipe factorial [
  local-scope
  n:number <- next-ingredient
  {
    +base-case
  }
  +recursive-case
]

after +base-case [
  # if n=0 return 1
  zero?:boolean <- equal n:number, 0:literal
  break-unless zero?:boolean
  reply 1:literal
]

after +recursive-case [
  # return n * factorial(n - 1)
  x:number <- subtract n:number, 1:literal
  subresult:number <- factorial x:number
  result:number <- multiply subresult:number, n:number
  reply result:number
]

recipe main [
  1:number <- factorial 5:literal
  $print [result: ], 1:number, [
]
]
