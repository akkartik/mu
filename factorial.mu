# example program: compute the factorial of 5

def main [
  local-scope
  x:num <- factorial 5
  $print [result: ], x, [ 
]
]

def factorial n:num -> result:num [
  local-scope
  load-ingredients
  # if n=0 return 1
  return-unless n, 1
  # return n * factorial(n-1)
  x:num <- subtract n, 1
  subresult:num <- factorial x
  result <- multiply subresult, n
]

# unit test
scenario factorial-test [
  run [
    1:num <- factorial 5
  ]
  memory-should-contain [
    1 <- 120
  ]
]
