# example program: maintain multiple counters with isolated lexical scopes
# (spaces)

recipe init-counter [
  default-space:address:array:location <- new location:type, 30:literal
  n:number <- next-ingredient
  reply default-space:address:space
]

recipe increment-counter [
  default-space:address:array:location <- new location:type, 30:literal
  0:address:array:location/names:init-counter <- next-ingredient  # setup outer space; it *must* come from 'init-counter'
  x:number <- next-ingredient
  n:number/space:1 <- add n:number/space:1, x:number
  reply n:number/space:1
]

recipe main [
  default-space:address:array:location <- new location:type, 30:literal
  # counter A
  a:address:space <- init-counter 34:literal
  # counter B
  b:address:space <- init-counter 23:literal
  # increment both by 2 but in different ways
  increment-counter a:address:space, 1:literal
  b-value:number <- increment-counter b:address:space, 2:literal
  a-value:number <- increment-counter a:address:space, 1:literal
  # check results
  $print [Contents of counters
]
  # trailing space in next line is to help with syntax highlighting
  $print [a: ], a-value:number, [ b: ], b-value:number, [ 
]
]
