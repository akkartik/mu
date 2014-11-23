(factorial
  ((default-scope scope-address) <- new (scope literal) (30 literal))
  ((n integer) <- arg)
  { begin
    ; if n=0 return 1
    ((zero? boolean) <- eq (n integer) (0 literal))
    (break-unless (zero? boolean))
    (reply (1 literal))
  }
  ; return n*factorial(n-1)
  ((x integer) <- sub (n integer) (1 literal))
  ((subresult integer) <- factorial (x integer))
  ((result integer) <- mul (subresult integer) (n integer))
  (reply (result integer)))

(main
  ((1 integer) <- factorial (5 literal))
  (print-primitive ("result: " literal))
  (print-primitive (1 integer))
  (print-primitive ("\n" literal)))
