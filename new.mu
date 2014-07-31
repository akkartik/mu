; memory map: 1-1000 reserved for the (currently non-reentrant) allocator
(main
  ((1 integer) <- literal 1000)  ; location 1 contains the high-water mark for the memory allocator
  ((4 integer-address) <- new)
  ((5 integer) <- copy (4 integer-address deref))
)

(new
  ((2 integer-address) <- copy (1 integer))
  ((3 integer) <- literal 1)
  ((1 integer) <- add (1 integer) (3 integer))
  (reply (2 integer-address)))

;; vim:ft=scheme
