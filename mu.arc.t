(load "mu.arc")

(reset)
(new-trace "literal")
(add-fns
  '((test1
      ((1 integer) <- copy (23 literal)))))
(run 'test1)
;? (prn memory*)
(if (~is memory*.1 23)
  (prn "F - 'copy' writes its lone 'arg' after the instruction name to its lone 'oarg' or output arg before the arrow. After this test, the value 23 is stored in memory address 1."))
;? (quit)

(reset)
(new-trace "add")
(add-fns
  '((test1
      ((1 integer) <- copy (1 literal))
      ((2 integer) <- copy (3 literal))
      ((3 integer) <- add (1 integer) (2 integer)))))
(run 'test1)
(if (~iso memory* (obj 1 1  2 3  3 4))
  (prn "F - 'add' operates on two addresses"))

(reset)
(new-trace "new-fn")
(add-fns
  '((test1
      ((3 integer) <- add (1 integer) (2 integer)))
    (main
      ((1 integer) <- copy (1 literal))
      ((2 integer) <- copy (3 literal))
      (test1))))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 1  2 3  3 4))
  (prn "F - calling a user-defined function runs its instructions"))
;? (quit)

(reset)
(new-trace "new-fn-once")
(add-fns
  '((test1
      ((1 integer) <- copy (1 literal)))
    (main
      (test1))))
(if (~is 2 (run 'main))
  (prn "F - calling a user-defined function runs its instructions exactly once"))
;? (quit)

(reset)
(new-trace "new-fn-reply")
(add-fns
  '((test1
      ((3 integer) <- add (1 integer) (2 integer))
      (reply)
      ((4 integer) <- copy (34 literal)))
    (main
      ((1 integer) <- copy (1 literal))
      ((2 integer) <- copy (3 literal))
      (test1))))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 1  2 3  3 4))
  (prn "F - 'reply' stops executing the current function"))
;? (quit)

