; Mu: An exploration on making the global structure of programs more accessible.
;
;   "Is it a language, or an operating system, or a virtual machine? Mu."
;   (with apologies to Robert Pirsig: http://en.wikipedia.org/wiki/Mu_%28negative%29#In_popular_culture)
;
;; Motivation
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

;; Getting started
;
; Mu is currently built atop Racket and Arc, but this is temporary and
; contingent. We want to keep our options open, whether to port to a different
; host language, and easy to rewrite to native code for any platform. So we'll
; try to avoid 'cheating': relying on the host platform for advanced
; functionality.
;
; Other than that, we'll say no more about the code, and focus in the rest of
; this file on the scenarios the code cares about.

(load "mu.arc")

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
;
; In our tests we'll define such mu functions using a call to 'add-fns', so
; look for it. Everything outside 'add-fns' is just test-harness details.

(reset)
;? (set dump-trace*)
(new-trace "literal")
(add-fns
  '((main
      ((1 integer) <- copy (23 literal)))))
;? (set dump-trace*)
(run 'main)
;? (prn memory*)
(if (~is memory*.1 23)
  (prn "F - 'copy' writes its lone 'arg' after the instruction name to its lone 'oarg' or output arg before the arrow. After this test, the value 23 is stored in memory address 1."))
;? (quit)

; Our basic arithmetic ops can operate on memory locations or literals.
; (Ignore hardware details like registers for now.)

(reset)
(new-trace "add")
(add-fns
  '((main
      ((1 integer) <- copy (1 literal))
      ((2 integer) <- copy (3 literal))
      ((3 integer) <- add (1 integer) (2 integer)))))
(run 'main)
(if (~iso memory* (obj 1 1  2 3  3 4))
  (prn "F - 'add' operates on two addresses"))

(reset)
(new-trace "add-literal")
(add-fns
  '((main
      ((1 integer) <- add (2 literal) (3 literal)))))
(run 'main)
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
  (prn "F - 'sub' subtracts the second arg from the first"))

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
  (prn "F - 'div' divides like 'sub' subtracts"))

(reset)
(new-trace "idiv-literal")
(add-fns
  '((main
      ((1 integer) (2 integer) <- idiv (23 literal) (6 literal)))))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 3  2 5))
  (prn "F - 'idiv' performs integer division, returning quotient and remainder"))

(reset)
(new-trace "dummy-oarg")
;? (set dump-trace*)
(add-fns
  '((main
      (_ (2 integer) <- idiv (23 literal) (6 literal)))))
(run 'main)
(if (~iso memory* (obj 2 5))
  (prn "F - '_' oarg can ignore some results"))
;? (quit)

; Basic boolean operations: and, or, not
; There are easy ways to encode booleans in binary, but we'll skip past those
; details for now.

(reset)
(new-trace "and-literal")
(add-fns
  '((main
      ((1 boolean) <- and (t literal) (nil literal)))))
(run 'main)
;? (prn memory*)
(if (~is memory*.1 nil)
  (prn "F - logical 'and' for booleans"))

; Basic comparison operations: lt, le, gt, ge, eq, neq

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

; Control flow operations: jump, jump-if, jump-unless
; These introduce a new type -- 'offset' -- for literals that refer to memory
; locations relative to the current location.

(reset)
(new-trace "jump-skip")
(add-fns
  '((main
      ((1 integer) <- copy (8 literal))
      (jump (1 offset))
      ((2 integer) <- copy (3 literal))  ; should be skipped
      (reply))))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 8))
  (prn "F - 'jump' skips some instructions"))

(reset)
(new-trace "jump-target")
(add-fns
  '((main
      ((1 integer) <- copy (8 literal))
      (jump (1 offset))
      ((2 integer) <- copy (3 literal))  ; should be skipped
      (reply)
      ((3 integer) <- copy (34 literal)))))  ; never reached
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 8))
  (prn "F - 'jump' doesn't skip too many instructions"))
;? (quit)

(reset)
(new-trace "jump-if-skip")
(add-fns
  '((main
      ((2 integer) <- copy (1 literal))
      ((1 boolean) <- eq (1 literal) (2 integer))
      (jump-if (1 boolean) (1 offset))
      ((2 integer) <- copy (3 literal))
      (reply)
      ((3 integer) <- copy (34 literal)))))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 t  2 1))
  (prn "F - 'jump-if' is a conditional 'jump'"))

(reset)
(new-trace "jump-if-fallthrough")
(add-fns
  '((main
      ((1 boolean) <- eq (1 literal) (2 literal))
      (jump-if (3 boolean) (1 offset))
      ((2 integer) <- copy (3 literal))
      (reply)
      ((3 integer) <- copy (34 literal)))))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 nil  2 3))
  (prn "F - if 'jump-if's first arg is false, it doesn't skip any instructions"))

(reset)
(new-trace "jump-if-backward")
(add-fns
  '((main
      ((1 integer) <- copy (2 literal))
      ((2 integer) <- copy (1 literal))
      ; loop
      ((2 integer) <- add (2 integer) (2 integer))
      ((3 boolean) <- eq (1 integer) (2 integer))
      (jump-if (3 boolean) (-3 offset))  ; to loop
      ((4 integer) <- copy (3 literal))
      (reply)
      ((3 integer) <- copy (34 literal)))))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 2  2 4  3 nil  4 3))
  (prn "F - 'jump-if' can take a negative offset to make backward jumps"))

; Data movement relies on addressing modes:
;   'direct' - refers to a memory location; default for most types.
;   'literal' - directly encoded in the code; implicit for some types like 'offset'.

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

; 'Indirect' addressing refers to an address stored in a memory location.
; Indicated by the metadata 'deref'. Usually requires an address type.
; In the test below, the memory location 1 contains '2', so an indirect read
; of location 1 returns the value of location 2.

(reset)
(new-trace "indirect-addressing")
(add-fns
  '((main
      ((1 integer-address) <- copy (2 literal))  ; unsafe; can't do this in general
      ((2 integer) <- copy (34 literal))
      ((3 integer) <- copy (1 integer-address deref)))))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 2  2 34  3 34))
  (prn "F - 'copy' performs indirect addressing"))

; Output args can use indirect addressing. In the test below the value is
; stored at the location stored in location 1 (i.e. location 2).

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

;; Compound data types
;
; Until now we've dealt with scalar types like integers and booleans and
; addresses, where mu looks like other assembly languages. In addition, mu
; provides first-class support for compound types: arrays and records.
;
; 'get' accesses fields in records
; 'index' accesses indices in arrays
;
; Both operations require knowledge about the types being worked on, so all
; types used in mu programs are defined in a single global system-wide table
; (see types* in mu.arc for the complete list of types; we'll add to it over
; time).

; first a sanity check that the table of types is consistent
(reset)
(each (typ typeinfo) types*
  (when typeinfo!record
    (assert (is typeinfo!size (len typeinfo!elems)))
    (when typeinfo!fields
      (assert (is typeinfo!size (len typeinfo!fields))))))

(reset)
(new-trace "get-record")
(add-fns
  '((main
      ((1 integer) <- copy (34 literal))
      ((2 boolean) <- copy (nil literal))
      ((3 boolean) <- get (1 integer-boolean-pair) (1 offset))
      ((4 integer) <- get (1 integer-boolean-pair) (0 offset)))))
;? (set dump-trace*)
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
;? (set dump-trace*)
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
      ((2 boolean) <- copy (t literal))
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
      ((2 boolean) <- copy (t literal))
      ((3 integer-boolean-pair-address) <- copy (1 literal))
      ((4 boolean-address) <- get-address (3 integer-boolean-pair-address deref) (1 offset)))))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 34  2 t  3 1  4 2))
  (prn "F - 'get-address' accesses fields of record address"))

(reset)
(new-trace "index-literal")
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
;? (quit)

(reset)
(new-trace "index-direct")
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
;? (quit)

