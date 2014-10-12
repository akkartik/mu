; Mu: An exploration on making the global structure of programs more accessible.
;
;   "Is it a language, or an operating system, or a virtual machine? Mu."
;   (with apologies to Robert Pirsig: http://en.wikipedia.org/wiki/Mu_%28negative%29#In_popular_culture)
;
; I want to live in a world where I can have an itch to tweak a program, clone
; its open-source repository, orient myself on how it's organized, and make
; the simple change I envisioned, all in an afternoon. This codebase tries to
; make this possible for its readers. (More details: http://akkartik.name/about)
;
; What helps comprehend the global structure of programs? For starters, let's
; enumerate what doesn't: idiomatic code, adherence to a style guide or naming
; convention, consistent indentation, API documentation for each class, etc.
; These conventional considerations improve matters in the small, but don't
; help understand global organization. They help existing programmers manage
; day-to-day operations, but they can't turn outsider programmers into
; insiders. (Elaboration: http://akkartik.name/post/readable-bad)
;
; In my experience, two things have improved matters so far: version control
; and automated tests. Version control lets me rewind back to earlier, simpler
; times when the codebase was simpler, when its core skeleton was easier to
; ascertain. Indeed, arguably what came first is by definition the skeleton of
; a program, modulo major rewrites. Once you understand the skeleton, it
; becomes tractable to 'play back' later major features one by one. (Previous
; project that fleshed out this idea: http://akkartik.name/post/wart-layers)
;
; The second and biggest boost to comprehension comes from tests. Tests are
; good for writers for well-understood reasons: they avoid regressions, and
; they can influence code to be more decoupled and easier to change. In
; addition, tests are also good for the outsider reader because they permit
; active reading. If you can't build a program and run its tests it can't help
; you understand it. It hangs limp at best, and might even be actively
; misleading. If you can run its tests, however, it comes alive. You can step
; through scenarios in a debugger. You can add logging and scan logs to make
; sense of them. You can run what-if scenarios: "why is this line not written
; like this?" Make a change, rerun tests: "Oh, that's why." (Elaboration:
; http://akkartik.name/post/literate-programming)
;
; However, tests are only useful to the extent that they exist. Think back to
; your most recent codebase. Do you feel comfortable releasing a new version
; just because the tests pass? I'm not aware of any such project. There's just
; too many situations envisaged by the authors that were never encoded in a
; test. Even disciplined authors can't test for performance or race conditions
; or fault tolerance. If a line is phrased just so because of some subtle
; performance consideration, it's hard to communicate to newcomers.
;
; This isn't an arcane problem, and it isn't just a matter of altruism. As
; more and more such implicit considerations proliferate, and as the original
; authors are replaced by latecomers for day-to-day operations, knowledge is
; actively forgotten and lost. The once-pristine codebase turns into legacy
; code that is hard to modify without expensive and stress-inducing
; regressions.
;
; How to write tests for performance, fault tolerance, race conditions, etc.?
; How can we state and verify that a codepath doesn't ever perform memory
; allocation, or write to disk? It requires better, more observable primitives
; than we currently have. Modern operating systems have their roots in the
; 70s. Their interfaces were not designed to be testable. They provide no way
; to simulate a full disk, or a specific sequence of writes from different
; threads. We need something better.
;
; This project tries to move, groping, towards that 'something better', a
; platform that is both thoroughly tested and allows programs written for it
; to be thoroughly tested. It tries to answer the question:
;
;   If Denis Ritchie and Ken Thompson were to set out today to co-design unix
;   and C, knowing what we know about automated tests, what would they do
;   differently?
;
; To try to impose *some* constraints on this gigantic yak-shave, we'll try to
; keep both language and OS as simple as possible, focused entirely on
; permitting more kinds of tests, on first *collecting* all the information
; about implicit considerations in some form so that readers and tools can
; have at least some hope of making sense of it.
;
; The initial language will be just assembly. We'll try to make it convenient
; to program in with some simple localized rewrite rules inspired by lisp
; macros and literate programming. Programmers will have to do their own
; memory management and register allocation, but we'll provide libraries to
; help with them.
;
; The initial OS will provide just memory management and concurrency
; primitives. No users or permissions (we don't live on mainframes anymore),
; no kernel- vs user-mode, no virtual memory or process abstraction, all
; threads sharing a single address space (use VMs for security and
; sandboxing). The only use case we care about is getting a test harness to
; run some code, feed it data through blocking channels, stop it and observe
; its internals. The code under test is expected to cooperate in such testing,
; by logging important events for the test harness to observe. (More info:
; http://akkartik.name/post/tracing-tests)
;
; The common thread here is elimination of abstractions, and it's not an
; accident. Abstractions help insiders manage the evolution of a codebase, but
; they actively hinder outsiders in understanding it from scratch. This
; matters, because the funnel to turn outsiders into insiders is critical to
; the long-term life of a codebase. Perhaps authors should raise their
; estimation of the costs of abstraction, and go against their instincts for
; introducing it. That's what I'll be trying to do: question every abstraction
; before I introduce it. We'll see how it goes.

; ---

; Mu is currently built atop Racket and Arc, but this is temporary and
; contingent. We want to keep our options open, whether to port to a different
; host language, and easy to rewrite to native code for any platform. So we'll
; try to avoid 'cheating': relying on the host platform for advanced
; functionality.
;
; Other than that, we'll say no more about the code, and focus in the rest of
; this file on the scenarios the code cares about.

(load "mu.arc")

; Every test below is conceptually a run right after our virtual machine
; starts up. When it starts up we assume it knows about the following types.

(on-init
  (= types* (obj
              ; Each type must be scalar or array, sum or product or primitive
              type (obj size 1)  ; implicitly scalar and primitive
              type-address (obj size 1  address t  elem 'type)
              type-array (obj array t  elem 'type)
              type-array-address (obj size 1  address t  elem 'type-array)
              location (obj size 1  address t  elem 'location)  ; assume it points to an atom
              integer (obj size 1)
              boolean (obj size 1)
              boolean-address (obj size 1  address t)
              byte (obj size 1)
;?               string (obj array t  elem 'byte)  ; inspired by Go
              character (obj size 1)  ; int32 like a Go rune
              character-address (obj size 1  address t  elem 'character)
              string (obj size 1)  ; temporary hack
              ; arrays consist of an integer length followed by the right number of elems
              integer-array (obj array t  elem 'integer)
              integer-address (obj size 1  address t  elem 'integer)  ; pointer to int
              ; records consist of a series of elems, corresponding to a list of types
              integer-boolean-pair (obj size 2  record t  elems '(integer boolean))
              integer-boolean-pair-address (obj size 1  address t  elem 'integer-boolean-pair)
              integer-boolean-pair-array (obj array t  elem 'integer-boolean-pair)
              integer-integer-pair (obj size 2  record t  elems '(integer integer))
              integer-point-pair (obj size 2  record t  elems '(integer integer-integer-pair))
              ; tagged-values are the foundation of dynamic types
              tagged-value (obj size 2  record t  elems '(type location))
              tagged-value-address (obj size 1  address t  elem 'tagged-value)
              ; heterogeneous lists
              list (obj size 2  record t  elems '(tagged-value list-address))
              list-address (obj size 1  address t  elem 'list)
              list-address-address (obj size 1  address t  elem 'list-address)
              )))

; Our language is assembly-like in that functions consist of series of
; statements, and statements consist of an operation and its arguments (input
; and output).
;
;   oarg1, oarg2, ... <- op arg1, arg2, ...
;
; Args must be atomic, like an integer or a memory address, they can't be
; expressions doing arithmetic or function calls. But we can have any number
; of them.
;
; Since we're building on lisp, our code samples won't look quite like the
; idealized syntax above. For now they will be lists of lists:
;
;   (function-name
;     ((oarg1 oarg2 ... <- op arg1 arg2 ...)
;      ...
;      ...))
;
; Each arg/oarg is itself a list, with the payload value at the head, and
; various metadata in the rest. In this first example the only metadata is types:
; 'integer' for a memory location containing an integer, and 'literal' for a
; value included directly in code. (Assembly languages traditionally call them
; 'immediate' operands.) In the future a simple tool will check that the types
; line up as expected in each op. A different tool might add types where they
; aren't provided. Instead of a monolithic compiler I want to build simple,
; lightweight tools that can be combined in various ways, say for using
; different typecheckers in different subsystems.

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

; Our basic arithmetic ops can operate on memory locations or literals.
; (Ignore hardware details like registers for now.)

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
  '((test1
      ((1 integer) <- sub (1 literal) (3 literal)))))
(run 'test1)
;? (prn memory*)
(if (~is memory*.1 -2)
  (prn "F - 'sub' subtracts the second arg from the first"))

(reset)
(new-trace "mul-literal")
(add-fns
  '((test1
      ((1 integer) <- mul (2 literal) (3 literal)))))
(run 'test1)
;? (prn memory*)
(if (~is memory*.1 6)
  (prn "F - 'mul' multiplies like 'add' adds"))

(reset)
(new-trace "div-literal")
(add-fns
  '((test1
      ((1 integer) <- div (8 literal) (3 literal)))))
(run 'test1)
;? (prn memory*)
(if (~is memory*.1 (/ real.8 3))
  (prn "F - 'div' divides like 'sub' subtracts"))

(reset)
(new-trace "idiv-literal")
(add-fns
  '((test1
      ((1 integer) (2 integer) <- idiv (8 literal) (3 literal)))))
(run 'test1)
;? (prn memory*)
(if (~iso memory* (obj 1 2  2 2))
  (prn "F - 'idiv' performs integer division, returning quotient and retest1der"))

; Basic boolean operations: and, or, not
; There are easy ways to encode booleans in binary, but we'll skip past those
; details.

(reset)
(new-trace "and-literal")
(add-fns
  '((test1
      ((1 boolean) <- and (t literal) (nil literal)))))
(run 'test1)
;? (prn memory*)
(if (~is memory*.1 nil)
  (prn "F - logical 'and' for booleans"))

; Basic comparison operations: lt, le, gt, ge, eq, neq

(reset)
(new-trace "lt-literal")
(add-fns
  '((test1
      ((1 boolean) <- lt (4 literal) (3 literal)))))
(run 'test1)
;? (prn memory*)
(if (~is memory*.1 nil)
  (prn "F - 'lt' is the less-than inequality operator"))

(reset)
(new-trace "le-literal-false")
(add-fns
  '((test1
      ((1 boolean) <- le (4 literal) (3 literal)))))
(run 'test1)
;? (prn memory*)
(if (~is memory*.1 nil)
  (prn "F - 'le' is the <= inequality operator"))

(reset)
(new-trace "le-literal-true")
(add-fns
  '((test1
      ((1 boolean) <- le (4 literal) (4 literal)))))
(run 'test1)
;? (prn memory*)
(if (~is memory*.1 t)
  (prn "F - 'le' returns true for equal operands"))

(reset)
(new-trace "le-literal-true-2")
(add-fns
  '((test1
      ((1 boolean) <- le (4 literal) (5 literal)))))
(run 'test1)
;? (prn memory*)
(if (~is memory*.1 t)
  (prn "F - le is the <= inequality operator - 2"))

; Control flow operations: jmp, jif
; These introduce a new type -- 'offset' -- for literals that refer to memory
; locations relative to the current location.

(reset)
(new-trace "jmp-skip")
(add-fns
  '((test1
      ((1 integer) <- copy (8 literal))
      (jmp (1 offset))
      ((2 integer) <- copy (3 literal))  ; should be skipped
      (reply))))
(run 'test1)
;? (prn memory*)
(if (~iso memory* (obj 1 8))
  (prn "F - 'jmp' skips some instructions"))

(reset)
(new-trace "jmp-target")
(add-fns
  '((test1
      ((1 integer) <- copy (8 literal))
      (jmp (1 offset))
      ((2 integer) <- copy (3 literal))  ; should be skipped
      (reply)
      ((3 integer) <- copy (34 literal)))))  ; never reached
(run 'test1)
;? (prn memory*)
(if (~iso memory* (obj 1 8))
  (prn "F - 'jmp' doesn't skip too many instructions"))
;? (quit)

(reset)
(new-trace "jif-skip")
(add-fns
  '((test1
      ((2 integer) <- copy (1 literal))
      ((1 boolean) <- eq (1 literal) (2 integer))
      (jif (1 boolean) (1 offset))
      ((2 integer) <- copy (3 literal))
      (reply)
      ((3 integer) <- copy (34 literal)))))
(run 'test1)
;? (prn memory*)
(if (~iso memory* (obj 1 t  2 1))
  (prn "F - 'jif' is a conditional 'jmp'"))

(reset)
(new-trace "jif-fallthrough")
(add-fns
  '((test1
      ((1 boolean) <- eq (1 literal) (2 literal))
      (jif (3 boolean) (1 offset))
      ((2 integer) <- copy (3 literal))
      (reply)
      ((3 integer) <- copy (34 literal)))))
(run 'test1)
;? (prn memory*)
(if (~iso memory* (obj 1 nil  2 3))
  (prn "F - if 'jif's first arg is false, it doesn't skip any instructions"))

(reset)
(new-trace "jif-backward")
(add-fns
  '((test1
      ((1 integer) <- copy (2 literal))
      ((2 integer) <- copy (1 literal))
      ; loop
      ((2 integer) <- add (2 integer) (2 integer))
      ((3 boolean) <- eq (1 integer) (2 integer))
      (jif (3 boolean) (-3 offset))  ; to loop
      ((4 integer) <- copy (3 literal))
      (reply)
      ((3 integer) <- copy (34 literal)))))
(run 'test1)
;? (prn memory*)
(if (~iso memory* (obj 1 2  2 4  3 nil  4 3))
  (prn "F - 'jif' can take a negative offset to make backward jumps"))

; Data movement relies on addressing modes:
;   'direct' - refers to a memory location; default for most types.
;   'literal' - directly encoded in the code; implicit for some types like 'offset'.

(reset)
(new-trace "direct-addressing")
(add-fns
  '((test1
      ((1 integer) <- copy (34 literal))
      ((2 integer) <- copy (1 integer)))))
(run 'test1)
;? (prn memory*)
(if (~iso memory* (obj 1 34  2 34))
  (prn "F - 'copy' performs direct addressing"))

; 'Indirect' addressing refers to an address stored in a memory location.
; Indicated by the metadata 'deref'. Usually requires an address type.
; In the test below, the memory location 1 contains '2', so an indirect read
; of location 1 returns the value of location 2.

(reset)
(new-trace "indirect-addressing")
(add-fns
  '((test1
      ((1 integer-address) <- copy (2 literal))
      ((2 integer) <- copy (34 literal))
      ((3 integer) <- copy (1 integer-address deref)))))
(run 'test1)
;? (prn memory*)
(if (~iso memory* (obj 1 2  2 34  3 34))
  (prn "F - 'copy' performs indirect addressing"))

; Output args can use indirect addressing. In the test below the value is
; stored at the location stored in location 1 (i.e. location 2).

(reset)
(new-trace "indirect-addressing-oarg")
(add-fns
  '((test1
      ((1 integer-address) <- copy (2 literal))
      ((2 integer) <- copy (34 literal))
      ((1 integer-address deref) <- add (2 integer) (2 literal)))))
(run 'test1)
;? (prn memory*)
(if (~iso memory* (obj 1 2  2 36))
  (prn "F - instructions can perform indirect addressing on output arg"))

; Until now we've dealt with scalar types like integers and booleans and
; addresses. We can also have compound types: arrays and records.
;
; 'get' accesses fields in records
; 'index' accesses indices in arrays

(reset)
(new-trace "get-record")
(add-fns
  '((test1
      ((1 integer) <- copy (34 literal))
      ((2 boolean) <- copy (nil literal))
      ((3 boolean) <- get (1 integer-boolean-pair) (1 offset))
      ((4 integer) <- get (1 integer-boolean-pair) (0 offset)))))
(run 'test1)
;? (prn memory*)
(if (~iso memory* (obj 1 34  2 nil  3 nil  4 34))
  (prn "F - 'get' accesses fields of records"))

(reset)
(new-trace "get-indirect")
(add-fns
  '((test1
      ((1 integer) <- copy (34 literal))
      ((2 boolean) <- copy (nil literal))
      ((3 integer-boolean-pair-address) <- copy (1 literal))
      ((4 boolean) <- get (3 integer-boolean-pair-address deref) (1 offset))
      ((5 integer) <- get (3 integer-boolean-pair-address deref) (0 offset)))))
(run 'test1)
;? (prn memory*)
(if (~iso memory* (obj 1 34  2 nil  3 1  4 nil  5 34))
  (prn "F - 'get' accesses fields of record address"))

(reset)
(new-trace "get-compound-field")
(add-fns
  '((test1
      ((1 integer) <- copy (34 literal))
      ((2 integer) <- copy (35 literal))
      ((3 integer) <- copy (36 literal))
      ((4 integer-integer-pair) <- get (1 integer-point-pair) (1 offset)))))
(run 'test1)
;? (prn memory*)
(if (~iso memory* (obj 1 34  2 35  3 36  4 35  5 36))
  (prn "F - 'get' accesses fields spanning multiple locations"))

(reset)
(new-trace "get-address")
(add-fns
  '((test1
      ((1 integer) <- copy (34 literal))
      ((2 integer) <- copy (t literal))
      ((3 boolean-address) <- get-address (1 integer-boolean-pair) (1 offset)))))
(run 'test1)
;? (prn memory*)
(if (~iso memory* (obj 1 34  2 t  3 2))
  (prn "F - 'get-address' returns address of fields of records"))

(reset)
(new-trace "get-address-indirect")
(add-fns
  '((test1
      ((1 integer) <- copy (34 literal))
      ((2 integer) <- copy (t literal))
      ((3 integer-boolean-pair-address) <- copy (1 literal))
      ((4 boolean-address) <- get-address (3 integer-boolean-pair-address deref) (1 offset)))))
