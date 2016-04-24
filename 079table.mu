# A table is like an array, except that its keys are not integers but
# arbitrary types.

scenario table-read-write [
  run [
    1:address:table:number:number <- new-table 30
    put 1:address:table:number:number, 12, 34
    2:number <- index 1:address:table:number:number, 12
  ]
  memory-should-contain [
    2 <- 34
  ]
]

scenario table-read-write-non-integer [
  run [
    1:address:array:character <- new [abc def]
    {2: (address table (address array character) number)} <- new-table 30
    put {2: (address table (address array character) number)}, 1:address:array:character, 34
    3:number <- index {2: (address table (address array character) number)}, 1:address:array:character
  ]
  memory-should-contain [
    3 <- 34
  ]
]

container table:_key:_value [
  length:number
  capacity:number
  data:address:array:table_row:_key:_value
]

container table_row:_key:_value [
  occupied?:boolean
  key:_key
  value:_value
]

def new-table capacity:number -> result:address:table:_key:_value [
  local-scope
  load-ingredients
  result <- new {(table _key _value): type}
  data:address:array:table_row:_key:_value <- new {(table_row _key _value): type}, capacity
  *result <- merge 0/length, capacity, data
]

def put table:address:table:_key:_value, key:_key, value:_value -> table:address:table:_key:_value [
  local-scope
  load-ingredients
  hash:number <- hash key
  hash <- abs hash
  capacity:number <- get *table, capacity:offset
  _, hash <- divide-with-remainder hash, capacity
  hash <- abs hash  # in case hash overflows into a negative integer
  table-data:address:array:table_row:_key:_value <- get *table, data:offset
  x:table_row:_key:_value <- index *table-data, hash
  occupied?:boolean <- get x, occupied?:offset
  not-occupied?:boolean <- not occupied?:boolean
  assert not-occupied?, [can't handle collisions yet]
  new-row:table_row:_key:_value <- merge 1/true, key, value
  *table-data <- put-index *table-data, hash, new-row
]

def abs n:number -> result:number [
  local-scope
  load-ingredients
  positive?:boolean <- greater-or-equal n, 0
  return-if positive?, n
  result <- multiply n, -1
]

def index table:address:table:_key:_value, key:_key -> result:_value [
  local-scope
  load-ingredients
  hash:number <- hash key
  hash <- abs hash
  capacity:number <- get *table, capacity:offset
  _, hash <- divide-with-remainder hash, capacity
  hash <- abs hash  # in case hash overflows into a negative integer
  table-data:address:array:table_row:_key:_value <- get *table, data:offset
  x:table_row:_key:_value <- index *table-data, hash
  occupied?:boolean <- get x, occupied?:offset
  assert occupied?, [can't handle missing elements yet]
  result <- get x, value:offset
]
