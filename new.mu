; memory map: 1-1000 reserved for the (currently non-reentrant) allocator
(main
  ((integer 1) <- literal 1000)  ; location 1 contains the high-water mark for the memory allocator
  ((integer-pointer 4) <- new)
  ((integer 5) <- deref (integer-pointer 4))
)

(new
  ((integer-pointer 2) <- copy (integer 1))
  ((integer 3) <- literal 1)
  ((integer 1) <- add (integer 1) (integer 3))
  (reply (integer-pointer 2)))

;; vim:ft=scheme