(run 'test1)
;? (prn memory*)
(if (~iso memory* (obj 1 34  2 t  3 1  4 2))
  (prn "F - 'get-address' accesses fields of record address"))

(reset)
(new-trace "index-array-literal")
(add-fns
  '((test1
      ((1 integer) <- copy (2 literal))
      ((2 integer) <- copy (23 literal))
      ((3 boolean) <- copy (nil literal))
      ((4 integer) <- copy (24 literal))
      ((5 boolean) <- copy (t literal))
      ((6 integer-boolean-pair) <- index (1 integer-boolean-pair-array) (1 literal)))))
(run 'test1)
;? (prn memory*)
(if (~iso memory* (obj 1 2  2 23 3 nil  4 24 5 t  6 24 7 t))
  (prn "F - 'index' accesses indices of arrays"))

(reset)
(new-trace "index-array-direct")
(add-fns
  '((test1
      ((1 integer) <- copy (2 literal))
      ((2 integer) <- copy (23 literal))
      ((3 boolean) <- copy (nil literal))
      ((4 integer) <- copy (24 literal))
      ((5 boolean) <- copy (t literal))
      ((6 integer) <- copy (1 literal))
      ((7 integer-boolean-pair) <- index (1 integer-boolean-pair-array) (6 integer)))))
