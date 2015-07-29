# example program: compute the factorial of 5

recipe main [
  local-scope
  x:number <- factorial 5
  $print [result: ], x, [ 
]
]

recipe factorial [
  local-scope
  n:number <- next-ingredient
  {
    # if n=0 return 1
    zero?:boolean <- equal n, 0
    break-unless zero?
    reply 1
  }
  # return n * factorial(n-1)
  x:number <- subtract n, 1
  subresult:number <- factorial x
  result:number <- multiply subresult, n
  reply result
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
