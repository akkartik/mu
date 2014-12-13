; support for dividing arc files into sections of different level, and
; selectively loading just sections at or less than a given level

; usage:
;   load.arc [level] [arc files] -- [mu files]

(def selective-load (file (o level 999))
;?   (prn "loading @file at level @level")
  (fromfile file
    (whilet expr (read)
;?       (prn car.expr)
      (if (is 'section expr.0)
        (when (< expr.1 level)
          (each x (cut expr 2)
            (eval x)))
        (eval expr))
;?       (prn car.expr " done")
      )))

(= section-level 999)
(point break
(each x (map [fromstring _ (read)] cdr.argv)
  (if (isa x 'int)
        (= section-level x)
      (is '-- x)
        (break)  ; later args are mu files
      :else
        (selective-load string.x section-level))))