(reset)
(new-trace "index-indirect")
(add-fns
  '((main
      ((1 integer) <- copy (2 literal))
      ((2 integer) <- copy (23 literal))
      ((3 boolean) <- copy (nil literal))
      ((4 integer) <- copy (24 literal))
      ((5 boolean) <- copy (t literal))
      ((6 integer) <- copy (1 literal))
      ((7 integer-boolean-pair-array-address) <- copy (1 literal))
      ((8 integer-boolean-pair) <- index (7 integer-boolean-pair-array-address deref) (6 integer)))))
;? (= dump-trace* (obj blacklist '("sz" "m" "setm" "addr" "cvt0" "cvt1")))
;? (set dump-trace*)
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 2  2 23 3 nil  4 24 5 t  6 1  7 1  8 24 9 t))
  (prn "F - 'index' accesses indices of array address"))
;? (quit)

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
(new-trace "index-address-indirect")
(add-fns
  '((main
      ((1 integer) <- copy (2 literal))
      ((2 integer) <- copy (23 literal))
      ((3 boolean) <- copy (nil literal))
      ((4 integer) <- copy (24 literal))
      ((5 boolean) <- copy (t literal))
      ((6 integer) <- copy (1 literal))
      ((7 integer-boolean-pair-array-address) <- copy (1 literal))
      ((8 integer-boolean-pair-address) <- index-address (7 integer-boolean-pair-array-address deref) (6 integer)))))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 2  2 23 3 nil  4 24 5 t  6 1  7 1  8 4))
  (prn "F - 'index-address' returns addresses of indices of array addresses"))

; Array values know their length. Record lengths are saved in the types table.

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
(new-trace "len-array-indirect")
(add-fns
  '((main
      ((1 integer) <- copy (2 literal))
      ((2 integer) <- copy (23 literal))
      ((3 boolean) <- copy (nil literal))
      ((4 integer) <- copy (24 literal))
      ((5 boolean) <- copy (t literal))
      ((6 integer-address) <- copy (1 literal))
      ((7 integer) <- len (6 integer-boolean-pair-array-address deref)))))
;? (set dump-trace*)
;? (= dump-trace* (obj blacklist '("sz" "m" "setm" "addr" "cvt0" "cvt1")))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 2  2 23 3 nil  4 24 5 t  6 1  7 2))
  (prn "F - 'len' accesses length of array address"))

; 'sizeof' is a helper to determine the amount of memory required by a type.

(reset)
(new-trace "sizeof-record")
(add-fns
  '((main
      ((1 integer) <- sizeof (integer-boolean-pair literal)))))
(run 'main)
;? (prn memory*)
(if (~is memory*.1 2)
  (prn "F - 'sizeof' returns space required by arg"))

(reset)
(new-trace "sizeof-record-not-len")
(add-fns
  '((main
      ((1 integer) <- sizeof (integer-point-pair literal)))))
(run 'main)
;? (prn memory*)
(if (~is memory*.1 3)
  (prn "F - 'sizeof' is different from number of elems"))

; Regardless of a type's length, you can move it around just like a primitive.

(reset)
(new-trace "compound-operand-copy")
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
(new-trace "compound-arg-indirect")
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
; lists containing both integers and strings. Tagged values admit two
; operations:
;
;   'save-type' - turns a regular value into a tagged-value of the appropriate type
;   'maybe-coerce' - turns a tagged value into a regular value if the type matches

(reset)
(new-trace "tagged-value")
;? (= dump-trace* (obj blacklist '("sz" "m" "setm" "addr" "cvt0" "cvt1")))
(add-fns
  '((main
      ((1 type) <- copy (integer-address literal))
      ((2 integer-address) <- copy (34 literal))  ; pointer to nowhere
      ((3 integer-address) (4 boolean) <- maybe-coerce (1 tagged-value) (integer-address literal)))))
(run 'main)
;? (prn memory*)
;? (prn completed-routines*)
(each routine completed-routines*
  (aif rep.routine!error (prn "error - " it)))
(if (or (~is memory*.3 34) (~is memory*.4 t))
  (prn "F - 'maybe-coerce' copies value only if type tag matches"))
;? (quit)

(reset)
(new-trace "tagged-value-2")
;? (set dump-trace*)
(add-fns
  '((main
      ((1 type) <- copy (integer-address literal))
      ((2 integer-address) <- copy (34 literal))  ; pointer to nowhere
      ((3 integer-address) (4 boolean) <- maybe-coerce (1 tagged-value) (boolean-address literal)))))
(run 'main)
;? (prn memory*)
(if (or (~is memory*.3 0) (~is memory*.4 nil))
  (prn "F - 'maybe-coerce' doesn't copy value when type tag doesn't match"))

(reset)
(new-trace "save-type")
(add-fns
  '((main
      ((1 integer-address) <- copy (34 literal))  ; pointer to nowhere
      ((2 tagged-value) <- save-type (1 integer-address)))))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj  1 34  2 'integer-address  3 34))
  (prn "F - 'save-type' saves the type of a value at runtime, turning it into a tagged-value"))

(reset)
(new-trace "new-tagged-value")
(add-fns
  '((main
      ((1 integer-address) <- copy (34 literal))  ; pointer to nowhere
      ((2 tagged-value-address) <- new-tagged-value (integer-address literal) (1 integer-address))
      ((3 integer-address) (4 boolean) <- maybe-coerce (2 tagged-value-address deref) (integer-address literal)))))
