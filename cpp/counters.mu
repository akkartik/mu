recipe init-counter [
  default-space:address:space <- new location:type, 30:literal
  n:integer <- next-ingredient
  reply default-space:address:space
]

recipe increment-counter [
  default-space:address:space <- new location:type, 30:literal
  0:address:space/names:init-counter <- next-ingredient  # setup outer space; it *must* come from 'init-counter'
  x:integer <- next-ingredient
  n:integer/space:1 <- add n:integer/space:1, x:integer
  reply n:integer/space:1
]

recipe main [
  default-space:address:space <- new location:type, 30:literal
  # counter A
  a:address:space <- init-counter 34:literal
  # counter B
  b:address:space <- init-counter 23:literal
  # increment both by 2 but in different ways
  increment-counter a:address:space, 1:literal
  bres:integer <- increment-counter b:address:space, 2:literal
  ares:integer <- increment-counter a:address:space, 1:literal
  # check results
  $print [Contents of counters a ]
  $print ares:integer
  $print [ b ]
  $print bres:integer
  $print [
]
]
