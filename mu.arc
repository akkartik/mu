(= types* (table))
(= memory* (table))

(def run (instrs)
  (each instr instrs
;?     (prn instr)
    (let (oarg1 <- op arg1 arg2) instr
;?       (prn op)
      (case op
        loadi
          (= memory*.oarg1 arg1)
        add
          (= memory*.oarg1
             (+ memory*.arg1 memory*.arg2))
        ))))

(each file (cut argv 1)
;?   (prn file)
  (run readfile.file)
  (prn memory*))
