; in mu, call-cc (http://en.wikipedia.org/wiki/Call-with-current-continuation)
; is constructed out of a combination of two primitives:
;   'current-continuation', which returns a continuation, and
;   'continue-from', which takes a continuation to

(function g [
  (c:continuation <- current-continuation)  ; <-- loop back to here
  (print-primitive-to-host (("a" literal)))
  (reply c:continuation)
])

(function f [
  (c:continuation <- g)
  (reply c:continuation)
])

(function main [
  (c:continuation <- f)
  (continue-from c:continuation)            ; <-- ..when you hit this
])
