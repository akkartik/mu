def barz x:_elem [
  local-scope
  load-ingredients
  y:address:shared:number <- new _elem:type
]

def fooz [
  local-scope
  barz 34
]
