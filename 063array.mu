scenario array-from-args [
  run [
    local-scope
    x:&:@:char <- new-array 0, 1, 2
    10:@:char/raw <- copy *x
  ]
  memory-should-contain [
    10 <- 3  # array length
    11 <- 0
    12 <- 1
    13 <- 2
  ]
]

# create an array out of a list of scalar args
# hacky; needs to be generic
def new-array -> result:&:@:char [
  local-scope
  capacity:num <- copy 0
  {
    # while read curr-value
    curr-value:char, exists?:bool <- next-ingredient
    break-unless exists?
    capacity <- add capacity, 1
    loop
  }
  result <- new character:type, capacity
  rewind-ingredients
  i:num <- copy 0
  {
    # while read curr-value
    done?:bool <- greater-or-equal i, capacity
    break-if done?
    curr-value:char, exists?:bool <- next-ingredient
    assert exists?, [error in rewinding ingredients to new-array]
    *result <- put-index *result, i, curr-value
    i <- add i, 1
    loop
  }
  return result
]