;? (= dump-trace* (obj blacklist '("sz" "m" "setm" "addr" "cvt0" "cvt1" "sizeof")))
(run 'main)
;? (prn memory*)
(if (or (~is memory*.3 34) (~is memory*.4 t))
  (prn "F - 'new-tagged-value' is the converse of 'maybe-coerce'"))
;? (quit)

; Now that we can record types for values we can construct a dynamically typed
; list.

(reset)
(new-trace "list")
;? (set dump-trace*)
(add-fns
  '((test1
      ; 1 points at first node: tagged-value (int 34)
      ((1 list-address) <- new (list literal))
      ((2 tagged-value-address) <- list-value-address (1 list-address))
      ((3 type-address) <- get-address (2 tagged-value-address deref) (0 offset))
      ((3 type-address deref) <- copy (integer literal))
      ((4 location) <- get-address (2 tagged-value-address deref) (1 offset))
      ((4 location deref) <- copy (34 literal))
      ((5 list-address-address) <- get-address (1 list-address deref) (1 offset))
      ((5 list-address-address deref) <- new (list literal))
      ; 6 points at second node: tagged-value (boolean t)
      ((6 list-address) <- copy (5 list-address-address deref))
      ((7 tagged-value-address) <- list-value-address (6 list-address))
      ((8 type-address) <- get-address (7 tagged-value-address deref) (0 offset))
      ((8 type-address deref) <- copy (boolean literal))
      ((9 location) <- get-address (7 tagged-value-address deref) (1 offset))
      ((9 location deref) <- copy (t literal))
      ((10 list-address) <- get (6 list-address deref) (1 offset))
      )))
(let first Memory-in-use-until
  (run 'test1)
;?   (prn memory*)
  (if (or (~all first (map memory* '(1 2 3)))
          (~is memory*.first  'integer)
          (~is memory*.4 (+ first 1))
          (~is (memory* (+ first 1))  34)
          (~is memory*.5 (+ first 2))
          (let second memory*.6
            (or
              (~is (memory* (+ first 2)) second)
              (~all second (map memory* '(6 7 8)))
              (~is memory*.second 'boolean)
              (~is memory*.9 (+ second 1))
              (~is (memory* (+ second 1)) t)
              (~is memory*.10 nil))))
    (prn "F - lists can contain elements of different types")))
(add-fns
  '((test2
      ((10 list-address) <- list-next (1 list-address)))))
(run 'test2)
;? (prn memory*)
(if (~is memory*.10 memory*.6)
  (prn "F - 'list-next can move a list pointer to the next node"))

; 'new-list' takes a variable number of args and constructs a list containing
; them.

(reset)
(new-trace "new-list")
(add-fns
  '((main
      ((1 integer) <- new-list (3 literal) (4 literal) (5 literal)))))
;? (= dump-trace* (obj blacklist '("sz" "m" "setm" "addr" "cvt0" "cvt1" "sizeof")))
(run 'main)
;? (prn memory*)
(let first memory*.1
;?   (prn first)
  (if (or (~is memory*.first  'integer)
          (~is (memory* (+ first 1))  3)
          (let second (memory* (+ first 2))
;?             (prn second)
            (or (~is memory*.second 'integer)
                (~is (memory* (+ second 1)) 4)
                (let third (memory* (+ second 2))
;?                   (prn third)
                  (or (~is memory*.third 'integer)
                      (~is (memory* (+ third 1)) 5)
                      (~is (memory* (+ third 2) nil)))))))
    (prn "F - 'new-list' can construct a list of integers")))

;; Functions
;
; Just like the table of types is centralized, functions are conceptualized as
; a centralized table of operations just like the "primitives" we've seen so
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
;? (= dump-trace* (obj whitelist '("run")))
(run 'main)
(if (~is 2 curr-cycle*)
  (prn "F - calling a user-defined function runs its instructions exactly once " curr-cycle*))
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
  '((test1
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
;? (= dump-trace* (obj whitelist '("run")))
(run 'main)
(if (~is 5 curr-cycle*)
  (prn "F - 'reply' executes instructions exactly once " curr-cycle*))
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
;? (set dump-trace*)
(add-fns
  '((test1
      ((5 integer) <- arg (1 literal))
      ((4 integer) <- arg (0 literal))
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
(new-trace "new-fn-arg-missing-4")
(add-fns
  '((test1
      ; if given two args, adds them; if given one arg, increments
      ((4 integer) <- arg)
      ((5 integer) (6 boolean) <- arg)
      { begin
        (break-if (6 boolean))
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

(reset)
(new-trace "new-fn-arg-by-value")
(add-fns
  '((test1
      ((1 integer) <- copy (0 literal))  ; overwrite caller memory
      ((2 integer) <- arg))  ; arg not clobbered
    (main
      ((1 integer) <- copy (34 literal))
      (test1 (1 integer)))))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 0  2 34))
  (prn "F - 'arg' passes by value"))

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
(new-trace "new-fn-prepare-reply")
(add-fns
  '((test1
      ((4 integer) <- arg)
      ((5 integer) <- arg)
      ((6 integer) <- add (4 integer) (5 integer))
      (prepare-reply (6 integer) (5 integer))
      (reply)
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
  (prn "F - without args, 'reply' returns values from previous 'prepare-reply'."))

;; Structured programming
;
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
(if (~iso (convert-braces
            '(((1 integer) <- copy (4 literal))
              ((2 integer) <- copy (2 literal))
              ((3 integer) <- add (2 integer) (2 integer))
              { begin  ; 'begin' is just a hack because racket turns curlies into parens
                ((4 boolean) <- neq (1 integer) (3 integer))
                (break-if (4 boolean))
                ((5 integer) <- copy (34 literal))
              }
              (reply)))
          '(((1 integer) <- copy (4 literal))
            ((2 integer) <- copy (2 literal))
            ((3 integer) <- add (2 integer) (2 integer))
            ((4 boolean) <- neq (1 integer) (3 integer))
            (jump-if (4 boolean) (1 offset))
            ((5 integer) <- copy (34 literal))
            (reply)))
  (prn "F - convert-braces replaces break-if with a jump-if to after the next close-curly"))

(reset)
(new-trace "convert-braces-empty-block")
(if (~iso (convert-braces
            '(((1 integer) <- copy (4 literal))
              ((2 integer) <- copy (2 literal))
              ((3 integer) <- add (2 integer) (2 integer))
              { begin
                (break)
              }
              (reply)))
          '(((1 integer) <- copy (4 literal))
            ((2 integer) <- copy (2 literal))
            ((3 integer) <- add (2 integer) (2 integer))
            (jump (0 offset))
            (reply)))
  (prn "F - convert-braces works for degenerate blocks"))

(reset)
(new-trace "convert-braces-nested-break")
(if (~iso (convert-braces
            '(((1 integer) <- copy (4 literal))
              ((2 integer) <- copy (2 literal))
              ((3 integer) <- add (2 integer) (2 integer))
              { begin
                ((4 boolean) <- neq (1 integer) (3 integer))
                (break-if (4 boolean))
                { begin
                  ((5 integer) <- copy (34 literal))
                }
              }
              (reply)))
          '(((1 integer) <- copy (4 literal))
            ((2 integer) <- copy (2 literal))
            ((3 integer) <- add (2 integer) (2 integer))
            ((4 boolean) <- neq (1 integer) (3 integer))
            (jump-if (4 boolean) (1 offset))
            ((5 integer) <- copy (34 literal))
            (reply)))
  (prn "F - convert-braces balances curlies when converting break"))

(reset)
(new-trace "convert-braces-nested-continue")
(if (~iso (convert-braces
            '(((1 integer) <- copy (4 literal))
              ((2 integer) <- copy (2 literal))
              { begin
                ((3 integer) <- add (2 integer) (2 integer))
                { begin
                  ((4 boolean) <- neq (1 integer) (3 integer))
                }
                (continue-if (4 boolean))
                ((5 integer) <- copy (34 literal))
              }
              (reply)))
          '(((1 integer) <- copy (4 literal))
            ((2 integer) <- copy (2 literal))
            ((3 integer) <- add (2 integer) (2 integer))
            ((4 boolean) <- neq (1 integer) (3 integer))
            (jump-if (4 boolean) (-3 offset))
            ((5 integer) <- copy (34 literal))
            (reply)))
  (prn "F - convert-braces balances curlies when converting continue"))

(reset)
(new-trace "continue")
;? (set dump-trace*)
(add-fns
  '((main
      ((1 integer) <- copy (4 literal))
      ((2 integer) <- copy (1 literal))
      { begin
        ((2 integer) <- add (2 integer) (2 integer))
        ((3 boolean) <- neq (1 integer) (2 integer))
        (continue-if (3 boolean))
        ((4 integer) <- copy (34 literal))
      }
      (reply))))
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
(add-fns
  '((main
      ((1 integer) <- copy (4 literal))
      ((2 integer) <- copy (1 literal))
      { begin
        ((2 integer) <- add (2 integer) (2 integer))
        { begin
          ((3 boolean) <- neq (1 integer) (2 integer))
        }
        (continue-if (3 boolean))
        ((4 integer) <- copy (34 literal))
      }
      (reply))))
;? (each stmt function*!main
;?   (prn stmt))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 4  2 4  3 nil  4 34))
  (prn "F - continue correctly loops"))

(reset)
(new-trace "continue-fail")
(add-fns
  '((main
      ((1 integer) <- copy (4 literal))
      ((2 integer) <- copy (2 literal))
      { begin
        ((2 integer) <- add (2 integer) (2 integer))
        { begin
          ((3 boolean) <- neq (1 integer) (2 integer))
        }
        (continue-if (3 boolean))
        ((4 integer) <- copy (34 literal))
      }
      (reply))))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 4  2 4  3 nil  4 34))
  (prn "F - continue might never trigger"))

;; Variables
;
; A big convenience high-level languages provide is the ability to name memory
; locations. In mu, a lightweight tool called 'convert-names' provides this
; convenience.

(reset)
;? (new-trace "convert-names")
(if (~iso (convert-names
            '(((x integer) <- copy (4 literal))
              ((y integer) <- copy (2 literal))
              ((z integer) <- add (x integer) (y integer))))
          '(((1 integer) <- copy (4 literal))
            ((2 integer) <- copy (2 literal))
            ((3 integer) <- add (1 integer) (2 integer))))
  (prn "F - convert-names renames symbolic names to integer locations"))

(reset)
;? (new-trace "convert-names-compound")
(if (~iso (convert-names
            '(((x integer-boolean-pair) <- copy (4 literal))
              ((y integer) <- copy (2 literal))))
          '(((1 integer-boolean-pair) <- copy (4 literal))
            ((3 integer) <- copy (2 literal))))
  (prn "F - convert-names increments integer locations by the size of the type of the previous var"))

(reset)
;? (new-trace "convert-names-nil")
(if (~iso (convert-names
            '(((x integer) <- copy (4 literal))
              ((y integer) <- copy (2 literal))
              ((nil integer) <- add (x integer) (y integer))))
          '(((1 integer) <- copy (4 literal))
            ((2 integer) <- copy (2 literal))
            ((nil integer) <- add (1 integer) (2 integer))))
  (prn "F - convert-names never renames nil"))

