; To demonstrate tangle directives, we'll construct a factorial function with
; separate base and recursive cases. Compare factorial.mu.
; This isn't a very realistic example, just a simple demonstration of
; possibilities.

(after base-case [
  ; if n=0 return 1
  ((zero? boolean) <- eq (n integer) (0 literal))
  (break-unless (zero? boolean))
  (reply (1 literal))
])

(after recursive-case [
  ; return n*factorial(n-1)
  ((x integer) <- sub (n integer) (1 literal))
  ((subresult integer) <- factorial (x integer))
  ((result integer) <- mul (subresult integer) (n integer))
  (reply (result integer))
])

(def factorial [
  ((default-scope scope-address) <- new (scope literal) (30 literal))
  ((n integer) <- arg)
  { begin
    base-case
  }
  recursive-case
])

(def main [
  ((1 integer) <- factorial (5 literal))
  (print-primitive ("result: " literal))
  (print-primitive (1 integer))
  (print-primitive ("\n" literal))
])

;? (((default-scope scope-address) <- new (scope literal) (30 literal))
;?  ((n integer) <- arg)
;?  { begin
;?    base-case
;?  }
;?  recursive-case
;?  ((x integer) <- sub (n integer) (1 literal))
;?  ((subresult integer) <- factorial (x integer))
;?  ((result integer) <- mul (subresult integer) (n integer))
;?  (reply (result integer)))
;? 
;? (((1 integer) <- factorial (5 literal)) (print-primitive (result:  literal)) (print-primitive (1 integer)) (print-primitive (
;?  literal)))
;? 
