; things that a future assembler will need separate memory for:
;   code; types; args channel
(def clear ()
  (= types* (obj
              integer (obj size 1)
              type (obj size 1)
              location (obj size 1)
              address (obj size 1)
              boolean (obj size 1)))
  (= memory* (table))
  (= function* (table)))
(clear)

; just a convenience until we get an assembler
(= type* (obj integer 0 type 1 location 2 address 3 boolean 4))

(def add-fns (fns)
  (each (name . body) fns
    (= function*.name body)))

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
              loadi
                (= (memory* oarg.0.1) arg.0)
              add
;?               (do (prn "add " arg.0.1 arg.1.1)
                (= (memory* oarg.0.1)
                   (+ (memory* arg.0.1) (memory* arg.1.1)))
;?                 (prn "add2"))
              sub
                (= (memory* oarg.0.1)
                   (- (memory* arg.0.1) (memory* arg.1.1)))
              mul
                (= (memory* oarg.0.1)
                   (* (memory* arg.0.1) (memory* arg.1.1)))
              div
                (= (memory* oarg.0.1)
                   (/ (real (memory* arg.0.1)) (memory* arg.1.1)))
              idiv
                (= (memory* oarg.0.1)
                   (trunc:/ (memory* arg.0.1) (memory* arg.1.1))
                   (memory* oarg.1.1)
                   (mod (memory* arg.0.1) (memory* arg.1.1)))
              and
                (= (memory* oarg.0.1)
                   (and (memory* arg.0.1) (memory* arg.1.1)))
              or
                (= (memory* oarg.0.1)
                   (and (memory* arg.0.1) (memory* arg.1.1)))
              not
                (= (memory* oarg.0.1)
                   (not (memory* arg.0.1)))
              eq
                (= (memory* oarg.0.1)
                   (iso (memory* arg.0.1) (memory* arg.1.1)))
              neq
                (= (memory* oarg.0.1)
                   (~iso (memory* arg.0.1) (memory* arg.1.1)))
              lt
                (= (memory* oarg.0.1)
                   (< (memory* arg.0.1) (memory* arg.1.1)))
              gt
                (= (memory* oarg.0.1)
                   (> (memory* arg.0.1) (memory* arg.1.1)))
              le
                (= (memory* oarg.0.1)
                   (<= (memory* arg.0.1) (memory* arg.1.1)))
              ge
                (= (memory* oarg.0.1)
                   (>= (memory* arg.0.1) (memory* arg.1.1)))
              arg
                (let idx (if arg
                           arg.0
                           (do1 fn-arg-idx
                              ++.fn-arg-idx))
                  (= (memory* oarg.0.1)
                     (memory* fn-args.idx.1)))
              otype
                (= (memory* oarg.0.1)
                   (type* (otypes arg.0)))
              jmp
                (do (= pc (+ pc arg.0.1))  ; relies on continue still incrementing (bug)
;?                     (prn "jumping to " pc)
                    (continue))
              jif
                (when (is t (memory* arg.0.1))
;?                   (prn "jumping to " arg.1.1)
                  (= pc (+ pc arg.1.1))  ; relies on continue still incrementing (bug)
                  (continue))
              reply
                (do (= result arg)
                    (break))
              ; else user-defined function
                (let-or new-body function*.op (prn "no definition for " op)
;?                   (prn "== " memory*)
                  (let results (run new-body arg (map car oarg))
                    (each o oarg
;?                       (prn o)
                      (= (memory* o.1) (memory* pop.results.1)))))
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
  (each file it
;?     (prn file)
    (add-fns readfile.file))
;?   (prn function*)
  (run function*!main)
  (prn memory*))