(reset)
(new-trace "new-fn-reply-nested")
(add-fns
  `((test1
      ((3 integer) <- test2))
    (test2
      (reply (2 integer)))
    (main
      ((2 integer) <- copy (34 literal))
      (test1))))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 2 34  3 34))
  (prn "F - 'reply' stops executing any callers as necessary"))
;? (quit)

(reset)
(new-trace "new-fn-reply-once")
(add-fns
  '((test1
      ((3 integer) <- add (1 integer) (2 integer))
      (reply)
      ((4 integer) <- copy (34 literal)))
    (main
      ((1 integer) <- copy (1 literal))
      ((2 integer) <- copy (3 literal))
      (test1))))
(if (~is 4 (run 'main))  ; last reply sometimes not counted. worth fixing?
  (prn "F - 'reply' executes instructions exactly once"))
;? (quit)

(reset)
(new-trace "new-fn-arg-sequential")
(add-fns
  '((test1
      ((4 integer) <- arg)
      ((5 integer) <- arg)
      ((3 integer) <- add (4 integer) (5 integer))
      (reply)
      ((4 integer) <- copy (34 literal)))
    (main
      ((1 integer) <- copy (1 literal))
      ((2 integer) <- copy (3 literal))
      (test1 (1 integer) (2 integer))
    )))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 1  2 3  3 4
                       ; add-fn's temporaries
                       4 1  5 3))
  (prn "F - 'arg' accesses in order the operands of the most recent function call (the caller)"))
;? (quit)

(reset)
(new-trace "new-fn-arg-random-access")
(add-fns
  '((test1
      ((5 integer) <- arg 1)
      ((4 integer) <- arg 0)
      ((3 integer) <- add (4 integer) (5 integer))
      (reply)
      ((4 integer) <- copy (34 literal)))  ; should never run
    (main
      ((1 integer) <- copy (1 literal))
      ((2 integer) <- copy (3 literal))
      (test1 (1 integer) (2 integer))
    )))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 1  2 3  3 4
                       ; add-fn's temporaries
                       4 1  5 3))
  (prn "F - 'arg' with index can access function call arguments out of order"))
;? (quit)

; todo: test that too few args throws an error
; how should errors be handled? will be unclear until we support concurrency and routine trees.

(reset)
(new-trace "new-fn-reply-oarg")
(add-fns
  '((test1
      ((4 integer) <- arg)
      ((5 integer) <- arg)
      ((6 integer) <- add (4 integer) (5 integer))
      (reply (6 integer))
      ((4 integer) <- copy (34 literal)))
    (main
      ((1 integer) <- copy (1 literal))
      ((2 integer) <- copy (3 literal))
      ((3 integer) <- test1 (1 integer) (2 integer)))))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 1  2 3  3 4
                       ; add-fn's temporaries
                       4 1  5 3  6 4))
  (prn "F - 'reply' can take aguments that are returned, or written back into output args of caller"))

(reset)
(new-trace "new-fn-reply-oarg-multiple")
(add-fns
  '((test1
      ((4 integer) <- arg)
      ((5 integer) <- arg)
      ((6 integer) <- add (4 integer) (5 integer))
      (reply (6 integer) (5 integer))
      ((4 integer) <- copy (34 literal)))
    (main
      ((1 integer) <- copy (1 literal))
      ((2 integer) <- copy (3 literal))
      ((3 integer) (7 integer) <- test1 (1 integer) (2 integer)))))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 1  2 3  3 4    7 3
                         ; add-fn's temporaries
                         4 1  5 3  6 4))
  (prn "F - 'reply' permits a function to return multiple values at once"))

(reset)
(new-trace "add-literal")
(add-fns
  '((test1
      ((1 integer) <- add (2 literal) (3 literal)))))
(run 'test1)
(if (~is memory*.1 5)
  (prn "F - ops can take 'literal' operands (but not return them)"))

(reset)
(new-trace "sub-literal")
(add-fns
  '((main
      ((1 integer) <- sub (1 literal) (3 literal)))))
(run 'main)
;? (prn memory*)
(if (~is memory*.1 -2)
  (prn "F - 'sub' subtracts the value at one address from the value at another"))

(reset)
(new-trace "mul-literal")
(add-fns
  '((main
      ((1 integer) <- mul (2 literal) (3 literal)))))
(run 'main)
;? (prn memory*)
(if (~is memory*.1 6)
  (prn "F - 'mul' multiplies like 'add' adds"))

(reset)
(new-trace "div-literal")
(add-fns
  '((main
      ((1 integer) <- div (8 literal) (3 literal)))))
(run 'main)
;? (prn memory*)
(if (~is memory*.1 (/ real.8 3))
  (prn "F - 'div' divides like 'add' adds"))

(reset)
(new-trace "idiv-literal")
(add-fns
  '((main
      ((1 integer) (2 integer) <- idiv (8 literal) (3 literal)))))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 2  2 2))
  (prn "F - 'idiv' performs integer division, returning quotient and remainder"))

(reset)
(new-trace "and-literal")
(add-fns
  '((main
      ((1 boolean) <- and (t literal) (nil literal)))))
(run 'main)
;? (prn memory*)
(if (~is memory*.1 nil)
  (prn "F - logical 'and' for booleans"))

(reset)
(new-trace "lt-literal")
(add-fns
  '((main
      ((1 boolean) <- lt (4 literal) (3 literal)))))
(run 'main)
;? (prn memory*)
(if (~is memory*.1 nil)
  (prn "F - 'lt' is the less-than inequality operator"))

(reset)
(new-trace "le-literal-false")
(add-fns
  '((main
      ((1 boolean) <- le (4 literal) (3 literal)))))
(run 'main)
;? (prn memory*)
(if (~is memory*.1 nil)
  (prn "F - 'le' is the <= inequality operator"))

(reset)
(new-trace "le-literal-true")
(add-fns
  '((main
      ((1 boolean) <- le (4 literal) (4 literal)))))
(run 'main)
;? (prn memory*)
(if (~is memory*.1 t)
  (prn "F - 'le' returns true for equal operands"))

(reset)
(new-trace "le-literal-true-2")
(add-fns
  '((main
      ((1 boolean) <- le (4 literal) (5 literal)))))
(run 'main)
;? (prn memory*)
(if (~is memory*.1 t)
  (prn "F - le is the <= inequality operator - 2"))

(reset)
(new-trace "jmp-skip")
(add-fns
  '((main
      ((1 integer) <- copy (8 literal))
      (jmp (1 offset))
      ((2 integer) <- copy (3 literal))  ; should be skipped
      (reply))))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 8))
  (prn "F - 'jmp' skips some instructions"))

(reset)
(new-trace "jmp-target")
(add-fns
  '((main
      ((1 integer) <- copy (8 literal))
      (jmp (1 offset))
      ((2 integer) <- copy (3 literal))  ; should be skipped
      (reply)
      ((3 integer) <- copy (34 literal)))))  ; never reached
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 8))
  (prn "F - 'jmp' doesn't skip too many instructions"))
;? (quit)

(reset)
(new-trace "jif-skip")
(add-fns
  '((main
      ((2 integer) <- copy (1 literal))
      ((1 boolean) <- eq (1 literal) (2 integer))
      (jif (1 boolean) (1 offset))
      ((2 integer) <- copy (3 literal))
      (reply)
      ((3 integer) <- copy (34 literal)))))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 t  2 1))
  (prn "F - 'jif' is a conditional 'jmp'"))

(reset)
(new-trace "jif-fallthrough")
(add-fns
  '((main
      ((1 boolean) <- eq (1 literal) (2 literal))
      (jif (3 boolean) (1 offset))
      ((2 integer) <- copy (3 literal))
      (reply)
      ((3 integer) <- copy (34 literal)))))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 nil  2 3))
  (prn "F - if 'jif's first arg is false, it doesn't skip any instructions"))

(reset)
(new-trace "jif-backward")
(add-fns
  '((main
      ((1 integer) <- copy (2 literal))
      ((2 integer) <- copy (1 literal))
      ; loop
      ((2 integer) <- add (2 integer) (2 integer))
      ((3 boolean) <- eq (1 integer) (2 integer))
      (jif (3 boolean) (-3 offset))  ; to loop
      ((4 integer) <- copy (3 literal))
      (reply)
      ((3 integer) <- copy (34 literal)))))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 2  2 4  3 nil  4 3))
  (prn "F - 'jif' can take a negative offset to make backward jumps"))

(reset)
(new-trace "direct-addressing")
(add-fns
  '((main
      ((1 integer) <- copy (34 literal))
      ((2 integer) <- copy (1 integer)))))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 34  2 34))
  (prn "F - 'copy' performs direct addressing"))

(reset)
(new-trace "indirect-addressing")
(add-fns
  '((main
      ((1 integer-address) <- copy (2 literal))
      ((2 integer) <- copy (34 literal))
      ((3 integer) <- copy (1 integer-address deref)))))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 2  2 34  3 34))
  (prn "F - 'copy' performs indirect addressing"))

(reset)
(new-trace "indirect-addressing-oarg")
(add-fns
  '((main
      ((1 integer-address) <- copy (2 literal))
      ((2 integer) <- copy (34 literal))
      ((1 integer-address deref) <- add (2 integer) (2 literal)))))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 2  2 36))
  (prn "F - instructions can perform indirect addressing on output arg"))

(reset)
(new-trace "get-record")
(add-fns
  '((main
      ((1 integer) <- copy (34 literal))
      ((2 boolean) <- copy (nil literal))
      ((3 boolean) <- get (1 integer-boolean-pair) (1 offset))
      ((4 integer) <- get (1 integer-boolean-pair) (0 offset)))))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 34  2 nil  3 nil  4 34))
  (prn "F - 'get' accesses fields of records"))

(reset)
(new-trace "get-indirect")
(add-fns
  '((main
      ((1 integer) <- copy (34 literal))
      ((2 boolean) <- copy (nil literal))
      ((3 integer-boolean-pair-address) <- copy (1 literal))
      ((4 boolean) <- get (3 integer-boolean-pair-address deref) (1 offset))
      ((5 integer) <- get (3 integer-boolean-pair-address deref) (0 offset)))))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 34  2 nil  3 1  4 nil  5 34))
  (prn "F - 'get' accesses fields of record address"))

(reset)
(new-trace "get-compound-field")
(add-fns
  '((main
      ((1 integer) <- copy (34 literal))
      ((2 integer) <- copy (35 literal))
      ((3 integer) <- copy (36 literal))
      ((4 integer-integer-pair) <- get (1 integer-point-pair) (1 offset)))))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 34  2 35  3 36  4 35  5 36))
  (prn "F - 'get' accesses fields spanning multiple locations"))

(reset)
(new-trace "get-address")
(add-fns
  '((main
      ((1 integer) <- copy (34 literal))
      ((2 integer) <- copy (t literal))
      ((3 boolean-address) <- get-address (1 integer-boolean-pair) (1 offset)))))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 34  2 t  3 2))
  (prn "F - 'get-address' returns address of fields of records"))

(reset)
(new-trace "get-address-indirect")
(add-fns
  '((main
      ((1 integer) <- copy (34 literal))
      ((2 integer) <- copy (t literal))
      ((3 integer-boolean-pair-address) <- copy (1 literal))
      ((4 boolean-address) <- get-address (3 integer-boolean-pair-address deref) (1 offset)))))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 34  2 t  3 1  4 2))
  (prn "F - 'get-address' accesses fields of record address"))

(reset)
(new-trace "index-array-literal")
(add-fns
  '((main
      ((1 integer) <- copy (2 literal))
      ((2 integer) <- copy (23 literal))
      ((3 boolean) <- copy (nil literal))
      ((4 integer) <- copy (24 literal))
      ((5 boolean) <- copy (t literal))
      ((6 integer-boolean-pair) <- index (1 integer-boolean-pair-array) (1 literal)))))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 2  2 23 3 nil  4 24 5 t  6 24 7 t))
  (prn "F - 'index' accesses indices of arrays"))

(reset)
(new-trace "index-array-direct")
(add-fns
  '((main
      ((1 integer) <- copy (2 literal))
      ((2 integer) <- copy (23 literal))
      ((3 boolean) <- copy (nil literal))
      ((4 integer) <- copy (24 literal))
      ((5 boolean) <- copy (t literal))
      ((6 integer) <- copy (1 literal))
      ((7 integer-boolean-pair) <- index (1 integer-boolean-pair-array) (6 integer)))))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 2  2 23 3 nil  4 24 5 t  6 1  7 24 8 t))
  (prn "F - 'index' accesses indices of arrays"))

(reset)
(new-trace "index-address")
(add-fns
  '((main
      ((1 integer) <- copy (2 literal))
      ((2 integer) <- copy (23 literal))
      ((3 boolean) <- copy (nil literal))
      ((4 integer) <- copy (24 literal))
      ((5 boolean) <- copy (t literal))
      ((6 integer) <- copy (1 literal))
      ((7 integer-boolean-pair-address) <- index-address (1 integer-boolean-pair-array) (6 integer)))))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 2  2 23 3 nil  4 24 5 t  6 1  7 4))
  (prn "F - 'index-address' returns addresses of indices of arrays"))

(reset)
(new-trace "len-array")
(add-fns
  '((main
      ((1 integer) <- copy (2 literal))
      ((2 integer) <- copy (23 literal))
      ((3 boolean) <- copy (nil literal))
      ((4 integer) <- copy (24 literal))
      ((5 boolean) <- copy (t literal))
      ((6 integer) <- len (1 integer-boolean-pair-array)))))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 2  2 23 3 nil  4 24 5 t  6 2))
  (prn "F - 'len' accesses length of array"))

(reset)
(new-trace "sizeof-record")
(add-fns
  '((main
      ((1 integer) <- sizeof (integer-boolean-pair type)))))
(run 'main)
;? (prn memory*)
(if (~is memory*.1 2)
  (prn "F - 'sizeof' returns space required by arg"))

(reset)
(new-trace "sizeof-record-not-len")
(add-fns
  '((main
      ((1 integer) <- sizeof (integer-point-pair type)))))
(run 'main)
;? (prn memory*)
(if (~is memory*.1 3)
  (prn "F - 'sizeof' is different from number of elems"))

; todo: test that out-of-bounds access throws an error

(reset)
(new-trace "compound-operand")
(add-fns
  '((main
      ((1 integer) <- copy (34 literal))
      ((2 boolean) <- copy (nil literal))
      ((4 boolean) <- copy (t literal))
      ((3 integer-boolean-pair) <- copy (1 integer-boolean-pair)))))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 34  2 nil  3 34  4 nil))
  (prn "F - ops can operate on records spanning multiple locations"))

(reset)
(new-trace "dispatch-otype")
(add-fns
  '((test1
      ((4 type) <- otype 0)
      ((5 boolean) <- neq (4 type) (integer literal))
      (jif (5 boolean) (3 offset))
      ((6 integer) <- arg)
      ((7 integer) <- arg)
      ((8 integer) <- add (6 integer) (7 integer))
      (reply (8 integer)))
    (main
      ((1 integer) <- test1 (1 literal) (3 literal)))))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 4
                         ; add-fn's temporaries
                         4 'integer  5 nil  6 1  7 3  8 4))
  (prn "F - an example function that checks that its oarg is an integer"))
;? (quit)

; todo - test that reply increments pc for caller frame after popping current frame

(reset)
(new-trace "dispatch-otype-multiple-clauses")
(add-fns
  '((test-fn
      ((4 type) <- otype 0)
      ; integer needed? add args
      ((5 boolean) <- neq (4 type) (integer literal))
      (jif (5 boolean) (4 offset))
      ((6 integer) <- arg)
      ((7 integer) <- arg)
      ((8 integer) <- add (6 integer) (7 integer))
      (reply (8 integer))
      ; boolean needed? 'or' args
      ((5 boolean) <- neq (4 type) (boolean literal))
      (jif (5 boolean) (4 offset))
      ((6 boolean) <- arg)
      ((7 boolean) <- arg)
      ((8 boolean) <- or (6 boolean) (7 boolean))
      (reply (8 boolean)))
    (main
      ((1 boolean) <- test-fn (t literal) (t literal)))))
(run 'main)
;? (prn memory*)
(if (~is memory*.1 t)
  (prn "F - an example function that can do different things (dispatch) based on the type of its args or oargs"))
(if (~iso memory* (obj 1 t
                       ; add-fn's temporaries
                       4 'boolean  5 nil  6 t  7 t  8 t))
  (prn "F - an example function that can do different things (dispatch) based on the type of its args or oargs (internals)"))
;? (quit)

(reset)
(new-trace "dispatch-otype-multiple-calls")
(add-fns
  '((test-fn
      ((4 type) <- otype 0)
      ((5 boolean) <- neq (4 type) (integer literal))
      (jif (5 boolean) (4 offset))
      ((6 integer) <- arg)
      ((7 integer) <- arg)
      ((8 integer) <- add (6 integer) (7 integer))
      (reply (8 integer))
      ((5 boolean) <- neq (4 type) (boolean literal))
      (jif (5 boolean) (6 offset))
      ((6 boolean) <- arg)
      ((7 boolean) <- arg)
      ((8 boolean) <- or (6 boolean) (7 boolean))
      (reply (8 boolean)))
    (main
      ((1 boolean) <- test-fn (t literal) (t literal))
      ((2 integer) <- test-fn (3 literal) (4 literal)))))
(run 'main)
;? (prn memory*)
(if (~and (is memory*.1 t) (is memory*.2 7))
  (prn "F - different calls can exercise different clauses of the same function"))
(if (~iso memory* (obj ; results of first and second calls to test-fn
                       1 t  2 7
                       ; temporaries for most recent call to test-fn
                       4 'integer  5 nil  6 3  7 4  8 7))
  (prn "F - different calls can exercise different clauses of the same function (internals)"))

(reset)
(new-trace "convert-braces")
(if (~iso (convert-braces '(((1 integer) <- copy (4 literal))
                            ((2 integer) <- copy (2 literal))
                            ((3 integer) <- add (2 integer) (2 integer))
                            { begin  ; 'begin' is just a hack because racket turns curlies into parens
                            ((4 boolean) <- neq (1 integer) (3 integer))
                            (breakif (4 boolean))
                            ((5 integer) <- copy (34 literal))
                            }
                            (reply)))
          '(((1 integer) <- copy (4 literal))
            ((2 integer) <- copy (2 literal))
            ((3 integer) <- add (2 integer) (2 integer))
            ((4 boolean) <- neq (1 integer) (3 integer))
            (jif (4 boolean) (1 offset))
            ((5 integer) <- copy (34 literal))
            (reply)))
  (prn "F - convert-braces replaces breakif with a jif to after the next close curly"))

(reset)
(new-trace "convert-braces-empty-block")
(if (~iso (convert-braces '(((1 integer) <- copy (4 literal))
                            ((2 integer) <- copy (2 literal))
                            ((3 integer) <- add (2 integer) (2 integer))
                            { begin
                            (break)
                            }
                            (reply)))
          '(((1 integer) <- copy (4 literal))
            ((2 integer) <- copy (2 literal))
            ((3 integer) <- add (2 integer) (2 integer))
            (jmp (0 offset))
            (reply)))
  (prn "F - convert-braces works for degenerate blocks"))

(reset)
(new-trace "convert-braces-nested-break")
(if (~iso (convert-braces '(((1 integer) <- copy (4 literal))
                            ((2 integer) <- copy (2 literal))
                            ((3 integer) <- add (2 integer) (2 integer))
                            { begin
                            ((4 boolean) <- neq (1 integer) (3 integer))
                            (breakif (4 boolean))
                            { begin
                            ((5 integer) <- copy (34 literal))
                            }
                            }
                            (reply)))
          '(((1 integer) <- copy (4 literal))
            ((2 integer) <- copy (2 literal))
            ((3 integer) <- add (2 integer) (2 integer))
            ((4 boolean) <- neq (1 integer) (3 integer))
            (jif (4 boolean) (1 offset))
            ((5 integer) <- copy (34 literal))
            (reply)))
  (prn "F - convert-braces balances curlies when converting break"))

(reset)
(new-trace "convert-braces-nested-continue")
(if (~iso (convert-braces '(((1 integer) <- copy (4 literal))
                            ((2 integer) <- copy (2 literal))
                            { begin
                            ((3 integer) <- add (2 integer) (2 integer))
                            { begin
                            ((4 boolean) <- neq (1 integer) (3 integer))
                            }
                            (continueif (4 boolean))
                            ((5 integer) <- copy (34 literal))
                            }
                            (reply)))
          '(((1 integer) <- copy (4 literal))
            ((2 integer) <- copy (2 literal))
            ((3 integer) <- add (2 integer) (2 integer))
            ((4 boolean) <- neq (1 integer) (3 integer))
            (jif (4 boolean) (-3 offset))
            ((5 integer) <- copy (34 literal))
            (reply)))
  (prn "F - convert-braces balances curlies when converting continue"))

(reset)
(new-trace "continue")
(add-fns `((main ,@(convert-braces '(((1 integer) <- copy (4 literal))
                                     ((2 integer) <- copy (1 literal))
                                     { begin
                                     ((2 integer) <- add (2 integer) (2 integer))
                                     { begin
                                     ((3 boolean) <- neq (1 integer) (2 integer))
                                     }
                                     (continueif (3 boolean))
                                     ((4 integer) <- copy (34 literal))
                                     }
                                     (reply))))))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 4  2 4  3 nil  4 34))
  (prn "F - continue correctly loops"))

