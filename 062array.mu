scenario array-from-args [
  run [
    1:address:array:location <- new-array 0:literal, 1:literal, 2:literal
    2:array:location <- copy 1:address:array:location/deref
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
  default-space:address:array:location <- new location:type, 30:literal
  capacity:number <- copy 0:literal
  {
    # while read curr-value
    curr-value:location, exists?:boolean <- next-ingredient
    break-unless exists?:boolean
    capacity:number <- add capacity:number, 1:literal
    loop
  }
  result:address:array:location <- new location:type, capacity:number
  rewind-ingredients
  i:number <- copy 0:literal
  {
    # while read curr-value
    done?:boolean <- greater-or-equal i:number, capacity:number
    break-if done?:boolean
    curr-value:location, exists?:boolean <- next-ingredient
    assert exists?:boolean, [error in rewinding ingredients to new-array]
    tmp:address:location <- index-address result:address:array:location/deref, i:number
    tmp:address:location/deref <- copy curr-value:location
    i:number <- add i:number, 1:literal
    loop
  }
  reply result:address:array:location
]
