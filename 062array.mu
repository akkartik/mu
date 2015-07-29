scenario array-from-args [
  run [
    1:address:array:location <- new-array 0, 1, 2
    2:array:location <- copy *1:address:array:location
  ]
  memory-should-contain [
    2 <- 3  # array length
    3 <- 0
    4 <- 1
    5 <- 2
  ]
]

# create an array out of a list of scalar args
recipe new-array [
  local-scope
  capacity:number <- copy 0
  {
    # while read curr-value
    curr-value:location, exists?:boolean <- next-ingredient
    break-unless exists?
    capacity <- add capacity, 1
    loop
  }
  result:address:array:location <- new location:type, capacity
  rewind-ingredients
  i:number <- copy 0
  {
    # while read curr-value
    done?:boolean <- greater-or-equal i, capacity
    break-if done?
    curr-value:location, exists?:boolean <- next-ingredient
    assert exists?, [error in rewinding ingredients to new-array]
    tmp:address:location <- index-address *result, i
    *tmp <- copy curr-value
    i <- add i, 1
    loop
  }
  reply result
]
