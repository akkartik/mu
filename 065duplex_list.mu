# A doubly linked list permits bidirectional traversal.

container duplex-list [
  value:location
  next:address:duplex-list
  prev:address:duplex-list
]

# result:address:duplex-list <- push-duplex x:location, in:address:duplex-list
recipe push-duplex [
  default-space:address:array:location <- new location:type, 30:literal
  x:location <- next-ingredient
  in:address:duplex-list <- next-ingredient
  result:address:duplex-list <- new duplex-list:type
  val:address:location <- get-address result:address:duplex-list/deref, value:offset
  val:address:location/deref <- copy x:location
  next:address:address:duplex-list <- get-address result:address:duplex-list/deref, next:offset
  next:address:address:duplex-list/deref <- copy in:address:duplex-list
  prev:address:address:duplex-list <- get-address in:address:duplex-list/deref, prev:offset
  prev:address:address:duplex-list/deref <- copy result:address:duplex-list
  reply result:address:duplex-list
]

# result:location <- first-duplex in:address:duplex-list
recipe first-duplex [
  default-space:address:array:location <- new location:type, 30:literal
  in:address:duplex-list <- next-ingredient
  result:location <- get in:address:duplex-list/deref, value:offset
  reply result:location
]

# result:address:duplex-list <- next-duplex in:address:duplex-list
recipe next-duplex [
  default-space:address:array:location <- new location:type, 30:literal
  in:address:duplex-list <- next-ingredient
  result:address:duplex-list <- get in:address:duplex-list/deref, next:offset
  reply result:address:duplex-list
]

# result:address:duplex-list <- prev-duplex in:address:duplex-list
recipe prev-duplex [
  default-space:address:array:location <- new location:type, 30:literal
  in:address:duplex-list <- next-ingredient
  result:address:duplex-list <- get in:address:duplex-list/deref, prev:offset
  reply result:address:duplex-list
]

scenario duplex-list-handling [
  run [
    1:address:duplex-list <- copy 0:literal
    1:address:duplex-list <- push-duplex 3:literal, 1:address:duplex-list
    1:address:duplex-list <- push-duplex 4:literal, 1:address:duplex-list
    1:address:duplex-list <- push-duplex 5:literal, 1:address:duplex-list
    2:address:duplex-list <- copy 1:address:duplex-list
    3:number <- first 2:address:duplex-list
    2:address:duplex-list <- next-duplex 2:address:duplex-list
    4:number <- first 2:address:duplex-list
    2:address:duplex-list <- next-duplex 2:address:duplex-list
    5:number <- first 2:address:duplex-list
    2:address:duplex-list <- prev-duplex 2:address:duplex-list
    6:number <- first 2:address:duplex-list
    2:address:duplex-list <- prev-duplex 2:address:duplex-list
    7:number <- first 2:address:duplex-list
    8:boolean <- equal 1:address:duplex-list, 2:address:duplex-list
  ]
  memory-should-contain [
    3 <- 5  # scanning next
    4 <- 4
    5 <- 3
    6 <- 4  # then prev
    7 <- 5
    8 <- 1  # list back at start
  ]
]
