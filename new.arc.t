(load "mu.arc")
(load "new.arc")

(reset)
;? (prn memory*)
(if (~iso memory*.Root_custodian Allocator_start)
  (prn "F - allocator initialized"))

(reset)
(add-fns
  '((main
      ((x integer-address) <- new)
      ((x integer-address deref) <- literal 34))))
(run function*!main)
;? (prn memory*)
(if (~iso memory*.Root_custodian (+ Allocator_start 1))
  (prn "F - 'new' increments allocator pointer"))
(if (~iso memory*.Allocator_start 34)
  (prn "F - 'new' returns old location"))

; other tests to express:
;  no other function can increment the pointer
;  no later clause can increment the pointer after this base clause
;  multiple threads/routines can't call the allocator at once
