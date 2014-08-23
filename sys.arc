(load "mu.arc")

; memory map: 0-2 for convenience constants
(enq (fn ()
       (run `(((0 integer) <- literal 0)
              ((1 integer) <- literal 1)
              ((2 integer) <- literal 2))))
     initialization-fns*)

; todo: copy types* info into simulated machine
; todo: sizeof

;; 'new' - simple slab allocator. Intended only to carve out isolated memory
;; for different threads/routines as they request.
; memory map: 3 for root custodian (size 1)
(= Root_custodian 3)
(= Allocator_start 1000)  ; lower locations reserved

(enq (fn ()
       (run `(((,Root_custodian location) <- literal ,Allocator_start))))
     initialization-fns*)

; (type-addr val) <- new (custodian x), (type t)
; memory map: 4-5 locals for slab allocator
(init-fn new
  ((4 integer-address) <- copy (3 location))
  ((3 location) <- add (3 location) (1 integer))
  (reply (4 integer-address)))
