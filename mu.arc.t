(load "mu.arc")

(reset)
(add-fns
  '((test1
      ((1 integer) <- literal 1))))
(run function*!test1)
;? (prn memory*)
(if (~iso memory* (obj 1 1))
  (prn "F - 'literal' writes a literal value (its lone 'arg' after the instruction name) to a location in memory (an address) specified by its lone 'oarg' or output arg before the arrow"))

(reset)
(add-fns
  '((test1
      ((1 integer) <- literal 1)
      ((2 integer) <- literal 3)
      ((3 integer) <- add (1 integer) (2 integer)))))
(run function*!test1)
(if (~iso memory* (obj 1 1  2 3  3 4))
  (prn "F - 'add' operates on two addresses"))

(reset)
(add-fns
  '((test1
      ((3 integer) <- add (1 integer) (2 integer)))
    (main
      ((1 integer) <- literal 1)
      ((2 integer) <- literal 3)
      (test1))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 1  2 3  3 4))
  (prn "F - calling a user-defined function runs its instructions"))

(reset)
(add-fns
  '((test1
      ((3 integer) <- add (1 integer) (2 integer))
      (reply)
      ((4 integer) <- literal 34))
    (main
      ((1 integer) <- literal 1)
      ((2 integer) <- literal 3)
      (test1))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 1  2 3  3 4))
  (prn "F - 'reply' stops executing the current function"))
;? (quit)

(reset)
(add-fns
  '((test1
      ((4 integer) <- arg)
      ((5 integer) <- arg)
      ((3 integer) <- add (4 integer) (5 integer))
      (reply)
      ((4 integer) <- literal 34))
    (main
      ((1 integer) <- literal 1)
      ((2 integer) <- literal 3)
      (test1 (1 integer) (2 integer))
    )))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 1  2 3  3 4
                       ; add-fn's temporaries
                       4 1  5 3))
  (prn "F - 'arg' accesses in order the operands of the most recent function call (the caller)"))
;? (quit)

(reset)
(add-fns
  '((test1
      ((5 integer) <- arg 1)
      ((4 integer) <- arg 0)
      ((3 integer) <- add (4 integer) (5 integer))
      (reply)
      ((4 integer) <- literal 34))
    (main
      ((1 integer) <- literal 1)
      ((2 integer) <- literal 3)
      (test1 (1 integer) (2 integer))
    )))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 1  2 3  3 4
                       ; add-fn's temporaries
                       4 1  5 3))
  (prn "F - 'arg' with index can access function call arguments out of order"))
;? (quit)

(reset)
(add-fns
  '((test1
      ((4 integer) <- arg)
      ((5 integer) <- arg)
      ((6 integer) <- add (4 integer) (5 integer))
      (reply (6 integer))
      ((4 integer) <- literal 34))
    (main
      ((1 integer) <- literal 1)
      ((2 integer) <- literal 3)
      ((3 integer) <- test1 (1 integer) (2 integer)))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 1  2 3  3 4
                       ; add-fn's temporaries
                       4 1  5 3  6 4))
  (prn "F - 'reply' can take aguments that are returned, or written back into output args of caller"))

(reset)
(add-fns
  '((test1
      ((4 integer) <- arg)
      ((5 integer) <- arg)
      ((6 integer) <- add (4 integer) (5 integer))
      (reply (6 integer) (5 integer))
      ((4 integer) <- literal 34))
    (main
      ((1 integer) <- literal 1)
      ((2 integer) <- literal 3)
      ((3 integer) (7 integer) <- test1 (1 integer) (2 integer)))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 1  2 3  3 4    7 3
                         ; add-fn's temporaries
                         4 1  5 3  6 4))
  (prn "F - 'reply' permits a function to return multiple values at once"))

(reset)
(add-fns
  '((main
      ((1 integer) <- literal 1)
      ((2 integer) <- literal 3)
      ((3 integer) <- sub (1 integer) (2 integer)))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 1  2 3  3 -2))
  (prn "F - 'sub' subtracts the value at one address from the value at another"))

(reset)
(add-fns
  '((main
      ((1 integer) <- literal 2)
      ((2 integer) <- literal 3)
      ((3 integer) <- mul (1 integer) (2 integer)))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 2  2 3  3 6))
  (prn "F - 'mul' multiplies like 'add' adds"))

