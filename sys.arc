(load "mu.arc")

; memory map: 0-2 for convenience numbers
; for these, address == value always; never modify them
(= Zero 0)
(= One 1)
(= Two 2)

(enq (fn ()
       (run `(((,Zero integer) <- literal 0)
              ((,One integer) <- literal 1)
              ((,Two integer) <- literal 2))))
     initialization-fns*)

; high-water mark for global memory used so far
; just on host, not in simulated memory
(= Memory-used-until 3)
(def static-new (n)
  (inc Memory-used-until n))

; copy types* info into simulated machine
(= Type-table Memory-used-until)
(enq (fn ()
       (each (type typeinfo)  types*
         (prn type " " typeinfo)))
     initialization-fns*)

(reset)

(init-fn sizeof)  ; todo

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
