; things that a future assembler will need separate memory for:
;   code; types; args channel
(= initialization-fns* (queue))
(def reset ()
  (each f (as cons initialization-fns*)
    (f)))

(def clear ()
  (= types* (obj
              ; must be scalar or array, sum or product or primitive
              type (obj size 1)
              location (obj size 1)
              integer (obj size 1)
              boolean (obj size 1)
              integer-array (obj array t  elem 'integer)  ; arrays provide size at front
              integer-address (obj size 1  address t  elem 'integer)  ; pointer to int
              block (obj size 1024  array t  elem 'location)  ; last elem points to next block when this one fills up
              block-address (obj size 1  address t  elem 'block)
              integer-boolean-pair (obj size 2  record t  elems '(integer boolean))
              integer-boolean-pair-address (obj size 1  address t  elem 'integer-boolean-pair)
              integer-boolean-pair-array (obj array t  elem 'integer-boolean-pair)
              integer-integer-pair (obj size 2  record t  elems '(integer integer))
              integer-point-pair (obj size 2  record t  elems '(integer integer-integer-pair))
              ))
  (= memory* (table))
  (= function* (table)))
(enq clear initialization-fns*)

(mac init-fn (name . body)
  `(enq (fn () (= (function* ',name) ',body))
        initialization-fns*))

(mac on-init body
  `(enq (fn () (run ',body))
        initialization-fns*))

(def add-fns (fns)
  (each (name . body) fns
    (= function*.name body)))

(def v (operand)  ; for value
  operand.0)

(def metadata (operand)
  cdr.operand)

(def ty (operand)
  operand.1)  ; assume type is always first bit of metadata, and it's always present

(def typeinfo (operand)
  (types* ty.operand))

(def sz (operand)
;?   (prn "sz " operand)
  ; todo: override this for arrays
  typeinfo.operand!size)
(defextend sz (typename) (isa typename 'sym)
  types*.typename!size)

(mac addr (loc)
  `(let loc@ ,loc
     (if (pos 'deref (metadata loc@))
       (memory* (v loc@))
       (v loc@))))

(def addrs (n sz)
  (accum yield
    (repeat sz
      (yield n)
      (++ n))))

(mac m (loc)  ; read memory, respecting metadata
  `(let loc@ ,loc
;?      (prn "m " loc@ sz.loc@)
     (if (is 1 sz.loc@)
       (memory* (addr loc@))
       (annotate 'record
                 (map memory* (addrs (addr loc@) sz.loc@))))))

(mac setm (loc val)  ; set memory, respecting metadata
  `(with (loc@ ,loc
          val@ ,val)
;?      (prn "setm " loc@ " " val@)
     (if (is 1 sz.loc@)
       (= (memory* (addr loc@)) val@)
       (each (dest@ src@) (zip (addrs (addr loc@) sz.loc@)
                               (rep val@))
         (= (memory* dest@) src@)))))

(def array-len (operand)
  (m `(,v.operand integer)))

(def array-ref (operand idx)
  (assert typeinfo.operand!array)
  (assert (< -1 idx (array-len operand)))
  (withs (elem  typeinfo.operand!elem
          offset  (+ 1 (* idx sz.elem)))
    (m `(,(+ v.operand offset) ,elem))))

(def run (instrs (o fn-args) (o fn-oargs))
  (ret result nil
    (with (ninstrs 0  fn-arg-idx 0)
;?     (prn instrs)
    (for pc 0 (< pc len.instrs) (do ++.ninstrs ++.pc)
;?       (if (> ninstrs 10) (break))
      (let instr instrs.pc
;?         (prn memory*)
;?         (prn pc ": " instr)
        (let delim (or (pos '<- instr) -1)
          (with (oarg  (if (>= delim 0)
                         (cut instr 0 delim))
                 op  (instr (+ delim 1))
                 arg  (cut instr (+ delim 2)))
;?             (prn op " " oarg)
            (let tmp
              (case op
                literal
                  arg.0
                add
;?                 (do (prn "add " (m arg.0) (m arg.1))
                  (+ (m arg.0) (m arg.1))
;?                   (prn "add2"))
                sub
                  (- (m arg.0) (m arg.1))
                mul
                  (* (m arg.0) (m arg.1))
                div
                  (/ (real (m arg.0)) (m arg.1))
                idiv
                  (list
                     (trunc:/ (m arg.0) (m arg.1))
                     (mod (m arg.0) (m arg.1)))
                and
                  (and (m arg.0) (m arg.1))
                or
                  (or (m arg.0) (m arg.1))
                not
                  (not (m arg.0))
                eq
                  (is (m arg.0) (m arg.1))
                neq
                  (~is (m arg.0) (m arg.1))
                lt
                  (< (m arg.0) (m arg.1))
                gt
                  (> (m arg.0) (m arg.1))
                le
                  (<= (m arg.0) (m arg.1))
                ge
                  (>= (m arg.0) (m arg.1))
                arg
                  (let idx (if arg
                             arg.0
                             (do1 fn-arg-idx
                                ++.fn-arg-idx))
                    (m fn-args.idx))
                otype
                  (ty (fn-oargs arg.0))
                jmp
                  (do (= pc (+ pc (v arg.0)))
;?                       (prn "jumping to " pc)
                      (continue))
                jif
                  (when (is t (m arg.0))
                    (= pc (+ pc (v arg.1)))
;?                     (prn "jumping to " pc)
                    (continue))
                copy
                  (m arg.0)
                get
                  (with (base arg.0  ; integer (non-symbol) memory location including metadata
                         idx (v arg.1))  ; literal integer
                    (if typeinfo.base!array
                      ; array is an integer 'sz' followed by sz elems
                      ; 'get' can only lookup its index
                      (do (assert (is 0 idx))
                          (array-len base))
                      ; field index
                      (do (assert (< -1 idx (len typeinfo.base!elems)))
                          (m `(,(+ v.base
                                   (apply + (map sz
                                                 (firstn idx typeinfo.base!elems))))
                               ,typeinfo.base!elems.idx)))))
                aref
                  (array-ref arg.0 (v arg.1))
                reply
                  (do (= result arg)
                      (break))
                ; else user-defined function
                  (let-or new-body function*.op (prn "no definition for " op)
;?                     (prn "== " memory*)
                    (let results (run new-body arg oarg)
;?                       (prn "=> " oarg " " results)
                      (each o oarg
;?                         (prn o)
                        (setm o (m pop.results))))
                    (continue))
                )
;?               (prn tmp " " oarg)
              ; opcode that generated at least some result
              (if (acons tmp)
                (for i 0 (< i (min len.tmp len.oarg)) ++.i
                  (setm oarg.i tmp.i))
                (when oarg  ; must be a list
;?                   (prn oarg.0)
                  (setm oarg.0 tmp)))
              )))))
;?     (prn "return " result)
    )))

(def convert-braces (instrs)
  (let locs ()  ; list of information on each brace: (open/close pc)
    (let pc 0
      (loop (instrs instrs)
        (each instr instrs
          (if (~is 'begin instr.0)
            (do
;?               (prn pc " " instr)
              (++ pc))
            ; hack: racket replaces curlies with parens, so we need the
            ; keyword begin to delimit blocks.
            ; ultimately there'll be no nesting and curlies will just be in a
            ; line by themselves.
            (do
;?               (prn `(open ,pc))
              (push `(open ,pc) locs)
              (recur cdr.instr)
;?               (prn `(close ,pc))
              (push `(close ,pc) locs))))))
    (zap rev locs)
;?     (prn locs)
    (with (pc  0
           stack  ())  ; elems are pcs
      (accum yield
        (loop (instrs instrs)
          (each instr instrs
            (let delim (or (pos '<- instr) -1)
              (with (oarg  (if (>= delim 0)
                             (cut instr 0 delim))
                     op  (instr (+ delim 1))
                     arg  (cut instr (+ delim 2)))
;?                 (prn op " " oarg)
                (case op
                  begin
                    (do
                      (push pc stack)
                      (assert:is oarg nil)
                      (recur arg)
                      (pop stack))
                  break
                    (do
                      (assert:is oarg nil)
                      (assert:is arg nil)
                      (yield `(jmp (,(close-offset pc locs) offset))))
                  breakif
                    (do
;?                       (prn "breakif: " instr)
                      (assert:is oarg nil)
                      (yield `(jif ,arg.0 (,(close-offset pc locs) offset))))
                  continue
                    (do
                      (assert:is oarg nil)
                      (assert:is arg nil)
                      (yield `(jmp (,(- stack.0 pc) offset))))
                  continueif
                    (do
;?                       (prn "continueif: " instr)
                      (assert:is oarg nil)
                      (yield `(jif ,arg.0 (,(- stack.0 pc) offset))))
                  ;else
                    (yield instr))))
            (++ pc)))))))

(def close-offset (pc locs)
  (let close 0
    (with (stacksize 0
           done nil)
      (each (state loc) locs
;?         (prn "  :" close " " state " - " loc)
        (if (< loc pc)
              nil  ; do nothing
            (no done)
              (do
                ; first time
                (when (and (is 0 stacksize) (~is loc pc))
                  (++ stacksize))
                (if (is 'open state) (++ stacksize) (-- stacksize))
                ; last time
                (when (is 0 stacksize)
                  (= close loc)
                  (set done))))))
    (- close pc 1)))

(awhen cdr.argv
  (map add-fns:readfile it)
  (run function*!main)
  (prn memory*))