(run 'test1)
;? (prn memory*)
(if (~iso memory* (obj 1 2  2 23 3 nil  4 24 5 t  6 1  7 24 8 t))
  (prn "F - 'index' accesses indices of arrays"))

(reset)
(new-trace "index-address")
(add-fns
  '((test1
      ((1 integer) <- copy (2 literal))
      ((2 integer) <- copy (23 literal))
      ((3 boolean) <- copy (nil literal))
      ((4 integer) <- copy (24 literal))
      ((5 boolean) <- copy (t literal))
      ((6 integer) <- copy (1 literal))
      ((7 integer-boolean-pair-address) <- index-address (1 integer-boolean-pair-array) (6 integer)))))
(run 'test1)
;? (prn memory*)
(if (~iso memory* (obj 1 2  2 23 3 nil  4 24 5 t  6 1  7 4))
  (prn "F - 'index-address' returns addresses of indices of arrays"))

; todo: test that out-of-bounds access throws an error

; Array values know their length. Record lengths are saved in the types table.

(reset)
(new-trace "len-array")
(add-fns
  '((test1
      ((1 integer) <- copy (2 literal))
      ((2 integer) <- copy (23 literal))
      ((3 boolean) <- copy (nil literal))
      ((4 integer) <- copy (24 literal))
      ((5 boolean) <- copy (t literal))
      ((6 integer) <- len (1 integer-boolean-pair-array)))))
