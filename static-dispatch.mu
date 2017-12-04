# Example program showing how multiple functions with the same name can
# coexist, and how we select between them.
#
# Expected output:
#   4
#   7
#   7

def test a:num -> b:num [
  local-scope
  load-inputs
  b <- add a, 1
]

def test a:num, b:num -> c:num [
  local-scope
  load-inputs
  c <- add a, b
]

def main [
  local-scope
  a:num <- test 3  # selects single-input version
  $print a, 10/newline
  b:num <- test 3, 4  # selects double-input version
  $print b, 10/newline
  c:num <- test 3, 4, 5  # prefers double- to single-input version
  $print c, 10/newline
]
