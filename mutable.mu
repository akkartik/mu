# compare immutable-error.mu

def main [
  local-scope
  x:&:num <- new number:type
  foo x
]

def foo x:&:num -> x:&:num [
  local-scope
  load-ingredients
  *x <- copy 34
]
