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

(mac v (operand)  ; for value
  `(,operand 0))

(mac metadata (operand)
  `(cdr ,operand))

(mac ty (operand)
  `(,operand 1))  ; assume type is always first bit of metadata, and it's always present

(mac m (loc)  ; for memory
  (w/uniq gloc
    `(let ,gloc ,loc
       (if (pos 'deref (metadata ,gloc))
         (memory* (memory* (v ,gloc)))
         (memory* (v ,gloc))))))

(mac setm (loc val)  ; set memory, respecting addressing-mode tags
  (w/uniq gloc
    `(let ,gloc ,loc
       (if (pos 'deref (metadata ,gloc))
         (= (memory* (memory* (v ,gloc))) ,val)
         (=          (memory* (v ,gloc))  ,val)))))

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
                reply
                  (do (= result arg)
                      (break))
                ; else user-defined function
                  (let-or new-body function*.op (prn "no definition for " op)
;?                     (prn "== " memory*)
                    (let results (run new-body arg oarg)
;?                       (prn "=> " oarg)
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
