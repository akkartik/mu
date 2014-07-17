(load "mu.arc")

(clear)
(add-fns '((test1
  ((integer 1) <- loadi 1)
  ((integer 2) <- loadi 3)
  ((integer 3) <- add (integer 1) (integer 2)))))
(run function*!test1)
(if (~iso memory* (obj 1 1  2 3  3 4))
  (prn "F - load and add instructions work"))

(clear)
(add-fns
  '((test1
      ((integer 3) <- add (integer 1) (integer 2)))
    (main
      ((integer 1) <- loadi 1)
      ((integer 2) <- loadi 3)
      (test1))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 1  2 3  3 4))
  (prn "F - compound functions work"))

(clear)
(add-fns
  '((test1
      ((integer 3) <- add (integer 1) (integer 2))
      (reply)
      ((integer 4) <- loadi 34))
    (main
      ((integer 1) <- loadi 1)
      ((integer 2) <- loadi 3)
      (test1))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 1  2 3  3 4))
  (prn "F - early return works"))
;? (quit)

(clear)
(add-fns
  '((test1
      ((integer 4) <- arg)
      ((integer 5) <- arg)
      ((integer 3) <- add (integer 4) (integer 5))
      (reply)
      ((integer 4) <- loadi 34))
    (main
      ((integer 1) <- loadi 1)
      ((integer 2) <- loadi 3)
      (test1 (integer 1) (integer 2))
    )))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 1  2 3  3 4
                       ; add-fn's temporaries
                       4 1  5 3))
  (prn "F - parameterized compound fn"))
;? (quit)

(clear)
(add-fns
  '((test1
      ((integer 5) <- arg 1)
      ((integer 4) <- arg 0)
      ((integer 3) <- add (integer 4) (integer 5))
      (reply)
      ((integer 4) <- loadi 34))
    (main
      ((integer 1) <- loadi 1)
      ((integer 2) <- loadi 3)
      (test1 (integer 1) (integer 2))
    )))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 1  2 3  3 4
                       ; add-fn's temporaries
                       4 1  5 3))
  (prn "F - arg with index"))
;? (quit)

(clear)
(add-fns
  '((test1
      ((integer 4) <- arg)
      ((integer 5) <- arg)
      ((integer 6) <- add (integer 4) (integer 5))
      (reply (integer 6))
      ((integer 4) <- loadi 34))
    (main
      ((integer 1) <- loadi 1)
      ((integer 2) <- loadi 3)
      ((integer 3) <- test1 (integer 1) (integer 2)))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 1  2 3  3 4
                       ; add-fn's temporaries
                       4 1  5 3  6 4))
  (prn "F - parameterized compound fn with return value"))

(clear)
(add-fns
  '((test1
      ((integer 4) <- arg)
      ((integer 5) <- arg)
      ((integer 6) <- add (integer 4) (integer 5))
      (reply (integer 6) (integer 5))
      ((integer 4) <- loadi 34))
    (main
      ((integer 1) <- loadi 1)
      ((integer 2) <- loadi 3)
      ((integer 3) (integer 7) <- test1 (integer 1) (integer 2)))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 1  2 3  3 4    7 3
                         ; add-fn's temporaries
                         4 1  5 3  6 4))
  (prn "F - parameterized compound fn with multiple return values"))

(clear)
(add-fns
  '((main
      ((integer 1) <- loadi 1)
      ((integer 2) <- loadi 3)
      ((integer 3) <- sub (integer 1) (integer 2)))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 1  2 3  3 -2))
  (prn "F - sub works"))

(clear)
(add-fns
  '((main
      ((integer 1) <- loadi 2)
      ((integer 2) <- loadi 3)
      ((integer 3) <- mul (integer 1) (integer 2)))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 2  2 3  3 6))
  (prn "F - mul works"))

(clear)
(add-fns
  '((main
      ((integer 1) <- loadi 8)
      ((integer 2) <- loadi 3)
      ((integer 3) <- div (integer 1) (integer 2)))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 8  2 3  3 (/ real.8 3)))
  (prn "F - div works"))

(clear)
(add-fns
  '((main
      ((integer 1) <- loadi 8)
      ((integer 2) <- loadi 3)
      ((integer 3) (integer 4) <- idiv (integer 1) (integer 2)))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 8  2 3  3 2  4 2))
  (prn "F - idiv works"))

(clear)
(add-fns
  '((main
      ((boolean 1) <- loadi t)
      ((boolean 2) <- loadi nil)
      ((boolean 3) <- and (boolean 1) (boolean 2)))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 t  2 nil  3 nil))
  (prn "F - and works"))

(clear)
(add-fns
  '((main
      ((boolean 1) <- loadi 4)
      ((boolean 2) <- loadi 4)
      ((boolean 3) <- le (boolean 1) (boolean 2)))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 4  2 4  3 t))
  (prn "F - le works"))

(clear)
(add-fns
  '((main
      ((boolean 1) <- loadi 4)
      ((boolean 2) <- loadi 3)
      ((boolean 3) <- le (boolean 1) (boolean 2)))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 4  2 3  3 nil))
  (prn "F - le works - 2"))

(clear)
(add-fns
  '((main
      ((boolean 1) <- loadi 4)
      ((boolean 2) <- loadi 5)
      ((boolean 3) <- le (boolean 1) (boolean 2)))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 4  2 5  3 t))
  (prn "F - le works - 3"))

(clear)
(add-fns
  '((main
      ((integer 1) <- loadi 8)
      (jmp (offset 1))
      ((integer 2) <- loadi 3)
      (reply))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 8))
  (prn "F - jmp works"))

(clear)
(add-fns
  '((main
      ((integer 1) <- loadi 8)
      (jmp (offset 1))
      ((integer 2) <- loadi 3)
      (reply)
      ((integer 3) <- loadi 34))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 8))
  (prn "F - jmp works"))

(clear)
(add-fns
  '((main
      ((integer 1) <- loadi 1)
      ((integer 2) <- loadi 1)
      ((boolean 3) <- eq (integer 1) (integer 2))
      (jif (boolean 3) (offset 1))
      ((integer 2) <- loadi 3)
      (reply)
      ((integer 3) <- loadi 34))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 1  2 1  3 t))
  (prn "F - jif works"))

(clear)
(add-fns
  '((main
      ((integer 1) <- loadi 1)
      ((integer 2) <- loadi 2)
      ((boolean 3) <- eq (integer 1) (integer 2))
      (jif (boolean 3) (offset 1))
      ((integer 4) <- loadi 3)
      (reply)
      ((integer 3) <- loadi 34))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 1  2 2  3 nil  4 3))
  (prn "F - jif works - 2"))

(clear)
(add-fns
  '((test1
      ((type 4) <- otype 0)
      ((type 5) <- loadi 0)  ; type index corresponding to 'integer'
      ((boolean 6) <- neq (type 4) (type 5))
      (jif (boolean 6) (offset 3))
      ((integer 7) <- arg)
      ((integer 8) <- arg)
      ((integer 9) <- add (integer 7) (integer 8))
      (reply (integer 9)))
    (main
      ((integer 1) <- loadi 1)
      ((integer 2) <- loadi 3)
      ((integer 3) <- test1 (integer 1) (integer 2)))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 1  2 3                     3 4
                         ; add-fn's temporaries
                         4 0  5 0  6 nil  7 1  8 3  9 4))
  (prn "F - user-defined function with clauses"))
