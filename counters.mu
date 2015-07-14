# example program: maintain multiple counters with isolated lexical scopes
# (spaces)

recipe new-counter [
  default-space:address:array:location <- new location:type, 30:literal
  n:number <- next-ingredient
  reply default-space:address:array:location
]

recipe increment-counter [
  new-default-space
  0:address:array:location/names:new-counter <- next-ingredient  # setup outer space; it *must* come from 'new-counter'
  x:number <- next-ingredient
  n:number/space:1 <- add n:number/space:1, x:number
  reply n:number/space:1
]

recipe main [
  new-default-space
  # counter A
  a:address:array:location <- new-counter 34:literal
  # counter B
  b:address:array:location <- new-counter 23:literal
  # increment both by 2 but in different ways
  increment-counter a:address:array:location, 1:literal
  b-value:number <- increment-counter b:address:array:location, 2:literal
  a-value:number <- increment-counter a:address:array:location, 1:literal
  # check results
  $print [Contents of counters
]
  # trailing space in next line is to help with syntax highlighting
  $print [a: ], a-value:number, [ b: ], b-value:number, [ 
]
]
