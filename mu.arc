; things that a future assembler will need separate memory for:
;   code; types; args channel
(def clear ()
  (= types* (obj
              integer (obj size 1)
              address (obj size 1)))
  (= memory* (table))
  (= function* (table)))
(clear)

(def add-fns (fns)
  (each (name . body) fns
    (= function*.name body)))

(def run (instrs (o fn-args) (o returned))
  (each instr instrs
    (unless returned
;?       (prn instr)
;?       (prn memory*)
      (let delim (or (pos '<- instr) -1)
        (with (oarg (if (>= delim 0)
                      (cut instr 0 delim))
               op (instr (+ delim 1))
               arg  (cut instr (+ delim 2)))
;?           (prn op " " oarg)
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
            read
              (= (memory* oarg.0.1)
                 ; hardcoded channel for now
                 (memory* pop.fn-args.1))
            reply
              (= returned (annotate 'result arg))
            ; else user-defined function
              (let results (run function*.op arg)
;?                 (prn "== " memory*)
                (each o oarg
;?                   (prn o)
                  (= (memory* o.1) (memory* pop.results.1))))
            )))))
;?   (prn "return")
    rep.returned)

(awhen cdr.argv
  (each file it
;?     (prn file)
    (add-fns readfile.file))
;?   (prn function*)
  (run function*!main)
  (prn memory*))
