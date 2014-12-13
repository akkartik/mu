; To demonstrate generic functions, we'll construct a factorial function with
; separate base and recursive clauses. Compare factorial.mu.

; def factorial n = n*factorial(n-1)
(def factorial [
  ((default-scope scope-address) <- new (scope literal) (30 literal))
  ((n integer) <- input (0 literal))
  more-clauses
  ((x integer) <- subtract (n integer) (1 literal))
  ((subresult integer) <- factorial (x integer))
  ((result integer) <- multiply (subresult integer) (n integer))
  (reply (result integer))
])

; def factorial 0 = 1
(after factorial/more-clauses [
  { begin
    ((zero? boolean) <- equal (n integer) (0 literal))
    (break-unless (zero? boolean))
    (reply (1 literal))
  }
])

(def main [
  ((1 integer) <- factorial (5 literal))
  (print-primitive ("result: " literal))
  (print-primitive (1 integer))
  (print-primitive ("\n" literal))
])
