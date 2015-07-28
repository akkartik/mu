scenario array-from-args [
  run [
    1:address:array:location <- new-array 0, 1, 2
    2:array:location <- copy 1:address:array:location/lookup
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
    break-unless exists?:boolean
    capacity:number <- add capacity:number, 1
    loop
  }
  result:address:array:location <- new location:type, capacity:number
  rewind-ingredients
  i:number <- copy 0
  {
    # while read curr-value
    done?:boolean <- greater-or-equal i:number, capacity:number
    break-if done?:boolean
    curr-value:location, exists?:boolean <- next-ingredient
    assert exists?:boolean, [error in rewinding ingredients to new-array]
    tmp:address:location <- index-address result:address:array:location/lookup, i:number
    tmp:address:location/lookup <- copy curr-value:location
    i:number <- add i:number, 1
    loop
  }
  reply result:address:array:location
]
