# example program: compute the factorial of 5

recipe main [
  default-space:address:array:location <- new location:type, 30:literal
  x:number <- factorial 5:literal
  $print [result: ], x:number, [ 
]
]

recipe factorial [
  default-space:address:array:location <- new location:type, 30:literal
  n:number <- next-ingredient
  {
    # if n=0 return 1
    zero?:boolean <- equal n:number, 0:literal
    break-unless zero?:boolean
    reply 1:literal
  }
  # return n * factorial(n-1)
  x:number <- subtract n:number, 1:literal
  subresult:number <- factorial x:number
  result:number <- multiply subresult:number, n:number
  reply result:number
]

# unit test
scenario factorial-test [
  run [
    1:number <- factorial 5:literal
  ]
  memory-should-contain [
    1 <- 120
  ]
]