(reset)
;? (new-trace "convert-names-global")
(if (~iso (convert-names
            '(((x integer) <- copy (4 literal))
              ((y integer global) <- copy (2 literal))
              ((default-scope integer) <- add (x integer) (y integer global))))
          '(((1 integer) <- copy (4 literal))
            ((y integer global) <- copy (2 literal))
            ((default-scope integer) <- add (1 integer) (y integer global))))
  (prn "F - convert-names never renames global operands"))

; kludgy support for 'fork' below
(reset)
;? (new-trace "convert-names-functions")
(if (~iso (convert-names
            '(((x integer) <- copy (4 literal))
              ((y integer) <- copy (2 literal))
              ((z fn) <- add (x integer) (y integer))))
          '(((1 integer) <- copy (4 literal))
            ((2 integer) <- copy (2 literal))
            ((z fn) <- add (1 integer) (2 integer))))
  (prn "F - convert-names never renames nil"))

(reset)
;? (new-trace "convert-names-record-fields")
(if (~iso (convert-names
            '(((x integer) <- get (34 integer-boolean-pair) (bool offset))))
          '(((1 integer) <- get (34 integer-boolean-pair) (1 offset))))
  (prn "F - convert-names replaces record field offsets"))

(reset)
;? (new-trace "convert-names-record-fields-ambiguous")
(if (errsafe (convert-names
               '(((bool boolean) <- copy (t literal))
                 ((x integer) <- get (34 integer-boolean-pair) (bool offset)))))
  (prn "F - convert-names doesn't allow offsets and variables with the same name in a function"))

(reset)
;? (new-trace "convert-names-record-fields-ambiguous-2")
(if (errsafe (convert-names
               '(((x integer) <- get (34 integer-boolean-pair) (bool offset))
                 ((bool boolean) <- copy (t literal)))))
  (prn "F - convert-names doesn't allow offsets and variables with the same name in a function - 2"))

(reset)
;? (new-trace "convert-names-record-fields-indirect")
(if (~iso (convert-names
            '(((x integer) <- get (34 integer-boolean-pair-address deref) (bool offset))))
          '(((1 integer) <- get (34 integer-boolean-pair-address deref) (1 offset))))
  (prn "F - convert-names replaces field offsets for record addresses"))

(reset)
;? (new-trace "convert-names-record-fields-multiple")
(if (~iso (convert-names
            '(((2 boolean) <- get (1 integer-boolean-pair) (bool offset))
              ((3 boolean) <- get (1 integer-boolean-pair) (bool offset))))
          '(((2 boolean) <- get (1 integer-boolean-pair) (1 offset))
            ((3 boolean) <- get (1 integer-boolean-pair) (1 offset))))
  (prn "F - convert-names replaces field offsets with multiple mentions"))
;? (quit)

; A rudimentary memory allocator. Eventually we want to write this in mu.
;
; No deallocation yet; let's see how much code we can build in mu before we
; feel the need for it.

(reset)
(new-trace "new-primitive")
(add-fns
  '((main
      ((1 integer-address) <- new (integer literal)))))
(let before Memory-in-use-until
  (run 'main)
;?   (prn memory*)
  (if (~iso memory*.1 before)
    (prn "F - 'new' returns current high-water mark"))
  (if (~iso Memory-in-use-until (+ before 1))
    (prn "F - 'new' on primitive types increments high-water mark by their size")))

(reset)
(new-trace "new-array-literal")
(add-fns
  '((main
      ((1 type-array-address) <- new (type-array literal) (5 literal)))))
(let before Memory-in-use-until
  (run 'main)
;?   (prn memory*)
  (if (~iso memory*.1 before)
    (prn "F - 'new' on array with literal size returns current high-water mark"))
  (if (~iso Memory-in-use-until (+ before 6))
    (prn "F - 'new' on primitive arrays increments high-water mark by their size")))

(reset)
(new-trace "new-array-direct")
(add-fns
  '((main
      ((1 integer) <- copy (5 literal))
      ((2 type-array-address) <- new (type-array literal) (1 integer)))))
(let before Memory-in-use-until
  (run 'main)
;?   (prn memory*)
  (if (~iso memory*.2 before)
    (prn "F - 'new' on array with variable size returns current high-water mark"))
  (if (~iso Memory-in-use-until (+ before 6))
    (prn "F - 'new' on primitive arrays increments high-water mark by their (variable) size")))

; Even though our memory locations can now have names, the names are all
; globals, accessible from any function. To isolate functions from their
; callers we need local variables, and mu provides them using a special
; variable called default-scope. When you initialize such a variable (likely
; with a call to our just-defined memory allocator) mu interprets memory
; locations as offsets from its value. If default-scope is set to 1000, for
; example, reads and writes to memory location 1 will really go to 1001.
;
; 'default-scope' is itself hard-coded to be function-local; it's nil in a new
; function, and it's restored when functions return to their callers. But the
; actual scope allocation is independent. So you can define closures, or do
; even more funky things like share locals between two coroutines.

(reset)
(new-trace "set-default-scope")
(add-fns
  '((main
      ((default-scope scope-address) <- new (scope literal) (2 literal))
      ((1 integer) <- copy (23 literal)))))
(let before Memory-in-use-until
;?   (set dump-trace*)
  (run 'main)
;?   (prn memory*)
  (if (~and (~is 23 memory*.1)
            (is 23 (memory* (+ before 1))))
    (prn "F - default-scope implicitly modifies variable locations")))

(reset)
(new-trace "set-default-scope-skips-offset")
(add-fns
  '((main
      ((default-scope scope-address) <- new (scope literal) (2 literal))
      ((1 integer) <- copy (23 offset)))))
(let before Memory-in-use-until
;?   (set dump-trace*)
  (run 'main)
;?   (prn memory*)
  (if (~and (~is 23 memory*.1)
            (is 23 (memory* (+ before 1))))
    (prn "F - default-scope skips 'offset' types just like literals")))

(reset)
(new-trace "default-scope-bounds-check")
(add-fns
  '((main
      ((default-scope scope-address) <- new (scope literal) (2 literal))
      ((2 integer) <- copy (23 literal)))))
;? (set dump-trace*)
(run 'main)
;? (prn memory*)
(let routine (car completed-routines*)
  (if (no rep.routine!error)
    (prn "F - default-scope checks bounds")))

(reset)
(new-trace "default-scope-and-get-indirect")
(add-fns
  '((main
      ((default-scope scope-address) <- new (scope literal) (5 literal))
      ((1 integer-boolean-pair-address) <- new (integer-boolean-pair literal))
      ((2 integer-address) <- get-address (1 integer-boolean-pair-address deref) (0 offset))
      ((2 integer-address deref) <- copy (34 literal))
      ((3 integer global) <- get (1 integer-boolean-pair-address deref) (0 offset)))))
;? (= dump-trace* (obj blacklist '("sz" "m" "setm" "addr" "cvt0" "cvt1")))
(run 'main)
;? (prn memory*)
;? (prn completed-routines*)
(each routine completed-routines*
  (aif rep.routine!error (prn "error - " it)))
(if (~is 34 memory*.3)
  (prn "F - indirect 'get' works in the presence of default-scope"))
;? (quit)

(reset)
(new-trace "default-scope-and-index-indirect")
(add-fns
  '((main
      ((default-scope scope-address) <- new (scope literal) (5 literal))
      ((1 integer-array-address) <- new (integer-array literal) (4 literal))
      ((2 integer-address) <- index-address (1 integer-array-address deref) (2 offset))
      ((2 integer-address deref) <- copy (34 literal))
      ((3 integer global) <- index (1 integer-array-address deref) (2 offset)))))
;? (= dump-trace* (obj blacklist '("sz" "m" "setm" "addr" "cvt0" "cvt1")))
(run 'main)
;? (prn memory*)
;? (prn completed-routines*)
(each routine completed-routines*
  (aif rep.routine!error (prn "error - " it)))
(if (~is 34 memory*.3)
  (prn "F - indirect 'index' works in the presence of default-scope"))
;? (quit)

(reset)
;? (new-trace "convert-names-default-scope")
(if (~iso (convert-names
            '(((x integer) <- copy (4 literal))
              ((y integer) <- copy (2 literal))
              ; unsafe in general; don't write random values to 'default-scope'
              ((default-scope integer) <- add (x integer) (y integer))))
          '(((1 integer) <- copy (4 literal))
            ((2 integer) <- copy (2 literal))
            ((default-scope integer) <- add (1 integer) (2 integer))))
  (prn "F - convert-names never renames default-scope"))

(reset)
(new-trace "suppress-default-scope")
(add-fns
  '((main
      ((default-scope scope-address) <- new (scope literal) (2 literal))
      ((1 integer global) <- copy (23 literal)))))