(reset)
(add-fns
  '((main
      ((1 integer) <- literal 8)
      ((2 integer) <- literal 3)
      ((3 integer) <- div (1 integer) (2 integer)))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 8  2 3  3 (/ real.8 3)))
  (prn "F - 'div' divides like 'add' adds"))

(reset)
(add-fns
  '((main
      ((1 integer) <- literal 8)
      ((2 integer) <- literal 3)
      ((3 integer) (4 integer) <- idiv (1 integer) (2 integer)))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 8  2 3  3 2  4 2))
  (prn "F - 'idiv' performs integer division, returning quotient and remainder"))

(reset)
(add-fns
  '((main
      ((1 boolean) <- literal t)
      ((2 boolean) <- literal nil)
      ((3 boolean) <- and (1 boolean) (2 boolean)))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 t  2 nil  3 nil))
  (prn "F - logical 'and' for booleans"))

(reset)
(add-fns
  '((main
      ((1 boolean) <- literal 4)
      ((2 boolean) <- literal 3)
      ((3 boolean) <- lt (1 boolean) (2 boolean)))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 4  2 3  3 nil))
  (prn "F - 'lt' is the less-than inequality operator"))

(reset)
(add-fns
  '((main
      ((1 boolean) <- literal 4)
      ((2 boolean) <- literal 3)
      ((3 boolean) <- le (1 boolean) (2 boolean)))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 4  2 3  3 nil))
  (prn "F - 'le' is the <= inequality operator"))

(reset)
(add-fns
  '((main
      ((1 boolean) <- literal 4)
      ((2 boolean) <- literal 4)
      ((3 boolean) <- le (1 boolean) (2 boolean)))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 4  2 4  3 t))
  (prn "F - 'le' returns true for equal operands"))

(reset)
(add-fns
  '((main
      ((1 boolean) <- literal 4)
      ((2 boolean) <- literal 5)
      ((3 boolean) <- le (1 boolean) (2 boolean)))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 4  2 5  3 t))
  (prn "F - le is the <= inequality operator - 2"))

(reset)
(add-fns
  '((main
      ((1 integer) <- literal 8)
      (jmp (1 offset))
      ((2 integer) <- literal 3)
      (reply))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 8))
  (prn "F - 'jmp' skips some instructions"))

(reset)
(add-fns
  '((main
      ((1 integer) <- literal 8)
      (jmp (1 offset))
      ((2 integer) <- literal 3)
      (reply)
      ((3 integer) <- literal 34))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 8))
  (prn "F - 'jmp' doesn't skip too many instructions"))

(reset)
(add-fns
  '((main
      ((1 integer) <- literal 1)
      ((2 integer) <- literal 1)
      ((3 boolean) <- eq (1 integer) (2 integer))
      (jif (3 boolean) (1 offset))
      ((2 integer) <- literal 3)
      (reply)
      ((3 integer) <- literal 34))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 1  2 1  3 t))
  (prn "F - 'jif' is a conditional 'jmp'"))

(reset)
(add-fns
  '((main
      ((1 integer) <- literal 1)
      ((2 integer) <- literal 2)
      ((3 boolean) <- eq (1 integer) (2 integer))
      (jif (3 boolean) (1 offset))
      ((4 integer) <- literal 3)
      (reply)
      ((3 integer) <- literal 34))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 1  2 2  3 nil  4 3))
  (prn "F - if 'jif's first arg is false, it doesn't skip any instructions"))

(reset)
(add-fns
  '((main
      ((1 integer) <- literal 2)
      ((2 integer) <- literal 1)
      ((2 integer) <- add (2 integer) (2 integer))
      ((3 boolean) <- eq (1 integer) (2 integer))
      (jif (3 boolean) (-3 offset))
      ((4 integer) <- literal 3)
      (reply)
      ((3 integer) <- literal 34))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 2  2 4  3 nil  4 3))
  (prn "F - 'jif' can take a negative offset to make backward jumps"))

(reset)
(add-fns
  '((main
      ((1 integer) <- literal 34)
      ((2 integer) <- copy (1 integer)))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 34  2 34))
  (prn "F - 'copy' performs direct addressing"))

