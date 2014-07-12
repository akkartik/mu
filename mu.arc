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

; just a convenience until we get an assembler
(= type* (obj integer 0 location 1 address 2))

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
              jifz
                (when (is 0 (memory* arg.0.1))
;?                   (prn "jumping to " arg.1.1)
                  (= pc (+ pc arg.1.1))  ; relies on continue still incrementing (bug)
                  (continue))
              reply
                (do (= result arg)
                    (break))
              ; else user-defined function
                (aelse function*.op (prn "no definition for " op)
;?                   (prn "== " memory*)
                  (let results (run it arg (map car oarg))
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
