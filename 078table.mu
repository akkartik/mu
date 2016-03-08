# A table is like an array, except that its keys are not integers but
# arbitrary types.

scenario table-read-write [
  run [
    1:address:shared:table:number:number <- new-table 30
    put 1:address:shared:table:number:number, 12, 34
    2:number <- index 1:address:shared:table:number:number, 12
  ]
  memory-should-contain [
    2 <- 34
  ]
]

scenario table-read-write-non-integer [
  run [
    1:address:shared:array:character <- new [abc def]
    {2: (address shared table (address shared array character) number)} <- new-table 30
    put {2: (address shared table (address shared array character) number)}, 1:address:shared:array:character, 34
    3:number <- index {2: (address shared table (address shared array character) number)}, 1:address:shared:array:character
  ]
  memory-should-contain [
    3 <- 34
  ]
]

container table:_key:_value [
  length:number
  capacity:number
  data:address:shared:array:table_row:_key:_value
]

container table_row:_key:_value [
  occupied?:boolean
  key:_key
  value:_value
]

def new-table capacity:number -> result:address:shared:table:_key:_value [
  local-scope
  load-ingredients
  result <- new {(table _key _value): type}
  tmp:address:number <- get-address *result, capacity:offset
  *tmp <- copy capacity
  data:address:address:shared:array:table_row:_key:_value <- get-address *result, data:offset
  *data <- new {(table_row _key _value): type}, capacity
]

def put table:address:shared:table:_key:_value, key:_key, value:_value -> table:address:shared:table:_key:_value [
  local-scope
  load-ingredients
  hash:number <- hash key
  hash <- abs hash
  capacity:number <- get *table, capacity:offset
  _, hash <- divide-with-remainder hash, capacity
  hash <- abs hash  # in case hash overflows into a negative integer
  table-data:address:shared:array:table_row:_key:_value <- get *table, data:offset
  x:address:table_row:_key:_value <- index-address *table-data, hash
  occupied?:boolean <- get *x, occupied?:offset
  not-occupied?:boolean <- not occupied?:boolean
  assert not-occupied?, [can't handle collisions yet]
  *x <- merge 1/true, key, value
]

def abs n:number -> result:number [
  local-scope
  load-ingredients
  positive?:boolean <- greater-or-equal n, 0
  return-if positive?, n
  result <- multiply n, -1
]

def index table:address:shared:table:_key:_value, key:_key -> result:_value [
  local-scope
  load-ingredients
  hash:number <- hash key
  hash <- abs hash
  capacity:number <- get *table, capacity:offset
  _, hash <- divide-with-remainder hash, capacity
  hash <- abs hash  # in case hash overflows into a negative integer
  table-data:address:shared:array:table_row:_key:_value <- get *table, data:offset
  x:table_row:_key:_value <- index *table-data, hash
  occupied?:boolean <- get x, occupied?:offset
  assert occupied?, [can't handle missing elements yet]
  result <- get x, value:offset
]
