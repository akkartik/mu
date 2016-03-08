# example program: compute the factorial of 5

def main [
  local-scope
  x:number <- factorial 5
  $print [result: ], x, [ 
]
]

def factorial n:number -> result:number [
  local-scope
  load-ingredients
  {
    # if n=0 return 1
    zero?:boolean <- equal n, 0
    break-unless zero?
    return 1
  }
  # return n * factorial(n-1)
  x:number <- subtract n, 1
  subresult:number <- factorial x
  result <- multiply subresult, n
]

# unit test
scenario factorial-test [
  run [
    1:number <- factorial 5
  ]
  memory-should-contain [
    1 <- 120
  ]
]
