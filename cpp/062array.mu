scenario array-from-args [
  run [
    1:address:array:location <- init-array 0:literal, 1:literal, 2:literal
    2:array:location <- copy 1:address:array:location/deref
  ]
  memory should contain [
    2 <- 3  # array length
    3 <- 0
    4 <- 1
    5 <- 2
  ]
]

# create an array out of a list of scalar args
recipe init-array [
  default-space:address:array:location <- new location:type, 30:literal
  capacity:integer <- copy 0:literal
  {
    # while read curr-value
    curr-value:location, exists?:boolean <- next-ingredient
    break-unless exists?:boolean
    capacity:integer <- add capacity:integer, 1:literal
    loop
  }
  result:address:array:location <- new location:type, capacity:integer
  rewind-ingredients
  i:integer <- copy 0:literal
  {
    # while read curr-value
    done?:boolean <- greater-or-equal i:integer, capacity:integer
    break-if done?:boolean
    curr-value:location, exists?:boolean <- next-ingredient
    assert exists?:boolean, [error in rewinding ingredients to init-array]
    tmp:address:location <- index-address result:address:array:location/deref, i:integer
    tmp:address:location/deref <- copy curr-value:location
    i:integer <- add i:integer, 1:literal
    loop
  }
  reply result:address:array:location
]