(run 'test1)
;? (prn memory*)
(if (~iso memory* (obj 1 2  2 23 3 nil  4 24 5 t  6 2))
  (prn "F - 'len' accesses length of array"))

; 'sizeof' is a helper to determine the amount of memory required by a type.

(reset)
(new-trace "sizeof-record")
(add-fns
  '((test1
      ((1 integer) <- sizeof (integer-boolean-pair literal)))))
(run 'test1)
;? (prn memory*)
(if (~is memory*.1 2)
  (prn "F - 'sizeof' returns space required by arg"))

(reset)
(new-trace "sizeof-record-not-len")
(add-fns
  '((test1
      ((1 integer) <- sizeof (integer-point-pair literal)))))
(run 'test1)
;? (prn memory*)
(if (~is memory*.1 3)
  (prn "F - 'sizeof' is different from number of elems"))

; Regardless of a type's length, you can move it around just like a primitive.

(reset)
(new-trace "compound-operand-copy")
(add-fns
  '((test1
      ((1 integer) <- copy (34 literal))
      ((2 boolean) <- copy (nil literal))
      ((4 boolean) <- copy (t literal))
      ((3 integer-boolean-pair) <- copy (1 integer-boolean-pair)))))
(run 'test1)
;? (prn memory*)
(if (~iso memory* (obj 1 34  2 nil  3 34  4 nil))
  (prn "F - ops can operate on records spanning multiple locations"))

(reset)
(new-trace "compound-arg")
(add-fns
  '((test1
      ((4 integer-boolean-pair) <- arg))
    (main
      ((1 integer) <- copy (34 literal))
      ((2 boolean) <- copy (nil literal))
      (test1 (1 integer-boolean-pair)))))
