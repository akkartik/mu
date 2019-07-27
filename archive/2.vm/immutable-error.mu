# compare mutable.mu

def main [
  local-scope
  x:&:num <- new number:type
  foo x
]

def foo x:&:num [
  local-scope
  load-inputs
  *x <- copy 34  # will cause an error because x is immutable in this function
]
