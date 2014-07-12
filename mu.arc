; things that a future assembler will need separate memory for:
;   code; types; args channel
(def clear ()
  (= types* (obj
              integer (obj size 1)
              location (obj size 1)
              address (obj size 1)))
  (= memory* (table))
  (= function* (table)))
(clear)

(mac aelse (test else . body)
  `(aif ,test
      (do ,@body)
      ,else))

(def add-fns (fns)
  (each (name . body) fns
    (= function*.name body)))

(def run (instrs (o fn-args) (o otypes))
  (ret result nil
    (let fn-arg-idx 0
;?     (prn instrs)
    (for pc 0 (< pc len.instrs) (++ pc)
;?       (prn pc)
      (let instr instrs.pc
;?         (prn instr)
;?         (prn memory*)
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
                (= (memory* oarg.0.1)
                   (+ (memory* arg.0.1) (memory* arg.1.1)))
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
              arg
;?                 (do (prn "arg " arg " fn-arg " fn-arg-idx)
                    (if arg
;?                       (do (prn "arg " arg)
                      (= (memory* oarg.0.1)
                         (memory* ((fn-args arg.0) 1)))
;?                       )
;?                       (do (prn "no arg; using " fn-arg-idx " " fn-args.fn-arg-idx)
                          (= (memory* oarg.0.1)
                             (memory* fn-args.fn-arg-idx.1))
                          (++ fn-arg-idx))
;?                       )
;?                 )
              jmp
                (do (= pc arg.0.1)
;?                     (prn "jumping to " pc)
                    (continue))
              jifz
                (when (is 0 (memory* arg.0.1))
                  (= pc arg.1.1)
                  (continue))
              reply
                (do (= result arg)
                    (break))
              ; else user-defined function
                (aelse function*.op (prn "no definition for " op)
;?                   (prn "== " memory*)
                  (let results (run it arg)
                    (each o oarg
;?                       (prn o)
                      (= (memory* o.1) (memory* pop.results.1)))))
              )))))
;?     (prn "return " result)
    )))

(awhen cdr.argv
  (each file it
;?     (prn file)
    (add-fns readfile.file))
;?   (prn function*)
  (run function*!main)
  (prn memory*))