(reset)
(new-trace "continue-fail")
(add-fns `((main ,@(convert-braces '(((1 integer) <- copy (4 literal))
                                     ((2 integer) <- copy (2 literal))
                                     { begin
                                     ((2 integer) <- add (2 integer) (2 integer))
                                     { begin
                                     ((3 boolean) <- neq (1 integer) (2 integer))
                                     }
                                     (continueif (3 boolean))
                                     ((4 integer) <- copy (34 literal))
                                     }
                                     (reply))))))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 4  2 4  3 nil  4 34))
  (prn "F - continue might never trigger"))

(reset)
(new-trace "new-primitive")
(let before Memory-in-use-until
  (add-fns
    '((main
        ((1 integer-address) <- new (integer type)))))
  (run 'main)
  ;? (prn memory*)
  (if (~iso memory*.1 before)
    (prn "F - 'new' returns current high-water mark"))
  (if (~iso Memory-in-use-until (+ before 1))
    (prn "F - 'new' on primitive types increments high-water mark by their size")))

(reset)
(new-trace "new-array-literal")
(let before Memory-in-use-until
  (add-fns
    '((main
        ((1 type-array-address) <- new (type-array type) (5 literal)))))
  (run 'main)
  ;? (prn memory*)
  (if (~iso memory*.1 before)
    (prn "F - 'new' on array with literal size returns current high-water mark"))
  (if (~iso Memory-in-use-until (+ before 5))
    (prn "F - 'new' on primitive arrays increments high-water mark by their size")))

(reset)
(new-trace "new-array-direct")
(let before Memory-in-use-until
  (add-fns
    '((main
        ((1 integer) <- copy (5 literal))
        ((2 type-array-address) <- new (type-array type) (1 integer)))))
  (run 'main)
  ;? (prn memory*)
  (if (~iso memory*.2 before)
    (prn "F - 'new' on array with variable size returns current high-water mark"))
  (if (~iso Memory-in-use-until (+ before 5))
    (prn "F - 'new' on primitive arrays increments high-water mark by their (variable) size")))

(reset)
(new-trace "scheduler")
(add-fns
  '((f1
      ((1 integer) <- copy (3 literal)))
    (f2
      ((2 integer) <- copy (4 literal)))))
(let ninsts (run 'f1 'f2)
  (when (~iso 2 ninsts)
    (prn "F - scheduler didn't run the right number of instructions: " ninsts)))
(if (~iso memory* (obj 1 3  2 4))
  (prn "F - scheduler runs multiple functions: " memory*))
(check-trace-contents "scheduler orders functions correctly"
  '(("schedule" "f1")
    ("schedule" "f2")
  ))
(check-trace-contents "scheduler orders schedule and run events correctly"
  '(("schedule" "f1")
    ("run" "f1 0")
    ("schedule" "f2")
    ("run" "f2 0")
  ))

(reset)
