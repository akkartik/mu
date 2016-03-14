scenario array-from-args [
  run [
    1:address:shared:array:character <- new-array 0, 1, 2
    2:array:character <- copy *1:address:shared:array:character
  ]
  memory-should-contain [
    2 <- 3  # array length
    3 <- 0
    4 <- 1
    5 <- 2
  ]
]

# create an array out of a list of scalar args
def new-array -> result:address:shared:array:character [
  local-scope
  capacity:number <- copy 0
  {
    # while read curr-value
    curr-value:character, exists?:boolean <- next-ingredient
    break-unless exists?
    capacity <- add capacity, 1
    loop
  }
  result <- new character:type, capacity
  rewind-ingredients
  i:number <- copy 0
  {
    # while read curr-value
    done?:boolean <- greater-or-equal i, capacity
    break-if done?
    curr-value:character, exists?:boolean <- next-ingredient
    assert exists?, [error in rewinding ingredients to new-array]
    tmp:address:character <- index-address *result, i
    *tmp <- copy curr-value
    i <- add i, 1
    loop
  }
  return result
]