(run 'main)
(if (~iso memory* (obj 1 34  2 nil  4 34  5 nil))
  (prn "F - 'arg' can copy records spanning multiple locations"))

(reset)
(new-trace "compound-arg")
;? (set dump-trace*)
(add-fns
  '((test1
      ((4 integer-boolean-pair) <- arg))
    (main
      ((1 integer) <- copy (34 literal))
      ((2 boolean) <- copy (nil literal))
      ((3 integer-boolean-pair-address) <- copy (1 literal))
      (test1 (3 integer-boolean-pair-address deref)))))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 34  2 nil  3 1  4 34  5 nil))
  (prn "F - 'arg' can copy records spanning multiple locations in indirect mode"))

; A special kind of record is the 'tagged type'. It lets us represent
; dynamically typed values, which save type information in memory rather than
; in the code to use them. This will let us do things like create heterogenous
; lists containing both integers and strings.

(reset)
(new-trace "tagged-value")
;? (set dump-trace*)
(add-fns
  '((test1
      ((1 type) <- copy (integer-address literal))
      ((2 integer-address) <- copy (34 literal))  ; pointer to nowhere
      ((3 integer-address) (4 boolean) <- maybe-coerce (1 tagged-value) (integer-address literal)))))
(run 'test1)
;? (prn memory*)
(if (or (~is memory*.3 34) (~is memory*.4 t))
  (prn "F - 'maybe-coerce' copies value only if type tag matches"))

(reset)
(new-trace "tagged-value-2")
;? (set dump-trace*)
(add-fns
  '((test1
      ((1 type) <- copy (integer-address literal))
      ((2 integer-address) <- copy (34 literal))  ; pointer to nowhere
      ((3 integer-address) (4 boolean) <- maybe-coerce (1 tagged-value) (boolean-address literal)))))
