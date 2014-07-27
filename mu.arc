; things that a future assembler will need separate memory for:
;   code; types; args channel
(def clear ()
  (= types* (obj
              type (obj size 1  record nil array nil address nil)
              location (obj size 1  record nil array nil address nil)
              integer (obj size 1  record nil array nil address nil)
              boolean (obj size 1  record nil array nil address nil)
              integer-array (obj array t  elem 'integer)  ; array of ints, size in front
              integer-address (obj size 1 address t  elem 'integer)  ; pointer to int
              ))
  (= memory* (table))
  (= function* (table)))
(clear)

(def add-fns (fns)
  (each (name . body) fns
    (= function*.name body)))

(mac m (loc)
  `(memory* (,loc 1)))

(def run (instrs (o fn-args) (o otypes))
  (ret result nil
    (let fn-arg-idx 0
;?     (prn instrs)
    (for pc 0 (< pc len.instrs) (++ pc)
      (let instr instrs.pc
;?         (prn memory*)
;?         (prn pc ": " instr)
        (let delim (or (pos '<- instr) -1)
          (with (oarg  (if (>= delim 0)
                         (cut instr 0 delim))
                 op  (instr (+ delim 1))
                 arg  (cut instr (+ delim 2)))
;?             (prn op " " oarg)
            (case op
              literal
                (= (m oarg.0) arg.0)
              add
;?               (do (prn "add " arg.0.1 arg.1.1)
                (= (m oarg.0)
                   (+ (m arg.0) (m arg.1)))
;?                 (prn "add2"))
              sub
                (= (m oarg.0)
                   (- (m arg.0) (m arg.1)))
              mul
                (= (m oarg.0)
                   (* (m arg.0) (m arg.1)))
              div
                (= (m oarg.0)
                   (/ (real (m arg.0)) (m arg.1)))
              idiv
                (= (m oarg.0)
                   (trunc:/ (m arg.0) (m arg.1))
                   (m oarg.1)
                   (mod (m arg.0) (m arg.1)))
              and
                (= (m oarg.0)
                   (and (m arg.0) (m arg.1)))
              or
                (= (m oarg.0)
                   (and (m arg.0) (m arg.1)))
              not
                (= (m oarg.0)
                   (not (m arg.0)))
              eq
                (= (m oarg.0)
                   (is (m arg.0) (m arg.1)))
              neq
                (= (m oarg.0)
                   (~is (m arg.0) (m arg.1)))
              lt
                (= (m oarg.0)
                   (< (m arg.0) (m arg.1)))
              gt
                (= (m oarg.0)
                   (> (m arg.0) (m arg.1)))
              le
                (= (m oarg.0)
                   (<= (m arg.0) (m arg.1)))
              ge
                (= (m oarg.0)
                   (>= (m arg.0) (m arg.1)))
              arg
                (let idx (if arg
                           arg.0
                           (do1 fn-arg-idx
                              ++.fn-arg-idx))
                  (= (m oarg.0)
                     (m fn-args.idx)))
              otype
                (= (m oarg.0)
                   (otypes arg.0))
              jmp
                (do (= pc (+ pc arg.0.1))  ; relies on continue still incrementing (bug)
;?                     (prn "jumping to " pc)
                    (continue))
              jif
                (when (is t (m arg.0))
;?                   (prn "jumping to " arg.1.1)
                  (= pc (+ pc arg.1.1))  ; relies on continue still incrementing (bug)
                  (continue))
              copy
                (= (m oarg.0) (m arg.0))
              deref
                (= (m oarg.0)
                   (m (memory* arg.0)))
              reply
                (do (= result arg)
                    (break))
              ; else user-defined function
                (let-or new-body function*.op (prn "no definition for " op)
;?                   (prn "== " memory*)
                  (let results (run new-body arg (map car oarg))
                    (each o oarg
;?                       (prn o)
                      (= (m o) (m pop.results)))))
              )))))
;?     (prn "return " result)
    )))

;? (mac assert (expr)
;?   `(if (no ,expr)
;?      (err "assertion failed: " ',expr)))

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
                      (yield `(jmp (offset ,(close-offset pc locs)))))
                  breakif
                    (do
;?                       (prn "breakif: " instr)
                      (assert:is oarg nil)
                      (yield `(jif ,arg.0 (offset ,(close-offset pc locs)))))
                  continue
                    (do
                      (assert:is oarg nil)
                      (assert:is arg nil)
                      (yield `(jmp (offset ,(- stack.0 pc)))))
                  continueif
                    (do
;?                       (prn "continueif: " instr)
                      (assert:is oarg nil)
                      (yield `(jif ,arg.0 (offset ,(- stack.0 pc)))))
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
