; Memory management primitive.

(= Allocator_start 1000)  ; lower locations reserved

; memory map: 0-2 for convenience numbers
; for these, address == value always; never modify them
(= Zero 0)
(= One 1)
(= Two 2)
; memory map: 3 for root custodian (size 1)
; 'new' will allocate from custodians. Custodians will be arranged in trees,
; each node knowing its parent. The root custodian controls all memory
; allocations. And it's located at..
(= Root_custodian 3)

(enq (fn ()
       (run `(((,Zero integer) <- literal 0)
              ((,One integer) <- literal 1)
              ((,Two integer) <- literal 2)
              ((,Root_custodian location) <- literal ,Allocator_start))))
     initialization-fns*)

;; simple slab allocator. Intended only to carve out isolated memory for
;; different threads/routines as they request.
; memory map: 4-5 locals for slab allocator
(init-fn new
  ((4 integer-address) <- copy (3 location))
  ((3 location) <- add (3 location) (1 integer))
  (reply (4 integer-address)))