(let before Memory-in-use-until
;?   (set dump-trace*)
  (run 'main)
;?   (prn memory*)
  (if (~and (is 23 memory*.1)
            (~is 23 (memory* (+ before 1))))
    (prn "F - default-scope skipped for locations with metadata 'global'")))

;; Dynamic dispatch
;
; Putting it all together, here's how you define generic functions that run
; different code based on the types of their args.

(reset)
(new-trace "dispatch-clause")
;? (set dump-trace*)
(add-fns
  '((test1
      ; doesn't matter too much how many locals you allocate space for (here 20)
      ; if it's slightly too many -- memory is plentiful
      ; if it's too few -- mu will raise an error
      ((default-scope scope-address) <- new (scope literal) (20 literal))
      ((first-arg-box tagged-value-address) <- arg)
      ; if given integers, add them
      { begin
        ((first-arg integer) (match? boolean) <- maybe-coerce (first-arg-box tagged-value-address deref) (integer literal))
        (break-unless (match? boolean))
        ((second-arg-box tagged-value-address) <- arg)
        ((second-arg integer) <- maybe-coerce (second-arg-box tagged-value-address deref) (integer literal))
        ((result integer) <- add (first-arg integer) (second-arg integer))
        (reply (result integer))
      }
      (reply (nil literal)))
    (main
      ((1 tagged-value-address) <- new-tagged-value (integer literal) (34 literal))
      ((2 tagged-value-address) <- new-tagged-value (integer literal) (3 literal))
      ((3 integer) <- test1 (1 tagged-value-address) (2 tagged-value-address)))))
(run 'main)
;? (prn memory*)
(if (~is memory*.3 37)
  (prn "F - an example function that checks that its oarg is an integer"))
;? (quit)

; todo - test that reply increments pc for caller frame after popping current frame

(reset)
(new-trace "dispatch-multiple-clauses")
;? (set dump-trace*)
(add-fns
  '((test1
      ((default-scope scope-address) <- new (scope literal) (20 literal))
      ((first-arg-box tagged-value-address) <- arg)
      ; if given integers, add them
      { begin
        ((first-arg integer) (match? boolean) <- maybe-coerce (first-arg-box tagged-value-address deref) (integer literal))
        (break-unless (match? boolean))
        ((second-arg-box tagged-value-address) <- arg)
        ((second-arg integer) <- maybe-coerce (second-arg-box tagged-value-address deref) (integer literal))
        ((result integer) <- add (first-arg integer) (second-arg integer))
        (reply (result integer))
      }
      ; if given booleans, or them (it's a silly kind of generic function)
      { begin
        ((first-arg boolean) (match? boolean) <- maybe-coerce (first-arg-box tagged-value-address deref) (boolean literal))
        (break-unless (match? boolean))
        ((second-arg-box tagged-value-address) <- arg)
        ((second-arg boolean) <- maybe-coerce (second-arg-box tagged-value-address deref) (boolean literal))
        ((result boolean) <- or (first-arg boolean) (second-arg boolean))
        (reply (result integer))
      }
      (reply (nil literal)))
    (main
      ((1 tagged-value-address) <- new-tagged-value (boolean literal) (t literal))
      ((2 tagged-value-address) <- new-tagged-value (boolean literal) (nil literal))
      ((3 boolean) <- test1 (1 tagged-value-address) (2 tagged-value-address)))))
;? (each stmt function*!test-fn
;?   (prn "  " stmt))
(run 'main)
;? (wipe dump-trace*)
;? (prn memory*)
(if (~is memory*.3 t)
  (prn "F - an example function that can do different things (dispatch) based on the type of its args or oargs"))
;? (quit)

(reset)
(new-trace "dispatch-multiple-calls")
(add-fns
  '((test1
      ((default-scope scope-address) <- new (scope literal) (20 literal))
      ((first-arg-box tagged-value-address) <- arg)
      ; if given integers, add them
      { begin
        ((first-arg integer) (match? boolean) <- maybe-coerce (first-arg-box tagged-value-address deref) (integer literal))
        (break-unless (match? boolean))
        ((second-arg-box tagged-value-address) <- arg)
        ((second-arg integer) <- maybe-coerce (second-arg-box tagged-value-address deref) (integer literal))
        ((result integer) <- add (first-arg integer) (second-arg integer))
        (reply (result integer))
      }
      ; if given booleans, or them (it's a silly kind of generic function)
      { begin
        ((first-arg boolean) (match? boolean) <- maybe-coerce (first-arg-box tagged-value-address deref) (boolean literal))
        (break-unless (match? boolean))
        ((second-arg-box tagged-value-address) <- arg)
        ((second-arg boolean) <- maybe-coerce (second-arg-box tagged-value-address deref) (boolean literal))
        ((result boolean) <- or (first-arg boolean) (second-arg boolean))
        (reply (result integer))
      }
      (reply (nil literal)))
    (main
      ((1 tagged-value-address) <- new-tagged-value (boolean literal) (t literal))
      ((2 tagged-value-address) <- new-tagged-value (boolean literal) (nil literal))
      ((3 boolean) <- test1 (1 tagged-value-address) (2 tagged-value-address))
      ((10 tagged-value-address) <- new-tagged-value (integer literal) (34 literal))
      ((11 tagged-value-address) <- new-tagged-value (integer literal) (3 literal))
      ((12 integer) <- test1 (10 tagged-value-address) (11 tagged-value-address)))))
(run 'main)
;? (prn memory*)
(if (~and (is memory*.3 t) (is memory*.12 37))
  (prn "F - different calls can exercise different clauses of the same function"))

;; Concurrency
;
; A rudimentary process scheduler. You can 'run' multiple functions at once,
; and they share the virtual processor.
;
; There's also a 'fork' primitive to let functions create new threads of
; execution (we call them routines).
;
; Eventually we want to allow callers to influence how much of their CPU they
; give to their 'children', or to rescind a child's running privileges.

(reset)
(new-trace "scheduler")
(add-fns
  '((f1
      ((1 integer) <- copy (3 literal)))
    (f2
      ((2 integer) <- copy (4 literal)))))
(run 'f1 'f2)
(when (~iso 2 curr-cycle*)
  (prn "F - scheduler didn't run the right number of instructions: " curr-cycle*))
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
(new-trace "scheduler-alternate")
(add-fns
  '((f1
      ((1 integer) <- copy (3 literal))
      ((1 integer) <- copy (3 literal)))
    (f2
      ((2 integer) <- copy (4 literal))
      ((2 integer) <- copy (4 literal)))))
(= scheduling-interval* 1)
(run 'f1 'f2)
(check-trace-contents "scheduler alternates between routines"
  '(("run" "f1 0")
    ("run" "f2 0")
    ("run" "f1 1")
    ("run" "f2 1")
  ))

(reset)
(new-trace "scheduler-sleep")
(add-fns
  '((f1
      ((1 integer) <- copy (3 literal)))
    (f2
      ((2 integer) <- copy (4 literal)))))
