# A table is like an array, except that you can index it with arbitrary types
# and not just non-negative whole numbers.

# incomplete; doesn't handle hash conflicts

scenario table-read-write [
  local-scope
  tab:&:table:num:num <- new-table 30
  run [
    put-index tab, 12, 34
    60:num/raw, 61:bool/raw <- index tab, 12
  ]
  memory-should-contain [
    60 <- 34
    61 <- 1  # found
  ]
]

scenario table-read-write-non-integer [
  local-scope
  tab:&:table:text:num <- new-table 30
  run [
    put-index tab, [abc def], 34
    1:num/raw, 2:bool/raw <- index tab, [abc def]
  ]
  memory-should-contain [
    1 <- 34
    2 <- 1  # found
  ]
]

scenario table-read-not-found [
  local-scope
  tab:&:table:text:num <- new-table 30
  run [
    1:num/raw, 2:bool/raw <- index tab, [abc def]
  ]
  memory-should-contain [
    1 <- 0
    2 <- 0  # not found
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
  load-inputs
  result <- new {(table _key _value): type}
  data:&:@:table-row:_key:_value <- new {(table-row _key _value): type}, capacity
  *result <- merge 0/length, capacity, data
]

# todo: tag results as /required so that call-sites are forbidden from ignoring them
# then we could handle conflicts simply by resizing the table
def put-index table:&:table:_key:_value, key:_key, value:_value -> table:&:table:_key:_value [
  local-scope
  load-inputs
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

def index table:&:table:_key:_value, key:_key -> result:_value, found?:bool [
  local-scope
  load-inputs
  hash:num <- hash key
  hash <- abs hash
  capacity:num <- get *table, capacity:offset
  _, hash-key:num <- divide-with-remainder hash, capacity
  hash-key <- abs hash-key  # in case hash overflows from a double into a negative integer inside 'divide-with-remainder' above
  table-data:&:@:table-row:_key:_value <- get *table, data:offset
  x:table-row:_key:_value <- index *table-data, hash-key
  empty:&:_value <- new _value:type
  result <- copy *empty
  found?:bool <- get x, occupied?:offset
  return-unless found?
  key2:_key <- get x, key:offset
  found?:bool <- equal key, key2
  return-unless found?
  result <- get x, value:offset
]

def abs n:num -> result:num [
  local-scope
  load-inputs
  positive?:bool <- greater-or-equal n, 0
  return-if positive?, n
  result <- multiply n, -1
]
