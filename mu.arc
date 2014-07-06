(def clear ()
  (= types* (table))
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
      (let delim (or (pos '<- instr) -1)
        (with (oarg (cut instr 0 delim)
               op (instr (+ delim 1))
               arg  (cut instr (+ delim 2)))
;?           (prn op)
          (case op
            loadi
              (= (memory* oarg.0) arg.0)
            add
              (= (memory* oarg.0)
                 (+ (memory* arg.0) (memory* arg.1)))
            read
              (= (memory* oarg.0)
                 ; hardcoded channel for now
                 (memory* pop.fn-args))
            return
              (set returned)
            ; else user-defined function
              (run function*.op arg)
            )))))
;?   (prn "return")
  )

(awhen cdr.argv
  (each file it
  ;?   (prn file)
    (add-fns readfile.file))
  ;? (prn function*)
  (run function*!main)
  (prn memory*))