(run 'test1)
;? (prn memory*)
(if (or (~is memory*.3 0) (~is memory*.4 nil))
  (prn "F - 'maybe-coerce' doesn't copy value when type tag doesn't match"))

(reset)
(new-trace "new-tagged-value")
;? (set dump-trace*)
(add-fns
  '((test1
      ((1 integer-address) <- copy (34 literal))  ; pointer to nowhere
      ((2 tagged-value-address) <- new-tagged-value (integer-address literal) (1 integer-address))
      ((3 integer-address) (4 boolean) <- maybe-coerce (2 tagged-value-address deref) (integer-address literal)))))
(run 'test1)
;? (prn memory*)
(if (or (~is memory*.3 34) (~is memory*.4 t))
  (prn "F - 'new-tagged-value' is the converse of 'maybe-coerce'"))

; Now that we can record types for values we can construct a dynamically typed
; list.

(reset)
(new-trace "list")
;? (set dump-trace*)
(add-fns
  '((test1
      ; 1 points at first node: tagged-value (int 34)
      ((1 list-address) <- new (list type))
      ((2 tagged-value-address) <- get-address (1 list-address deref) (0 offset))
      ((3 type-address) <- get-address (2 tagged-value-address deref) (0 offset))
      ((3 type-address deref) <- copy (integer literal))
      ((4 location) <- get-address (2 tagged-value-address deref) (1 offset))
      ((4 location deref) <- copy (34 literal))
      ((5 list-address-address) <- get-address (1 list-address deref) (1 offset))
      ((5 list-address-address deref) <- new (list type))
      ; 6 points at second node: tagged-value (boolean t)
      ((6 list-address) <- copy (5 list-address-address deref))
      ((7 tagged-value-address) <- get-address (6 list-address deref) (0 offset))
      ((7 type-address) <- get-address (6 tagged-value-address deref) (0 offset))
      ((7 type-address deref) <- copy (boolean literal))
      ((8 location) <- get-address (6 tagged-value-address deref) (1 offset))
      ((8 location deref) <- copy (t literal)))))
