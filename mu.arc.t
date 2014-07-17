(load "mu.arc")

(clear)
(add-fns '((test1
  ((integer 1) <- loadi 1))))
(run function*!test1)
(if (~iso memory* (obj 1 1))
  (prn "F - 'loadi' writes a literal integer (its lone 'arg' after the instruction name) to a location in memory (an address) specified by its lone 'oarg' or output arg before the arrow"))

(clear)
(add-fns '((test1
  ((integer 1) <- loadi 1)
  ((integer 2) <- loadi 3)
  ((integer 3) <- add (integer 1) (integer 2)))))
(run function*!test1)
(if (~iso memory* (obj 1 1  2 3  3 4))
  (prn "F - 'add' operates on two addresses"))

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
  (prn "F - calling a user-defined function runs its instructions"))

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
  (prn "F - 'reply' stops executing the current function"))
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
  (prn "F - 'arg' accesses in order the operands of the most recent function call (the caller)"))
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
  (prn "F - 'arg' with index can access function call arguments out of order"))
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
  (prn "F - 'reply' can take aguments that are returned, or written back into output args of caller"))

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
  (prn "F - 'reply' permits a function to return multiple values at once"))

(clear)
(add-fns
  '((main
      ((integer 1) <- loadi 1)
      ((integer 2) <- loadi 3)
      ((integer 3) <- sub (integer 1) (integer 2)))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 1  2 3  3 -2))
  (prn "F - 'sub' subtracts the value at one address from the value at another"))

(clear)
(add-fns
  '((main
      ((integer 1) <- loadi 2)
      ((integer 2) <- loadi 3)
      ((integer 3) <- mul (integer 1) (integer 2)))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 2  2 3  3 6))
  (prn "F - 'mul' multiplies like 'add' adds"))

(clear)
(add-fns
  '((main
      ((integer 1) <- loadi 8)
      ((integer 2) <- loadi 3)
      ((integer 3) <- div (integer 1) (integer 2)))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 8  2 3  3 (/ real.8 3)))
  (prn "F - 'div' divides like 'add' adds"))

(clear)
(add-fns
  '((main
      ((integer 1) <- loadi 8)
      ((integer 2) <- loadi 3)
      ((integer 3) (integer 4) <- idiv (integer 1) (integer 2)))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 8  2 3  3 2  4 2))
  (prn "F - 'idiv' performs integer division, returning quotient and remainder"))

(clear)
(add-fns
  '((main
      ((boolean 1) <- loadi t)
      ((boolean 2) <- loadi nil)
      ((boolean 3) <- and (boolean 1) (boolean 2)))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 t  2 nil  3 nil))
  (prn "F - logical 'and' for booleans"))

(clear)
(add-fns
  '((main
      ((boolean 1) <- loadi 4)
      ((boolean 2) <- loadi 3)
      ((boolean 3) <- lt (boolean 1) (boolean 2)))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 4  2 3  3 nil))
  (prn "F - 'lt' is the less-than inequality operator"))

(clear)
(add-fns
  '((main
      ((boolean 1) <- loadi 4)
      ((boolean 2) <- loadi 3)
      ((boolean 3) <- le (boolean 1) (boolean 2)))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 4  2 3  3 nil))
  (prn "F - 'le' is the <= inequality operator"))

(clear)
(add-fns
  '((main
      ((boolean 1) <- loadi 4)
      ((boolean 2) <- loadi 4)
      ((boolean 3) <- le (boolean 1) (boolean 2)))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 4  2 4  3 t))
  (prn "F - 'le' returns true for equal operands"))

(clear)
(add-fns
  '((main
      ((boolean 1) <- loadi 4)
      ((boolean 2) <- loadi 5)
      ((boolean 3) <- le (boolean 1) (boolean 2)))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 4  2 5  3 t))
  (prn "F - le is the <= inequality operator - 2"))

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
  (prn "F - 'jmp' skips some instructions"))

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
  (prn "F - 'jmp' doesn't skip too many instructions"))

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
  (prn "F - 'jif' is a conditional 'jmp'"))

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
  (prn "F - if 'jif's first arg is false, it doesn't skip any instructions"))

(clear)
(add-fns
  '((main
      ((integer 1) <- loadi 2)
      ((integer 2) <- loadi 1)
      ((integer 2) <- add (integer 2) (integer 2))
      ((boolean 3) <- eq (integer 1) (integer 2))
      (jif (boolean 3) (offset -3))
      ((integer 4) <- loadi 3)
      (reply)
      ((integer 3) <- loadi 34))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 2  2 4  3 nil  4 3))
  (prn "F - 'jif' can take a negative offset to make backward jumps"))

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
  (prn "F - an example function that checks that its args are integers"))

