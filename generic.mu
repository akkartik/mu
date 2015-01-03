; To demonstrate generic functions, we'll construct a factorial function with
; separate base and recursive clauses. Compare factorial.mu.

; factorial n = n*factorial(n-1)
(function factorial [
  (default-space:space-address <- new space:literal 30:literal)
  (n:integer <- input 0:literal)
  more-clauses
  (x:integer <- subtract n:integer 1:literal)
  (subresult:integer <- factorial x:integer)
  (result:integer <- multiply subresult:integer n:integer)
  (reply result:integer)
])

; factorial 0 = 1
(after factorial/more-clauses [
  { begin
    (zero?:boolean <- equal n:integer 0:literal)
    (break-unless zero?:boolean)
    (reply 1:literal)
  }
])

(function main [
  (1:integer <- factorial 5:literal)
  (print-primitive (("result: " literal)))
  (print-primitive 1:integer)
  (print-primitive (("\n" literal)))
])