(let first Memory-in-use-until
  (run 'test1)
;?   (prn memory*)
  (if (or (~all first (map memory* '(1 2 3)))
          (~is memory*.first  'integer)
          (~is memory*.4 (+ first 1))
          (~is (memory* (+ first 1))  34)
          (~is memory*.5 (+ first 2))
          (let second memory*.6
            (~is (memory* (+ first 2)) second)
            (~is memory*.7 second)
            (~is memory*.second 'boolean)
            (~is memory*.8 (+ second 1))
            (~is (memory* (+ second 1)) t)))
    (prn "F - 'list' constructs a heterogeneous list, which can contain elements of different types")))

; Just like the table of types is centralized, functions are conceptualized as
; a centralized table of operations just like the 'primitives' we've seen so
; far. If you create a function you can call it like any other op.

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

; User-defined functions communicate with their callers through two
; primitives:
;
;   'arg' - to access inputs
;   'reply' - to return outputs

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

(reset)
(new-trace "new-fn-arg-status")
(add-fns
  '((test1
      ((4 integer) (5 boolean) <- arg))
    (main
      (test1 (1 literal))
    )))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 4 1  5 t))
  (prn "F - 'arg' sets a second oarg when arg exists"))
;? (quit)

(reset)
(new-trace "new-fn-arg-missing")
(add-fns
  '((test1
      ((4 integer) <- arg)
      ((5 integer) <- arg))
    (main
      (test1 (1 literal))
    )))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 4 1))
  (prn "F - missing 'arg' doesn't cause error"))
