;; simple slab allocator. Intended only to carve out isolated memory for
;; different threads/routines as they request.

(on-init
  ((Root_allocator_pointer location) <- literal 1000)  ; 1-1000 reserved
)

(init-fn new
  ((2 integer-address) <- copy (Root_allocator_pointer integer))
  ((3 integer) <- literal 1)
  ((Root_allocator_pointer integer) <- add (Root_allocator_pointer integer) (3 integer))
  (reply (2 integer-address)))
; tests to express:
; every call increments the pointer
; no other function can increment the pointer
; no later clause can increment the pointer after this base clause
; multiple threads/routines can't call the allocator at once
