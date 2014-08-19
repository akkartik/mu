;; simple slab allocator. Intended only to carve out isolated memory for
;; different threads/routines as they request.

(= Allocator_start 1000)  ; lower locations reserved

(enq (fn ()
       (run `(((Root_allocator_pointer location) <- literal ,Allocator_start))))
     initialization-fns*)

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
