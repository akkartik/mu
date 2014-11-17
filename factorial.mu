(factorial
  ((default-scope scope-address) <- new (scope literal) (30 literal))
  ((n integer) <- arg)
  { begin
    ((zero? boolean) <- eq (n integer) (0 literal))
    (break-unless (zero? boolean))
    (reply (1 literal))
  }
  ((x integer) <- sub (n integer) (1 literal))
  ((subresult integer) <- factorial (x integer))
  ((result integer) <- mul (subresult integer) (n integer))
  (reply (result integer)))

(main
  ((1 integer) <- factorial (5 literal)))
