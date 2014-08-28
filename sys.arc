(load "mu.arc")

; memory map: 0-2 for convenience constants
(enq (fn ()
       (run `(((0 integer) <- literal 0)
              ((1 integer) <- literal 1)
              ((2 integer) <- literal 2))))
     initialization-fns*)

(enq (fn ()
       (build-type-table)
     initialization-fns*)

(= Free 3)
(= Type-array Free)
(def build-type-table ()
  (allocate-type-array)
  (build-types)
  (fill-in-type-array))

(def allocate-type-array ()
  (= memory*.Free len.types*)
  (++ Free)
  (++ Free len.types*))

(def build-types ()
  (each type types*  ; todo
    (

(def sizeof (typeinfo)
  (if (~or typeinfo!record typeinfo!array)
        typeinfo!size
      typeinfo!record
        (sum idfn
          (accum yield
            (each elem typeinfo!elems
              (yield (sizeof type*.elem)))))
      typeinfo!array
        (* (sizeof (type* typeinfo!elem))
           (


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
