(load "mu.arc")
(load "new.arc")

(reset)
(add-fns
  '((main)))
(run function*!main)
(if (~iso memory* (obj Root_allocator_pointer 1000))
  (prn "F - allocator initialized"))

(reset)
(add-fns
  '((main
      ((x integer-address) <- new)
      ((x integer-address deref) <- literal 34))))
(run function*!main)
;? (prn memory*)
(if (~iso memory*!Root_allocator_pointer 1001)
  (prn "F - 'new' increments allocator pointer"))