(clear)
(add-fns
  '((add-fn
      ((type 4) <- otype 0)
      ((type 5) <- loadi 0)  ; type index corresponding to 'integer'
      ((boolean 6) <- neq (type 4) (type 5))
      (jif (boolean 6) (offset 4))
      ((integer 7) <- arg)
      ((integer 8) <- arg)
      ((integer 9) <- add (integer 7) (integer 8))
      (reply (integer 9))
      ((type 5) <- loadi 4)  ; second clause: is otype 0 a boolean?
      ((boolean 6) <- neq (type 4) (type 5))
      (jif (boolean 6) (offset 6))
      ((boolean 7) <- arg)
      ((boolean 8) <- arg)
      ((boolean 9) <- or (boolean 7) (boolean 8))
      (reply (boolean 9)))
    (main
      ((boolean 1) <- loadi t)
      ((boolean 2) <- loadi t)
      ((boolean 3) <- add-fn (boolean 1) (boolean 2)))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj ; first call to add-fn
                       1 t  2 t                     3 t
                         ; add-fn's temporaries
                         4 4  5 4  6 nil  7 t  8 t  9 t))
  (prn "F - an example function that can do different things (dispatch) based on the type of its args or oargs"))

(clear)
(add-fns
  '((add-fn
      ((type 4) <- otype 0)
      ((type 5) <- loadi 0)  ; type index corresponding to 'integer'
      ((boolean 6) <- neq (type 4) (type 5))
      (jif (boolean 6) (offset 4))
      ((integer 7) <- arg)
      ((integer 8) <- arg)
      ((integer 9) <- add (integer 7) (integer 8))
      (reply (integer 9))
      ((type 5) <- loadi 4)  ; second clause: is otype 0 a boolean?
      ((boolean 6) <- neq (type 4) (type 5))
      (jif (boolean 6) (offset 6))
      ((boolean 7) <- arg)
      ((boolean 8) <- arg)
      ((boolean 9) <- or (boolean 7) (boolean 8))
      (reply (boolean 9)))
    (main
      ((boolean 1) <- loadi t)
      ((boolean 2) <- loadi t)
      ((boolean 3) <- add-fn (boolean 1) (boolean 2))
      ((integer 10) <- loadi 3)
      ((integer 11) <- loadi 4)
      ((integer 12) <- add-fn (integer 10) (integer 11)))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj ; first call to add-fn
                       1 t  2 t                     3 t
                       ; second call to add-fn
                       10 3  11 4                   12 7
                         ; temporaries for most recent call to add-fn
                         4 0  5 0  6 nil  7 3  8 4  9 7))
  (prn "F - different calls can exercise different clauses of the same function"))

(if (~iso (convert-braces '(((integer 1) <- loadi 4)
                            ((integer 2) <- loadi 2)
                            ((integer 3) <- add (integer 2) (integer 2))
                            { begin  ; 'begin' is just a hack because racket turns curlies into parens
                            ((boolean 4) <- neq (integer 1) (integer 3))
                            (breakif (boolean 4))
                            ((integer 5) <- loadi 34)
                            }
                            (reply)))
          '(((integer 1) <- loadi 4)
            ((integer 2) <- loadi 2)
            ((integer 3) <- add (integer 2) (integer 2))
            ((boolean 4) <- neq (integer 1) (integer 3))
            (jif (boolean 4) (offset 1))
            ((integer 5) <- loadi 34)
            (reply)))
  (prn "F - convert-braces replaces breakif with a jif to after the next close curly"))

(if (~iso (convert-braces '(((integer 1) <- loadi 4)
                            ((integer 2) <- loadi 2)
                            ((integer 3) <- add (integer 2) (integer 2))
                            { begin
                            (break)
                            }
                            (reply)))
          '(((integer 1) <- loadi 4)
            ((integer 2) <- loadi 2)
            ((integer 3) <- add (integer 2) (integer 2))
            (jmp (offset 0))
            (reply)))
  (prn "F - convert-braces works for degenerate blocks"))

(if (~iso (convert-braces '(((integer 1) <- loadi 4)
                            ((integer 2) <- loadi 2)
                            ((integer 3) <- add (integer 2) (integer 2))
                            { begin
                            ((boolean 4) <- neq (integer 1) (integer 3))
                            (breakif (boolean 4))
                            { begin
                            ((integer 5) <- loadi 34)
                            }
                            }
                            (reply)))
          '(((integer 1) <- loadi 4)
            ((integer 2) <- loadi 2)
            ((integer 3) <- add (integer 2) (integer 2))
            ((boolean 4) <- neq (integer 1) (integer 3))
            (jif (boolean 4) (offset 1))
            ((integer 5) <- loadi 34)
            (reply)))
  (prn "F - convert-braces balances curlies"))

(if (~iso (convert-braces '(((integer 1) <- loadi 4)
                            ((integer 2) <- loadi 2)
                            ((integer 3) <- add (integer 2) (integer 2))
                            { begin
                            { begin
                            ((boolean 4) <- neq (integer 1) (integer 3))
                            }
                            (continueif (boolean 4))
                            ((integer 5) <- loadi 34)
                            }
                            (reply)))
          '(((integer 1) <- loadi 4)
            ((integer 2) <- loadi 2)
            ((integer 3) <- add (integer 2) (integer 2))
            ((boolean 4) <- neq (integer 1) (integer 3))
            (jif (boolean 4) (offset -2))
            ((integer 5) <- loadi 34)
            (reply)))
  (prn "F - convert-braces balances curlies"))
