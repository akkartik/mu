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

recipe new-table capacity:number -> result:address:shared:table:_key:_value [
  local-scope
  load-ingredients
  result <- new {(table _key _value): type}
  tmp:address:number <- get-address *result, capacity:offset
  *tmp <- copy capacity
  data:address:address:shared:array:table_row:_key:_value <- get-address *result, data:offset
  *data <- new {(table_row _key _value): type}, capacity
]

recipe put table:address:shared:table:_key:_value, key:_key, value:_value -> table:address:shared:table:_key:_value [
  local-scope
  load-ingredients
  hash:number <- hash key
  capacity:number <- get *table, capacity:offset
  _, hash <- divide-with-remainder hash, capacity
  table-data:address:shared:array:table_row:_key:_value <- get *table, data:offset
  x:address:table_row:_key:_value <- index-address *table-data, hash
  occupied?:boolean <- get *x, occupied?:offset
  not-occupied?:boolean <- not occupied?:boolean
  assert not-occupied?, [can't handle collisions yet]
  *x <- merge 1/true, key, value
]

recipe index table:address:shared:table:_key:_value, key:_key -> result:_value [
  local-scope
  load-ingredients
  hash:number <- hash key
  capacity:number <- get *table, capacity:offset
  _, hash <- divide-with-remainder hash, capacity
  table-data:address:shared:array:table_row:_key:_value <- get *table, data:offset
  x:address:table_row:_key:_value <- index-address *table-data, hash
  occupied?:boolean <- get *x, occupied?:offset
  assert occupied?, [can't handle missing elements yet]
  result <- get *x, value:offset
]
