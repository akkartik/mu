# A list links up multiple objects together to make them easier to manage.
#
# Try to make all objects in a single list of the same type, it'll help avoid bugs.
# If you want to store multiple types in a single list, use an exclusive-container.

container list [
  value:location
  next:address:list
]

# result:address:list <- push x:location, in:address:list
recipe push [
  local-scope
  x:location <- next-ingredient
  in:address:list <- next-ingredient
  result:address:list <- new list:type
  val:address:location <- get-address *result, value:offset
  *val <- copy x
  next:address:address:list <- get-address *result, next:offset
  *next <- copy in
  reply result
]

# result:location <- first in:address:list
recipe first [
  local-scope
  in:address:list <- next-ingredient
  result:location <- get *in, value:offset
  reply result
]

# result:address:list <- rest in:address:list
recipe rest [
  local-scope
  in:address:list <- next-ingredient
  result:address:list <- get *in, next:offset
  reply result
]

scenario list-handling [
  run [
    1:address:list <- copy 0
    1:address:list <- push 3, 1:address:list
    1:address:list <- push 4, 1:address:list
    1:address:list <- push 5, 1:address:list
    2:number <- first 1:address:list
    1:address:list <- rest 1:address:list
    3:number <- first 1:address:list
    1:address:list <- rest 1:address:list
    4:number <- first 1:address:list
    1:address:list <- rest 1:address:list
  ]
  memory-should-contain [
    1 <- 0  # empty to empty, dust to dust..
    2 <- 5
    3 <- 4
    4 <- 3
  ]
]