;? (quit)

(reset)
(new-trace "new-fn-arg-missing-2")
(add-fns
  '((test1
      ((4 integer) <- arg)
      ((5 integer) (6 boolean) <- arg))
    (main
      (test1 (1 literal))
    )))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 4 1  6 nil))
  (prn "F - missing 'arg' wipes second oarg when provided"))
;? (quit)

(reset)
(new-trace "new-fn-arg-missing-3")
(add-fns
  '((test1
      ((4 integer) <- arg)
      ((5 integer) <- copy (34 literal))
      ((5 integer) (6 boolean) <- arg))
    (main
      (test1 (1 literal))
    )))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 4 1  6 nil))
  (prn "F - missing 'arg' consistently wipes its oarg"))
;? (quit)

(reset)
(new-trace "new-fn-arg-missing-3")
(add-fns
  '((test1
      ; if given two args, adds them; if given one arg, increments
      ((4 integer) <- arg)
      ((5 integer) (6 boolean) <- arg)
      { begin
        (breakif (6 boolean))
        ((5 integer) <- copy (1 literal))
      }
      ((7 integer) <- add (4 integer) (5 integer)))
    (main
      (test1 (34 literal))
    )))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 4 34  5 1  6 nil  7 35))
  (prn "F - function with optional second arg"))
;? (quit)

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

; 'type' and 'otype' let us create generic functions that run different code
; based on what args the caller provides, or what oargs the caller expects.
;
; These operations are almost certainly bad ideas; they violate our constraint
; of easily assembling down to native code. We'll eventually switch to dynamic
; typing with tagged-values.

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

; Our control operators are quite inconvenient to use, so mu provides a
; lightweight tool called 'convert-braces' to work in a slightly more
; convenient format with nested braces:
;
;   {
;     some instructions
;     {
;       more instructions
;     }
;   }
;
; Braces are just labels, they require no special parsing. The operations
; 'break' and 'continue' jump to just after the enclosing '}' and '{'
; respectively.
;
; Conditional and unconditional 'break' and 'continue' should give us 80% of
; the benefits of the control-flow primitives we're used to in other
; languages, like 'if', 'while', 'for', etc.

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
;? (set dump-trace*)
(add-fns `((main ,@(convert-braces '(((1 integer) <- copy (4 literal))
                                     ((2 integer) <- copy (1 literal))
                                     { begin
                                     ((2 integer) <- add (2 integer) (2 integer))
                                     ((3 boolean) <- neq (1 integer) (2 integer))
                                     (continueif (3 boolean))
                                     ((4 integer) <- copy (34 literal))
                                     }
                                     (reply))))))
;? (each stmt function*!main
;?   (prn stmt))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 4  2 4  3 nil  4 34))
  (prn "F - continue correctly loops"))

; todo: fuzz-test invariant: convert-braces offsets should be robust to any
; number of inner blocks inside but not around the continue block.

(reset)
(new-trace "continue-nested")
;? (set dump-trace*)
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
;? (each stmt function*!main
;?   (prn stmt))
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

; A rudimentary memory allocator. Eventually we want to write this in mu.

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
  (if (~iso Memory-in-use-until (+ before 6))
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
  (if (~iso Memory-in-use-until (+ before 6))
    (prn "F - 'new' on primitive arrays increments high-water mark by their (variable) size")))

; A rudimentary process scheduler. You can 'run' multiple functions at once,
; and they share the virtual processor.
; There's also a 'fork' primitive to let functions create new threads of
; execution.
; Eventually we want to allow callers to influence how much of their CPU they
; give to their 'children', or to rescind a child's running privileges.

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

; The scheduler needs to keep track of the call stack for each thread.
; Eventually we'll want to save this information in mu's address space itself,
; along with the types array, the magic buffers for args and oargs, and so on.
;
; Eventually we want the right stack-management primitives to build delimited
; continuations in mu.

(reset)  ; end file with this to persist the trace for the final test