; add one baseline routine to run (empty running-routines* handled below)
(enq make-routine!f1 running-routines*)
(assert (is 1 len.running-routines*))
; sleeping routine
(let routine make-routine!f2
  (= rep.routine!sleep '(23 literal))
  (set sleeping-routines*.routine))
; not yet time for it to wake up
(= curr-cycle* 23)
;? (set dump-trace*)
;? (= dump-trace* (obj whitelist '("run" "schedule")))
(update-scheduler-state)
(if (~is 1 len.running-routines*)
  (prn "F - scheduler lets routines sleep"))

(reset)
(new-trace "scheduler-wakeup")
(add-fns
  '((f1
      ((1 integer) <- copy (3 literal)))
    (f2
      ((2 integer) <- copy (4 literal)))))
; add one baseline routine to run (empty running-routines* handled below)
(enq make-routine!f1 running-routines*)
(assert (is 1 len.running-routines*))
; sleeping routine
(let routine make-routine!f2
  (= rep.routine!sleep '(23 literal))
  (set sleeping-routines*.routine))
; time for it to wake up
(= curr-cycle* 24)
(update-scheduler-state)
(if (~is 2 len.running-routines*)
  (prn "F - scheduler wakes up sleeping routines at the right time"))

(reset)
(new-trace "scheduler-sleep-location")
(add-fns
  '((f1
      ((1 integer) <- copy (3 literal)))
    (f2
      ((2 integer) <- copy (4 literal)))))
; add one baseline routine to run (empty running-routines* handled below)
(enq make-routine!f1 running-routines*)
(assert (is 1 len.running-routines*))
; blocked routine
(let routine make-routine!f2
  (= rep.routine!sleep '(23 integer))
  (set sleeping-routines*.routine))
; 'empty' memory location
(= memory*.23 0)
;? (prn memory*)
;? (prn running-routines*)
;? (prn sleeping-routines*)
;? (set dump-trace*)
;? (= dump-trace* (obj whitelist '("run" "schedule")))
(update-scheduler-state)
;? (prn running-routines*)
;? (prn sleeping-routines*)
(if (~is 1 len.running-routines*)
  (prn "F - scheduler lets routines block on locations"))
;? (quit)

(reset)
(new-trace "scheduler-wakeup-location")
(add-fns
  '((f1
      ((1 integer) <- copy (3 literal)))
    (f2
      ((2 integer) <- copy (4 literal)))))
; add one baseline routine to run (empty running-routines* handled below)
(enq make-routine!f1 running-routines*)
(assert (is 1 len.running-routines*))
; blocked routine
(let routine make-routine!f2
  (= rep.routine!sleep '(23 integer))
  (set sleeping-routines*.routine))
; set memory location and unblock routine
(= memory*.23 1)
(update-scheduler-state)
(if (~is 2 len.running-routines*)
  (prn "F - scheduler unblocks routines blocked on locations"))

(reset)
(new-trace "scheduler-skip")
(add-fns
  '((f1
      ((1 integer) <- copy (3 literal)))))
; running-routines* is empty
(assert (empty running-routines*))
; sleeping routine
(let routine make-routine!f1
  (= rep.routine!sleep '(23 literal))
  (set sleeping-routines*.routine))
; long time left for it to wake up
(= curr-cycle* 0)
(update-scheduler-state)
(assert (is curr-cycle* 24))
(if (~is 1 len.running-routines*)
  (prn "F - scheduler skips ahead to earliest sleeping routines when nothing to run"))

(reset)
(new-trace "scheduler-deadlock")
(add-fns
  '((f1
      ((1 integer) <- copy (3 literal)))))
(assert (empty running-routines*))
(assert (empty completed-routines*))
; blocked routine
(let routine make-routine!f1
  (= rep.routine!sleep '(23 integer))
  (set sleeping-routines*.routine))
; location it's waiting on is 'empty'
(= memory*.23 0)
(update-scheduler-state)
(assert (~empty completed-routines*))
;? (prn completed-routines*)
(let routine completed-routines*.0
  (when (~posmatch "deadlock" rep.routine!error)
    (prn "F - scheduler detects deadlock")))
;? (quit)

(reset)
(new-trace "sleep")
(add-fns
  '((f1
      (sleep (1 literal))
      ((1 integer) <- copy (3 literal))
      ((1 integer) <- copy (3 literal)))
    (f2
      ((2 integer) <- copy (4 literal))
      ((2 integer) <- copy (4 literal)))))
;? (= dump-trace* (obj whitelist '("run" "schedule")))
(run 'f1 'f2)
(check-trace-contents "scheduler handles sleeping routines"
  '(("run" "f1 0")
    ("run" "sleeping until 2")
    ("schedule" "pushing f1 to sleep queue")
    ("run" "f2 0")
    ("run" "f2 1")
    ("schedule" "waking up f1")
    ("run" "f1 1")
    ("run" "f1 2")
  ))

(reset)
(new-trace "sleep-long")
(add-fns
  '((f1
      (sleep (20 literal))
      ((1 integer) <- copy (3 literal))
      ((1 integer) <- copy (3 literal)))
    (f2
      ((2 integer) <- copy (4 literal))
      ((2 integer) <- copy (4 literal)))))
;? (= dump-trace* (obj whitelist '("run" "schedule")))
(run 'f1 'f2)
(check-trace-contents "scheduler progresses sleeping routines when there are no routines left to run"
  '(("run" "f1 0")
    ("run" "sleeping until 21")
    ("schedule" "pushing f1 to sleep queue")
    ("run" "f2 0")
    ("run" "f2 1")
    ("schedule" "waking up f1")
    ("run" "f1 1")
    ("run" "f1 2")
  ))

(reset)
(new-trace "sleep-location")
(add-fns
  '((f1
      ; waits for memory location 1 to be set, before computing its successor
      ((1 integer) <- copy (0 literal))
      (sleep (1 integer))
      ((2 integer) <- add (1 integer) (1 literal)))
    (f2
      (sleep (30 literal))
      ((1 integer) <- copy (3 literal)))))  ; set to value
;? (= dump-trace* (obj whitelist '("run" "schedule")))
;? (set dump-trace*)
(run 'f1 'f2)
;? (prn int-canon.memory*)
(each routine completed-routines*
  (aif rep.routine!error (prn "error - " it)))
(if (~is memory*.2 4)  ; successor of value
  (prn "F - sleep can block on a memory location"))
;? (quit)

(reset)
(new-trace "sleep-scoped-location")
(add-fns
  '((f1
      ; waits for memory location 1 to be set, before computing its successor
      ((10 integer) <- copy (5 literal))
      ((default-scope scope-address) <- copy (10 literal))
      ((1 integer) <- copy (0 literal))  ; really location 11
      (sleep (1 integer))
      ((2 integer) <- add (1 integer) (1 literal)))
    (f2
      (sleep (30 literal))
      ((11 integer) <- copy (3 literal)))))  ; set to value
;? (= dump-trace* (obj whitelist '("run" "schedule")))
(run 'f1 'f2)
(if (~is memory*.12 4)  ; successor of value
  (prn "F - sleep can block on a scoped memory location"))
;? (quit)

(reset)
(new-trace "fork")
(add-fns
  '((f1
      (fork (f2 fn)))
    (f2
      ((2 integer) <- copy (4 literal)))))
(run 'f1)
(if (~iso memory*.2 4)
  (prn "F - fork works"))

(reset)
(new-trace "fork-with-args")
(add-fns
  '((f1
      (fork (f2 fn) (4 literal)))
    (f2
      ((2 integer) <- arg))))
(run 'f1)
(if (~iso memory*.2 4)
  (prn "F - fork can pass args"))

(reset)
(new-trace "fork-copies-args")
(add-fns
  '((f1
      ((default-scope scope-address) <- new (scope literal) (5 literal))
      ((x integer) <- copy (4 literal))
      (fork (f2 fn) (x integer))
      ((x integer) <- copy (0 literal)))  ; should be ignored
    (f2
      ((2 integer) <- arg))))
(run 'f1)
(if (~iso memory*.2 4)
  (prn "F - fork passes args by value"))

; The scheduler needs to keep track of the call stack for each routine.
; Eventually we'll want to save this information in mu's address space itself,
; along with the types array, the magic buffers for args and oargs, and so on.
;
; Eventually we want the right stack-management primitives to build delimited
; continuations in mu.

; Routines can throw errors.
(reset)
(new-trace "array-bounds-check")
(add-fns
  '((main
      ((1 integer) <- copy (2 literal))
      ((2 integer) <- copy (23 literal))
      ((3 integer) <- copy (24 literal))
      ((4 integer) <- index (1 integer-array) (2 literal)))))
