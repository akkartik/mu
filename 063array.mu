scenario array-from-args [
  run [
    local-scope
    x:address:array:character <- new-array 0, 1, 2
    10:array:character/raw <- copy *x
  ]
  memory-should-contain [
    10 <- 3  # array length
    11 <- 0
    12 <- 1
    13 <- 2
  ]
]

# create an array out of a list of scalar args
def new-array -> result:address:array:character [
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
    *result <- put-index *result, i, curr-value
    i <- add i, 1
    loop
  }
  return result
]
