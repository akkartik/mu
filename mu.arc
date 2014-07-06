(def clear ()
  (= types* (table))
  (= memory* (table))
  (= function* (table)))
(clear)

(def add-fns (fns)
  (each (name . body) fns
    (= function*.name body)))

(def run (instrs (o returned))
  (each instr instrs
    (unless returned
;?       (prn instr)
      (let (oarg1 <- op arg1 arg2) instr
;?         (prn op)
        (case op
          loadi
            (= memory*.oarg1 arg1)
          add
            (= memory*.oarg1
               (+ memory*.arg1 memory*.arg2))
          return
            (set returned)
          ; else user-defined function
            (run function*.op)
          ))))
;?   (prn "return")
  )

(awhen cdr.argv
  (each file it
  ;?   (prn file)
    (add-fns readfile.file))
  ;? (prn function*)
  (run function*!main)
  (prn memory*))