;? (set dump-trace*)
(run 'main)
;? (prn memory*)
(let routine (car completed-routines*)
  (if (no rep.routine!error)
    (prn "F - 'index' throws an error if out of bounds")))

;; Synchronization
;
; Mu synchronizes using channels rather than locks, like Erlang and Go.
;
; The two ends of a channel will usually belong to different routines, but
; each end should only be used by a single one. Don't try to read from or
; write to it from multiple routines at once.
;
; To avoid locking, writer and reader will never write to the same location.
; So channels will include fields in pairs, one for the writer and one for the
; reader.

; The core circular buffer contains values at index 'first-full' up to (but
; not including) index 'first-empty'. The reader always modifies it at
; first-full, while the writer always modifies it at first-empty.
(reset)
(new-trace "channel-new")
(add-fns
  '((main
      ((1 channel-address) <- new-channel (3 literal))
      ((2 integer) <- get (1 channel-address deref) (first-full offset))
      ((3 integer) <- get (1 channel-address deref) (first-free offset)))))
;? (set dump-trace*)
(run 'main)
;? (prn memory*)
(if (or (~is 0 memory*.2)
        (~is 0 memory*.3))
  (prn "F - 'new-channel' initializes 'first-full and 'first-free to 0"))

(reset)
(new-trace "channel-write")
(add-fns
  '((main
      ((1 channel-address) <- new-channel (3 literal))
      ((2 integer-address) <- new (integer literal))
      ((2 integer-address deref) <- copy (34 literal))
      ((3 tagged-value-address) <- new-tagged-value (integer-address literal) (2 integer-address))
      ((1 channel-address deref) <- write (1 channel-address deref) (3 tagged-value-address deref))
      ((4 integer) <- get (1 channel-address deref) (first-full offset))
      ((5 integer) <- get (1 channel-address deref) (first-free offset)))))