(reset)
(add-fns
  '((main
      ((1 integer-address) <- literal 2)
      ((2 integer) <- literal 34)
      ((3 integer) <- copy (1 integer-address deref)))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 2  2 34  3 34))
  (prn "F - 'copy' performs indirect addressing"))

(reset)
(add-fns
  '((main
      ((1 integer-address) <- literal 2)
      ((2 integer) <- literal 34)
      ((3 integer) <- literal 2)
      ((1 integer-address deref) <- add (2 integer) (3 integer)))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 2  2 36  3 2))
  (prn "F - instructions can performs indirect addressing on output arg"))

(reset)
(add-fns
  '((main
      ((1 integer) <- literal 34)
      ((2 boolean) <- literal nil)
      ((3 boolean) <- get (1 integer-boolean-pair) (1 offset))
      ((4 integer) <- get (1 integer-boolean-pair) (0 offset)))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 34  2 nil  3 nil  4 34))
  (prn "F - 'get' accesses fields of records"))

(reset)
(add-fns
  '((main
      ((1 integer) <- literal 34)
      ((2 boolean) <- literal nil)
      ((4 boolean) <- literal t)
      ((3 integer-boolean-pair) <- copy (1 integer-boolean-pair)))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 34  2 nil  3 34  4 nil))
  (prn "F - ops can operate on multi-field records"))

(reset)
(add-fns
  '((test1
      ((4 type) <- otype 0)
      ((5 type) <- literal integer)
      ((6 boolean) <- neq (4 type) (5 type))
      (jif (6 boolean) (3 offset))
      ((7 integer) <- arg)
      ((8 integer) <- arg)
      ((9 integer) <- add (7 integer) (8 integer))
      (reply (9 integer)))
    (main
      ((1 integer) <- literal 1)
      ((2 integer) <- literal 3)
      ((3 integer) <- test1 (1 integer) (2 integer)))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 1  2 3                     3 4
                         ; add-fn's temporaries
                         4 'integer  5 'integer  6 nil  7 1  8 3  9 4))
  (prn "F - an example function that checks that its args are integers"))

(reset)
(add-fns
  '((add-fn
      ((4 type) <- otype 0)
      ((5 type) <- literal integer)
      ((6 boolean) <- neq (4 type) (5 type))
      (jif (6 boolean) (4 offset))
      ((7 integer) <- arg)
      ((8 integer) <- arg)
      ((9 integer) <- add (7 integer) (8 integer))
      (reply (9 integer))
      ((5 type) <- literal boolean)
      ((6 boolean) <- neq (4 type) (5 type))
      (jif (6 boolean) (4 offset))
      ((7 boolean) <- arg)
      ((8 boolean) <- arg)
      ((9 boolean) <- or (7 boolean) (8 boolean))
      (reply (9 boolean)))
    (main
      ((1 boolean) <- literal t)
      ((2 boolean) <- literal t)
      ((3 boolean) <- add-fn (1 boolean) (2 boolean)))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj ; first call to add-fn
                       1 t  2 t                     3 t
                         ; add-fn's temporaries
                         4 'boolean  5 'boolean  6 nil  7 t  8 t  9 t))
  (prn "F - an example function that can do different things (dispatch) based on the type of its args or oargs"))

(reset)
(add-fns
  '((add-fn
      ((4 type) <- otype 0)
      ((5 type) <- literal integer)
      ((6 boolean) <- neq (4 type) (5 type))
      (jif (6 boolean) (4 offset))
      ((7 integer) <- arg)
      ((8 integer) <- arg)
      ((9 integer) <- add (7 integer) (8 integer))
      (reply (9 integer))
      ((5 type) <- literal boolean)
      ((6 boolean) <- neq (4 type) (5 type))
      (jif (6 boolean) (6 offset))
      ((7 boolean) <- arg)
      ((8 boolean) <- arg)
      ((9 boolean) <- or (7 boolean) (8 boolean))
      (reply (9 boolean)))
    (main
      ((1 boolean) <- literal t)
      ((2 boolean) <- literal t)
      ((3 boolean) <- add-fn (1 boolean) (2 boolean))
      ((10 integer) <- literal 3)
      ((11 integer) <- literal 4)
      ((12 integer) <- add-fn (10 integer) (11 integer)))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj ; first call to add-fn
                       1 t  2 t                     3 t
                       ; second call to add-fn
                       10 3  11 4                   12 7
                         ; temporaries for most recent call to add-fn
                         4 'integer  5 'integer  6 nil  7 3  8 4  9 7))
  (prn "F - different calls can exercise different clauses of the same function"))

