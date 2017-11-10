# Example program showing how multiple functions with the same name can
# coexist, and how we select between them.
#
# Expected output:
#   4
#   7
#   7

def test a:num -> b:num [
  local-scope
  load-ingredients
  b <- add a, 1
]

def test a:num, b:num -> c:num [
  local-scope
  load-ingredients
  c <- add a, b
]

def main [
  local-scope
  a:num <- test 3  # selects single-ingredient version
  $print a, 10/newline
  b:num <- test 3, 4  # selects double-ingredient version
  $print b, 10/newline
  c:num <- test 3, 4, 5  # prefers double- to single-ingredient version
  $print c, 10/newline
]
