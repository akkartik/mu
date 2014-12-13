(function factorial [
  ((default-scope scope-address) <- new (scope literal) (30 literal))
  ((n integer) <- next-input)
  { begin
    ; if n=0 return 1
    ((zero? boolean) <- equal (n integer) (0 literal))
    (break-unless (zero? boolean))
    (reply (1 literal))
  }
  ; return n*factorial(n-1)
  ((x integer) <- subtract (n integer) (1 literal))
  ((subresult integer) <- factorial (x integer))
  ((result integer) <- multiply (subresult integer) (n integer))
  (reply (result integer))
])

(function main [
  ((1 integer) <- factorial (5 literal))
  (print-primitive ("result: " literal))
  (print-primitive (1 integer))
  (print-primitive ("\n" literal))
])
