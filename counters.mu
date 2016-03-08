# example program: maintain multiple counters with isolated lexical scopes
# (spaces)

def new-counter n:number -> default-space:address:shared:array:location [
  default-space <- new location:type, 30
  load-ingredients
]

def increment-counter outer:address:shared:array:location/names:new-counter, x:number -> n:number/space:1 [
  local-scope
  load-ingredients
  0:address:shared:array:location/names:new-counter <- copy outer  # setup outer space; it *must* come from 'new-counter'
  n/space:1 <- add n/space:1, x
]

def main [
  local-scope
  # counter A
  a:address:shared:array:location <- new-counter 34
  # counter B
  b:address:shared:array:location <- new-counter 23
  # increment both by 2 but in different ways
  increment-counter a, 1
  b-value:number <- increment-counter b, 2
  a-value:number <- increment-counter a, 1
  # check results
  $print [Contents of counters], 10/newline
  # trailing space in next line is to help with syntax highlighting
  $print [a: ], a-value, [ b: ], b-value,  10/newline
]
