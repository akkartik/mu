# example program: maintain multiple counters with isolated lexical scopes
# (spaces)

def new-counter n:num -> default-space:space [
  default-space <- new location:type, 30
  load-inputs  # initialize n
]

def increment-counter outer:space/names:new-counter, x:num -> n:num/space:1 [
  local-scope
  load-inputs
  0:space/names:new-counter <- copy outer  # setup outer space; it *must* come from 'new-counter'
  n/space:1 <- add n/space:1, x
]

def main [
  local-scope
  # counter A
  a:space/names:new-counter <- new-counter 34
  # counter B
  b:space/names:new-counter <- new-counter 23
  # increment both by 2 but in different ways
  increment-counter a, 1
  b-value:num <- increment-counter b, 2
  a-value:num <- increment-counter a, 1
  # check results
  $print [Contents of counters], 10/newline
  $print [a: ], a-value, [ b: ], b-value, 10/newline
]
