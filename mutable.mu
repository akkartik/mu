# compare immutable-error.mu

def main [
  local-scope
  x:address:num <- new number:type
  foo x
]

def foo x:address:num -> x:address:num [
  local-scope
  load-ingredients
  *x <- copy 34
]
