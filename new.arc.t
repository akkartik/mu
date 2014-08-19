(load "mu.arc")
(load "new.arc")

(reset)
(add-fns
  '((main)))
(run function*!main)
(if (~iso memory*!Root_allocator_pointer Allocator_start)
  (prn "F - allocator initialized"))

(reset)
(add-fns
  '((main
      ((x integer-address) <- new)
      ((x integer-address deref) <- literal 34))))
(run function*!main)
;? (prn memory*)
(if (~iso memory*!Root_allocator_pointer (+ Allocator_start 1))
  (prn "F - 'new' increments allocator pointer"))
(if (~iso memory*.Allocator_start 34)
  (prn "F - 'new' returns old location"))
