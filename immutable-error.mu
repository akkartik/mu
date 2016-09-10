# compare mutable.mu

def main [
  local-scope
  x:address:number <- new number:type
  foo x
]

def foo x:address:number [
  local-scope
  load-ingredients
  *x <- copy 34  # will cause an error because x is immutable in this function
]
