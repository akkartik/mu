# A list links up multiple objects together to make them easier to manage.
#
# The objects must be of the same type. If you want to store multiple types in
# a single list, use an exclusive-container.

container list:_elem [
  value:_elem
  next:address:list:_elem
]

recipe push x:_elem, in:address:list:_elem -> result:address:list:_elem [
  local-scope
  load-ingredients
  result <- new {(list _elem): type}
  val:address:_elem <- get-address *result, value:offset
  *val <- copy x
  next:address:address:list:_elem <- get-address *result, next:offset
  *next <- copy in
  reply result
]

recipe first in:address:list:_elem -> result:_elem [
  local-scope
  load-ingredients
  result <- get *in, value:offset
]

# result:address:list <- rest in:address:list
recipe rest in:address:list:_elem -> result:address:list:_elem [
  local-scope
  load-ingredients
  result <- get *in, next:offset
]

recipe force-specialization-list-number [
  1:address:list:number <- push 2:number, 1:address:list:number
  2:number <- first 1:address:list:number
  1:address:list:number <- rest 1:address:list:number
]

# todo: automatically specialize code in scenarios
scenario list-handling [
  run [
    1:address:list:number <- copy 0
    2:number <- copy 3
    1:address:list:number <- push 2:number, 1:address:list:number
    1:address:list:number <- push 4, 1:address:list:number
    1:address:list:number <- push 5, 1:address:list:number
    2:number <- first 1:address:list:number
    1:address:list:number <- rest 1:address:list:number
    3:number <- first 1:address:list:number
    1:address:list:number <- rest 1:address:list:number
    4:number <- first 1:address:list:number
    1:address:list:number <- rest 1:address:list:number
  ]
  memory-should-contain [
    1 <- 0  # empty to empty, dust to dust..
    2 <- 5
    3 <- 4
    4 <- 3
  ]
]
