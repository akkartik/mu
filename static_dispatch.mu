def test a:number -> b:number [
  local-scope
  load-ingredients
  b <- add a, 1
]

def test a:number, b:number -> c:number [
  local-scope
  load-ingredients
  c <- add a, b
]

def main [
  local-scope
  a:number <- test 3  # selects single-ingredient version
  $print a, 10/newline
  b:number <- test 3, 4  # selects double-ingredient version
  $print b, 10/newline
  c:number <- test 3, 4, 5  # prefers double- to single-ingredient version
  $print c, 10/newline
]
