# A table is like an array, except that its keys are not integers but
# arbitrary types.

scenario table-read-write [
  local-scope
  tab:&:table:num:num <- new-table 30
  run [
    put-index tab, 12, 34
    1:num/raw <- index tab, 12
  ]
  memory-should-contain [
    1 <- 34
  ]
]

scenario table-read-write-non-integer [
  local-scope
  tab:&:table:text:num <- new-table 30
  run [
    put-index tab, [abc def], 34
    1:num/raw <- index tab, [abc def]
  ]
  memory-should-contain [
    1 <- 34
  ]
]

container table:_key:_value [
  length:num
  capacity:num
  data:&:@:table-row:_key:_value
]

container table-row:_key:_value [
  occupied?:bool
  key:_key
  value:_value
]

def new-table capacity:num -> result:&:table:_key:_value [
  local-scope
  load-ingredients
  result <- new {(table _key _value): type}
  data:&:@:table-row:_key:_value <- new {(table-row _key _value): type}, capacity
  *result <- merge 0/length, capacity, data
]

def put-index table:&:table:_key:_value, key:_key, value:_value -> table:&:table:_key:_value [
  local-scope
  load-ingredients
  hash:num <- hash key
  hash <- abs hash
  capacity:num <- get *table, capacity:offset
  _, hash-key:num <- divide-with-remainder hash, capacity
  hash-key <- abs hash-key  # in case hash overflows from a double into a negative integer inside 'divide-with-remainder' above
  table-data:&:@:table-row:_key:_value <- get *table, data:offset
  x:table-row:_key:_value <- index *table-data, hash-key
  occupied?:bool <- get x, occupied?:offset
  not-occupied?:bool <- not occupied?:bool
  assert not-occupied?, [can't handle collisions yet]
  new-row:table-row:_key:_value <- merge 1/true, key, value
  *table-data <- put-index *table-data, hash-key, new-row
]

def index table:&:table:_key:_value, key:_key -> result:_value [
  local-scope
  load-ingredients
  hash:num <- hash key
  hash <- abs hash
  capacity:num <- get *table, capacity:offset
  _, hash-key:num <- divide-with-remainder hash, capacity
  hash-key <- abs hash-key  # in case hash overflows from a double into a negative integer inside 'divide-with-remainder' above
  table-data:&:@:table-row:_key:_value <- get *table, data:offset
  x:table-row:_key:_value <- index *table-data, hash-key
  occupied?:bool <- get x, occupied?:offset
  assert occupied?, [can't handle missing elements yet]
  result <- get x, value:offset
]

def abs n:num -> result:num [
  local-scope
  load-ingredients
  positive?:bool <- greater-or-equal n, 0
  return-if positive?, n
  result <- multiply n, -1
]
