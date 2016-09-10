# compare immutable-error.mu

def main [
  local-scope
  x:address:number <- new number:type
  foo x
]

def foo x:address:number -> x:address:number [
  local-scope
  load-ingredients
  *x <- copy 34
]