(if (~iso (convert-braces '(((1 integer) <- literal 4)
                            ((2 integer) <- literal 2)
                            ((3 integer) <- add (2 integer) (2 integer))
                            { begin  ; 'begin' is just a hack because racket turns curlies into parens
                            ((4 boolean) <- neq (1 integer) (3 integer))
                            (breakif (4 boolean))
                            ((5 integer) <- literal 34)
                            }
                            (reply)))
          '(((1 integer) <- literal 4)
            ((2 integer) <- literal 2)
            ((3 integer) <- add (2 integer) (2 integer))
            ((4 boolean) <- neq (1 integer) (3 integer))
            (jif (4 boolean) (1 offset))
            ((5 integer) <- literal 34)
            (reply)))
  (prn "F - convert-braces replaces breakif with a jif to after the next close curly"))

(if (~iso (convert-braces '(((1 integer) <- literal 4)
                            ((2 integer) <- literal 2)
                            ((3 integer) <- add (2 integer) (2 integer))
                            { begin
                            (break)
                            }
                            (reply)))
          '(((1 integer) <- literal 4)
            ((2 integer) <- literal 2)
            ((3 integer) <- add (2 integer) (2 integer))
            (jmp (0 offset))
            (reply)))
  (prn "F - convert-braces works for degenerate blocks"))

(if (~iso (convert-braces '(((1 integer) <- literal 4)
                            ((2 integer) <- literal 2)
                            ((3 integer) <- add (2 integer) (2 integer))
                            { begin
                            ((4 boolean) <- neq (1 integer) (3 integer))
                            (breakif (4 boolean))
                            { begin
                            ((5 integer) <- literal 34)
                            }
                            }
                            (reply)))
          '(((1 integer) <- literal 4)
            ((2 integer) <- literal 2)
            ((3 integer) <- add (2 integer) (2 integer))
            ((4 boolean) <- neq (1 integer) (3 integer))
            (jif (4 boolean) (1 offset))
            ((5 integer) <- literal 34)
            (reply)))
  (prn "F - convert-braces balances curlies when converting break"))

(if (~iso (convert-braces '(((1 integer) <- literal 4)
                            ((2 integer) <- literal 2)
                            { begin
                            ((3 integer) <- add (2 integer) (2 integer))
                            { begin
                            ((4 boolean) <- neq (1 integer) (3 integer))
                            }
                            (continueif (4 boolean))
                            ((5 integer) <- literal 34)
                            }
                            (reply)))
          '(((1 integer) <- literal 4)
            ((2 integer) <- literal 2)
            ((3 integer) <- add (2 integer) (2 integer))
            ((4 boolean) <- neq (1 integer) (3 integer))
            (jif (4 boolean) (-3 offset))
            ((5 integer) <- literal 34)
            (reply)))
  (prn "F - convert-braces balances curlies when converting continue"))

(reset)
(add-fns `((main ,@(convert-braces '(((1 integer) <- literal 4)
                                     ((2 integer) <- literal 1)
                                     { begin
                                     ((2 integer) <- add (2 integer) (2 integer))
                                     { begin
                                     ((3 boolean) <- neq (1 integer) (2 integer))
                                     }
                                     (continueif (3 boolean))
                                     ((4 integer) <- literal 34)
                                     }
                                     (reply))))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 4  2 4  3 nil  4 34))
  (prn "F - continue correctly loops"))

(reset)
(add-fns `((main ,@(convert-braces '(((1 integer) <- literal 4)
                                     ((2 integer) <- literal 2)
                                     { begin
                                     ((2 integer) <- add (2 integer) (2 integer))
                                     { begin
                                     ((3 boolean) <- neq (1 integer) (2 integer))
                                     }
                                     (continueif (3 boolean))
                                     ((4 integer) <- literal 34)
                                     }
                                     (reply))))))
(run function*!main)
;? (prn memory*)
(if (~iso memory* (obj 1 4  2 4  3 nil  4 34))
  (prn "F - continue might never trigger"))
