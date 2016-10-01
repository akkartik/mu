scenario array-from-args [
  run [
    local-scope
    x:&:@:num <- new-array 0, 1, 2
    10:@:num/raw <- copy *x
  ]
  memory-should-contain [
    10 <- 3  # array length
    11 <- 0
    12 <- 1
    13 <- 2
  ]
]

# create an array out of a list of args
def new-array -> result:&:@:_elem [
  local-scope
  capacity:num <- copy 0
  {
    # while read curr-value
    curr-value:_elem, exists?:bool <- next-ingredient
    break-unless exists?
    capacity <- add capacity, 1
    loop
  }
  result <- new _elem:type, capacity
  rewind-ingredients
  i:num <- copy 0
  {
    # while read curr-value
    done?:bool <- greater-or-equal i, capacity
    break-if done?
    curr-value:_elem, exists?:bool <- next-ingredient
    assert exists?, [error in rewinding ingredients to new-array]
    *result <- put-index *result, i, curr-value
    i <- add i, 1
    loop
  }
  return result
]

# fill an existing array with a set of numbers
# (contributed by Caleb Couch)
def fill array:&:@:num -> array:&:@:num [
  local-scope
  load-ingredients
  loopn:num <- copy 0
  length:num <- length *array
  {
    length?:bool <- equal loopn, length
    break-if length?
    object:num, arg-received?:bool <- next-ingredient
    break-unless arg-received?
    *array <- put-index *array, loopn, object
    loopn <- add loopn, 1
    loop
  }
]

scenario fill-on-an-empty-array [
  local-scope
  array:&:@:num <- new number:type, 3
  run [
    array <- fill array, 1 2 3
    10:@:num/raw <- copy *array
  ]
  memory-should-contain [
    10 <- 3
    11 <- 1
    12 <- 2
    13 <- 3
  ]
]

scenario fill-overwrites-existing-values [
  local-scope
  array:&:@:num <- new number:type, 3
  *array <- put-index *array, 0, 4
  run [
    array <- fill array, 1 2 3
    10:@:num/raw <- copy *array
  ]
  memory-should-contain [
    10 <- 3
    11 <- 1
    12 <- 2
    13 <- 3
  ]
]

scenario fill-exits-gracefully-when-given-no-ingredients [
  local-scope
  array:&:@:num <- new number:type, 3
  run [
    array <- fill array
    10:@:num/raw <- copy *array
  ]
  memory-should-contain [
    10 <- 3
    11 <- 0
    12 <- 0
    13 <- 0
  ]
]

# swap two elements of an array
# (contributed by Caleb Couch)
def swap array:&:@:num, index1:num, index2:num -> array:&:@:num [
  local-scope
  load-ingredients
  object1:num <- index *array, index1
  object2:num <- index *array, index2
  *array <- put-index *array, index1, object2
  *array <- put-index *array, index2, object1
]

scenario swap-works [
  local-scope
  array:&:@:num <- new number:type, 4
  array <- fill array, 4 3 2 1
  run [
    array <- swap array, 0, 2
    10:num/raw <- index *array, 0
    11:num/raw <- index *array, 2
  ]
  memory-should-contain [
    10 <- 2
    11 <- 4
  ]
]

# reverse the elements of an array
# (contributed by Caleb Couch)
def reverse array:&:@:_elem -> array:&:@:_elem [
  local-scope
  load-ingredients
  start:num <- copy 0
  length:num <- length *array
  end:num <- subtract length, 1
  {
    done?:bool <- greater-or-equal start, end
    break-if done?
    array <- swap array, start, end
    start <- add start, 1
    end <- subtract end, 1
    loop
  }
]

scenario reverse-array-odd-length [
  local-scope
  array:&:@:num <- new number:type, 3
  array <- fill array, 3 2 1
  run [
    array <- reverse array
    10:@:num/raw <- copy *array
  ]
  memory-should-contain [
    10 <- 3
    11 <- 1
    12 <- 2
    13 <- 3
  ]
]

scenario reverse-array-even-length [
  local-scope
  array:&:@:num <- new number:type, 4
  array <- fill array, 4 3 2 1
  run [
    array <- reverse array
    10:@:num/raw <- copy *array
  ]
  memory-should-contain [
    10 <- 4
    11 <- 1
    12 <- 2
    13 <- 3
    14 <- 4
  ]
]
