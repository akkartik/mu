# example program: constructing recipes out of order
#
# We construct a factorial function with separate base and recursive cases.
# Compare factorial.mu.
#
# This isn't a very tasteful example, just a simple demonstration of
# possibilities.

recipe factorial [
  default-space:address:array:location <- new location:type, 30:literal
  n:integer <- next-ingredient
  {
    +base-case
  }
  +recursive-case
]

after +base-case [
  # if n=0 return 1
  zero?:boolean <- equal n:integer, 0:literal
  break-unless zero?:boolean
  reply 1:literal
]

after +recursive-case [
  # return n * factorial(n - 1)
  x:integer <- subtract n:integer, 1:literal
  subresult:integer <- factorial x:integer
  result:integer <- multiply subresult:integer, n:integer
  reply result:integer
]

recipe main [
  1:integer <- factorial 5:literal
  $print [result: ], 1:integer, [
]
]