;? (set dump-trace*)
;? (= dump-trace* (obj blacklist '("sz" "m" "setm" "addr" "array-len" "cvt0" "cvt1")))
;? (= dump-trace* (obj whitelist '("jump")))
(run 'main)
;? (prn canon.memory*)
(if (or (~is 0 memory*.4)
        (~is 1 memory*.5))
  (prn "F - 'write' enqueues item to channel"))
;? (quit)

(reset)
(new-trace "channel-read")
(add-fns
  '((main
      ((1 channel-address) <- new-channel (3 literal))
      ((2 integer-address) <- new (integer literal))
      ((2 integer-address deref) <- copy (34 literal))
      ((3 tagged-value-address) <- new-tagged-value (integer-address literal) (2 integer-address))
      ((1 channel-address deref) <- write (1 channel-address deref) (3 tagged-value-address deref))
      ((4 tagged-value) (1 channel-address deref) <- read (1 channel-address deref))
      ((6 integer-address) <- maybe-coerce (4 tagged-value) (integer-address literal))
      ((7 integer) <- get (1 channel-address deref) (first-full offset))
      ((8 integer) <- get (1 channel-address deref) (first-free offset)))))
;? (set dump-trace*)
;? (= dump-trace* (obj blacklist '("sz" "m" "setm" "addr" "array-len" "cvt0" "cvt1")))
(run 'main)
;? (prn int-canon.memory*)
(if (~is memory*.6 memory*.2)
  (prn "F - 'read' returns written value"))
(if (or (~is 1 memory*.7)
        (~is 1 memory*.8))
  (prn "F - 'read' dequeues item from channel"))

(reset)
(new-trace "channel-write-wrap")
(add-fns
  '((main
      ; channel with 1 slot
      ((1 channel-address) <- new-channel (1 literal))
      ; write a value
      ((2 integer-address) <- new (integer literal))
      ((2 integer-address deref) <- copy (34 literal))
      ((3 tagged-value-address) <- new-tagged-value (integer-address literal) (2 integer-address))
      ((1 channel-address deref) <- write (1 channel-address deref) (3 tagged-value-address deref))
      ; first-free will now be 1
      ((4 integer) <- get (1 channel-address deref) (first-free offset))
      ; read one value
      (_ (1 channel-address deref) <- read (1 channel-address deref))
      ; write a second value; verify that first-free wraps around to 0.
      ((1 channel-address deref) <- write (1 channel-address deref) (3 tagged-value-address deref))
      ((5 integer) <- get (1 channel-address deref) (first-free offset)))))
;? (set dump-trace*)
;? (= dump-trace* (obj blacklist '("sz" "m" "setm" "addr" "array-len" "cvt0" "cvt1")))
(run 'main)
;? (prn canon.memory*)
(if (or (~is 1 memory*.4)
        (~is 0 memory*.5))
  (prn "F - 'write' can wrap pointer back to start"))

(reset)
(new-trace "channel-read-wrap")
(add-fns
  '((main
      ; channel with 1 slot
      ((1 channel-address) <- new-channel (1 literal))
      ; write a value
      ((2 integer-address) <- new (integer literal))
      ((2 integer-address deref) <- copy (34 literal))
      ((3 tagged-value-address) <- new-tagged-value (integer-address literal) (2 integer-address))
      ((1 channel-address deref) <- write (1 channel-address deref) (3 tagged-value-address deref))
      ; read one value
      (_ (1 channel-address deref) <- read (1 channel-address deref))
      ; first-full will now be 1
      ((4 integer) <- get (1 channel-address deref) (first-full offset))
      ; write a second value
      ((1 channel-address deref) <- write (1 channel-address deref) (3 tagged-value-address deref))
      ; read second value; verify that first-full wraps around to 0.
      (_ (1 channel-address deref) <- read (1 channel-address deref))
      ((5 integer) <- get (1 channel-address deref) (first-full offset)))))
;? (set dump-trace*)
;? (= dump-trace* (obj blacklist '("sz" "m" "setm" "addr" "array-len" "cvt0" "cvt1")))
(run 'main)
;? (prn canon.memory*)
(if (or (~is 1 memory*.4)
        (~is 0 memory*.5))
  (prn "F - 'read' can wrap pointer back to start"))

(reset)
(new-trace "channel-new-empty-not-full")
(add-fns
  '((main
      ((1 channel-address) <- new-channel (3 literal))
      ((2 boolean) <- empty? (1 channel-address deref))
      ((3 boolean) <- full? (1 channel-address deref)))))
;? (set dump-trace*)
(run 'main)
;? (prn memory*)
(if (or (~is t memory*.2)
        (~is nil memory*.3))
  (prn "F - a new channel is always empty, never full"))

(reset)
(new-trace "channel-write-not-empty")
(add-fns
  '((main
      ((1 channel-address) <- new-channel (3 literal))
      ((2 integer-address) <- new (integer literal))
      ((2 integer-address deref) <- copy (34 literal))
      ((3 tagged-value-address) <- new-tagged-value (integer-address literal) (2 integer-address))
      ((1 channel-address deref) <- write (1 channel-address deref) (3 tagged-value-address deref))
      ((4 boolean) <- empty? (1 channel-address deref))
      ((5 boolean) <- full? (1 channel-address deref)))))
;? (set dump-trace*)
(run 'main)
;? (prn memory*)
(if (or (~is nil memory*.4)
        (~is nil memory*.5))
  (prn "F - a channel after writing is never empty"))

(reset)
(new-trace "channel-write-full")
(add-fns
  '((main
      ((1 channel-address) <- new-channel (1 literal))
      ((2 integer-address) <- new (integer literal))
      ((2 integer-address deref) <- copy (34 literal))
      ((3 tagged-value-address) <- new-tagged-value (integer-address literal) (2 integer-address))
      ((1 channel-address deref) <- write (1 channel-address deref) (3 tagged-value-address deref))
      ((4 boolean) <- empty? (1 channel-address deref))
      ((5 boolean) <- full? (1 channel-address deref)))))
;? (set dump-trace*)
(run 'main)
;? (prn memory*)
(if (or (~is nil memory*.4)
        (~is t memory*.5))
  (prn "F - a channel after writing may be full"))

(reset)
(new-trace "channel-read-not-full")
(add-fns
  '((main
      ((1 channel-address) <- new-channel (3 literal))
      ((2 integer-address) <- new (integer literal))
      ((2 integer-address deref) <- copy (34 literal))
      ((3 tagged-value-address) <- new-tagged-value (integer-address literal) (2 integer-address))
      ((1 channel-address deref) <- write (1 channel-address deref) (3 tagged-value-address deref))
      ((1 channel-address deref) <- write (1 channel-address deref) (3 tagged-value-address deref))
      (_ (1 channel-address deref) <- read (1 channel-address deref))
      ((4 boolean) <- empty? (1 channel-address deref))
      ((5 boolean) <- full? (1 channel-address deref)))))
;? (set dump-trace*)
(run 'main)
;? (prn memory*)
(if (or (~is nil memory*.4)
        (~is nil memory*.5))
  (prn "F - a channel after reading is never full"))

(reset)
(new-trace "channel-read-empty")
(add-fns
  '((main
      ((1 channel-address) <- new-channel (3 literal))
      ((2 integer-address) <- new (integer literal))
      ((2 integer-address deref) <- copy (34 literal))
      ((3 tagged-value-address) <- new-tagged-value (integer-address literal) (2 integer-address))
      ((1 channel-address deref) <- write (1 channel-address deref) (3 tagged-value-address deref))
      (_ (1 channel-address deref) <- read (1 channel-address deref))
      ((4 boolean) <- empty? (1 channel-address deref))
      ((5 boolean) <- full? (1 channel-address deref)))))
;? (set dump-trace*)
(run 'main)
;? (prn memory*)
(if (or (~is t memory*.4)
        (~is nil memory*.5))
  (prn "F - a channel after reading may be empty"))

; The key property of channels; writing to a full channel blocks the current
; routine until it creates space. Ditto reading from an empty channel.

(reset)
(new-trace "channel-read-block")
(add-fns
  '((main
      ((1 channel-address) <- new-channel (3 literal))
      ; channel is empty, but receives a read
      ((2 tagged-value) (1 channel-address deref) <- read (1 channel-address deref)))))
;? (set dump-trace*)
;? (= dump-trace* (obj whitelist '("run")))
(run 'main)
;? (prn int-canon.memory*)
;? (prn sleeping-routines*)
;? (prn completed-routines*)
; read should cause the routine to sleep, and
; the sole sleeping routine should trigger the deadlock detector
(let routine (car completed-routines*)
  (when (or (no routine)
            (no rep.routine!error)
            (~posmatch "deadlock" rep.routine!error))
    (prn "F - 'read' on empty channel blocks (puts the routine to sleep until the channel gets data)")))
;? (quit)

(reset)
(new-trace "channel-write-block")
(add-fns
  '((main
      ((1 channel-address) <- new-channel (1 literal))
      ((2 integer-address) <- new (integer literal))
      ((2 integer-address deref) <- copy (34 literal))
      ((3 tagged-value-address) <- new-tagged-value (integer-address literal) (2 integer-address))
      ((1 channel-address deref) <- write (1 channel-address deref) (3 tagged-value-address deref))
      ; channel has capacity 1, but receives a second write
      ((1 channel-address deref) <- write (1 channel-address deref) (3 tagged-value-address deref)))))
;? (set dump-trace*)
;? (= dump-trace* (obj whitelist '("run" "schedule" "addr")))
(run 'main)
;? (prn int-canon.memory*)
;? (prn running-routines*)
;? (prn sleeping-routines*)
;? (prn completed-routines*)
; second write should cause the routine to sleep, and
; the sole sleeping routine should trigger the deadlock detector
(let routine (car completed-routines*)
  (when (or (no routine)
            (no rep.routine!error)
            (~posmatch "deadlock" rep.routine!error))
    (prn "F - 'write' on full channel blocks (puts the routine to sleep until the channel gets data)")))
;? (quit)

; But how will the sleeping routines wake up? Our scheduler can't watch for
; changes to arbitrary values, just tell us if a specific raw location becomes
; non-zero (see the sleep-location test above). So both reader and writer set
; 'read-watch' and 'write-watch' respectively at the end of a successful call.

(reset)
(new-trace "channel-write-watch")
(add-fns
  '((main
      ((1 channel-address) <- new-channel (3 literal))
      ((2 integer-address) <- new (integer literal))
      ((2 integer-address deref) <- copy (34 literal))
      ((3 tagged-value-address) <- new-tagged-value (integer-address literal) (2 integer-address))
      ((4 boolean) <- get (1 channel-address deref) (read-watch offset))
      ((1 channel-address deref) <- write (1 channel-address deref) (3 tagged-value-address deref))
      ((5 boolean) <- get (1 channel-address deref) (write-watch offset)))))
(run 'main)
(if (or (~is nil memory*.4)
        (~is t memory*.5))
  (prn "F - 'write' sets channel watch"))

(reset)
(new-trace "channel-read-watch")
(add-fns
  '((main
      ((1 channel-address) <- new-channel (3 literal))
      ((2 integer-address) <- new (integer literal))
      ((2 integer-address deref) <- copy (34 literal))
      ((3 tagged-value-address) <- new-tagged-value (integer-address literal) (2 integer-address))
      ((1 channel-address deref) <- write (1 channel-address deref) (3 tagged-value-address deref))
      ((4 boolean) <- get (1 channel-address deref) (read-watch offset))
      (_ (1 channel-address deref) <- read (1 channel-address deref))
      ((5 integer) <- get (1 channel-address deref) (read-watch offset)))))
(run 'main)
(if (or (~is nil memory*.4)
        (~is t memory*.5))
  (prn "F - 'read' sets channel watch"))

(reset)
(new-trace "channel-handoff")
(add-fns
  '((f1
      ((default-scope scope-address) <- new (scope literal) (30 literal))
      ((chan channel-address) <- new-channel (3 literal))
      (fork (f2 fn) (chan channel-address))
      ((1 integer global) <- read (chan channel-address deref)))
    (f2
      ((default-scope scope-address) <- new (scope literal) (30 literal))
      ((n integer-address) <- new (integer literal))
      ((n integer-address deref) <- copy (24 literal))
      ((ochan channel-address) <- arg)
      ((x tagged-value-address) <- new-tagged-value (integer-address literal) (n integer-address))
      ((ochan channel-address deref) <- write (ochan channel-address deref) (x tagged-value-address deref)))))
(set dump-trace*)
;? (= dump-trace* (obj whitelist '("schedule" "run" "addr")))
;? (= dump-trace* (obj whitelist '("-")))
(run 'f1)
;? (prn memory*)
(each routine completed-routines*
  (aif rep.routine!error (prn "error - " it)))
(if (~is 24 memory*.1)
  (prn "F - channels are meant to be shared between routines"))
;? (quit)

;? (reset)
;? (new-trace "channel-race")
;? (add-fns
;?   '((reader
;?       ((

;; Separating concerns
;
; Lightweight tools can also operate on quoted lists of statements surrounded
; by square brackets. In the example below, we mimic Go's 'defer' keyword
; using 'convert-quotes'. It lets us write code anywhere in a function, but
; have it run just before the function exits. Great for keeping code to
; reclaim memory or other resources close to the code to allocate it. (C++
; programmers know this as RAII.) We'll use 'defer' when we build a memory
; deallocation routine like C's 'free'.
;
; More powerful reorderings are also possible like in Literate Programming or
; Aspect-Oriented Programming; one advantage of prohibiting arbitrarily nested
; code is that we can naturally name 'join points' wherever we want.

(reset)
;? (new-trace "convert-quotes-defer")
(if (~iso (convert-quotes
            '(((1 integer) <- copy (4 literal))
              (defer [
                       ((3 integer) <- copy (6 literal))
                     ])
              ((2 integer) <- copy (5 literal))))
          '(((1 integer) <- copy (4 literal))
            ((2 integer) <- copy (5 literal))
            ((3 integer) <- copy (6 literal))))
  (prn "F - convert-quotes can handle 'defer'"))

(reset)  ; end file with this to persist the trace for the final test
