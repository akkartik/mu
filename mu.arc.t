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

(selective-load "mu.arc" section-level)
;? (quit)

(section 20

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
; In our tests we'll define such mu functions using a call to 'add-code', so
; look for it. Everything outside 'add-code' is just test-harness details.

(reset)
;? (set dump-trace*)
(new-trace "literal")
(add-code
  '((function main [
      ((1 integer) <- copy (23 literal))
     ])))
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
(add-code
  '((function main [
      ((1 integer) <- copy (1 literal))
      ((2 integer) <- copy (3 literal))
      ((3 integer) <- add (1 integer) (2 integer))
     ])))
(run 'main)
(if (~iso memory* (obj 1 1  2 3  3 4))
  (prn "F - 'add' operates on two addresses"))

(reset)
(new-trace "add-literal")
(add-code
  '((function main [
      ((1 integer) <- add (2 literal) (3 literal))
     ])))
(run 'main)
(if (~is memory*.1 5)
  (prn "F - ops can take 'literal' operands (but not return them)"))

(reset)
(new-trace "sub-literal")
(add-code
  '((function main [
      ((1 integer) <- subtract (1 literal) (3 literal))
     ])))
(run 'main)
;? (prn memory*)
(if (~is memory*.1 -2)
  (prn "F - 'subtract'"))

(reset)
(new-trace "mul-literal")
(add-code
  '((function main [
      ((1 integer) <- multiply (2 literal) (3 literal))
     ])))
(run 'main)
;? (prn memory*)
(if (~is memory*.1 6)
  (prn "F - 'multiply'"))

(reset)
(new-trace "div-literal")
(add-code
  '((function main [
      ((1 integer) <- divide (8 literal) (3 literal))
     ])))
(run 'main)
;? (prn memory*)
(if (~is memory*.1 (/ real.8 3))
  (prn "F - 'divide'"))

(reset)
(new-trace "idiv-literal")
(add-code
  '((function main [
      ((1 integer) (2 integer) <- divide-with-remainder (23 literal) (6 literal))
     ])))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 3  2 5))
  (prn "F - 'divide-with-remainder' performs integer division"))

(reset)
(new-trace "dummy-oarg")
;? (set dump-trace*)
(add-code
  '((function main [
      (_ (2 integer) <- divide-with-remainder (23 literal) (6 literal))
     ])))
(run 'main)
(if (~iso memory* (obj 2 5))
  (prn "F - '_' oarg can ignore some results"))
;? (quit)

; Basic boolean operations: and, or, not
; There are easy ways to encode booleans in binary, but we'll skip past those
; details for now.

(reset)
(new-trace "and-literal")
(add-code
  '((function main [
      ((1 boolean) <- and (t literal) (nil literal))
     ])))
(run 'main)
;? (prn memory*)
(if (~is memory*.1 nil)
  (prn "F - logical 'and' for booleans"))

; Basic comparison operations

(reset)
(new-trace "lt-literal")
(add-code
  '((function main [
      ((1 boolean) <- less-than (4 literal) (3 literal))
     ])))
(run 'main)
;? (prn memory*)
(if (~is memory*.1 nil)
  (prn "F - 'less-than' inequality operator"))

(reset)
(new-trace "le-literal-false")
(add-code
  '((function main [
      ((1 boolean) <- lesser-or-equal (4 literal) (3 literal))
     ])))
(run 'main)
;? (prn memory*)
(if (~is memory*.1 nil)
  (prn "F - 'lesser-or-equal'"))

(reset)
(new-trace "le-literal-true")
(add-code
  '((function main [
      ((1 boolean) <- lesser-or-equal (4 literal) (4 literal))
     ])))
(run 'main)
;? (prn memory*)
(if (~is memory*.1 t)
  (prn "F - 'lesser-or-equal' returns true for equal operands"))

(reset)
(new-trace "le-literal-true-2")
(add-code
  '((function main [
      ((1 boolean) <- lesser-or-equal (4 literal) (5 literal))
     ])))
(run 'main)
;? (prn memory*)
(if (~is memory*.1 t)
  (prn "F - 'lesser-or-equal' - 2"))

; Control flow operations: jump, jump-if, jump-unless
; These introduce a new type -- 'offset' -- for literals that refer to memory
; locations relative to the current location.

(reset)
(new-trace "jump-skip")
(add-code
  '((function main [
      ((1 integer) <- copy (8 literal))
      (jump (1 offset))
      ((2 integer) <- copy (3 literal))  ; should be skipped
      (reply)
     ])))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 8))
  (prn "F - 'jump' skips some instructions"))

(reset)
(new-trace "jump-target")
(add-code
  '((function main [
      ((1 integer) <- copy (8 literal))
      (jump (1 offset))
      ((2 integer) <- copy (3 literal))  ; should be skipped
      (reply)
      ((3 integer) <- copy (34 literal))
     ])))  ; never reached
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 8))
  (prn "F - 'jump' doesn't skip too many instructions"))
;? (quit)

(reset)
(new-trace "jump-if-skip")
(add-code
  '((function main [
      ((2 integer) <- copy (1 literal))
      ((1 boolean) <- equal (1 literal) (2 integer))
      (jump-if (1 boolean) (1 offset))
      ((2 integer) <- copy (3 literal))
      (reply)
      ((3 integer) <- copy (34 literal))
     ])))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 t  2 1))
  (prn "F - 'jump-if' is a conditional 'jump'"))

(reset)
(new-trace "jump-if-fallthrough")
(add-code
  '((function main [
      ((1 boolean) <- equal (1 literal) (2 literal))
      (jump-if (3 boolean) (1 offset))
      ((2 integer) <- copy (3 literal))
      (reply)
      ((3 integer) <- copy (34 literal))
     ])))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 nil  2 3))
  (prn "F - if 'jump-if's first arg is false, it doesn't skip any instructions"))

(reset)
(new-trace "jump-if-backward")
(add-code
  '((function main [
      ((1 integer) <- copy (2 literal))
      ((2 integer) <- copy (1 literal))
      ; loop
      ((2 integer) <- add (2 integer) (2 integer))
      ((3 boolean) <- equal (1 integer) (2 integer))
      (jump-if (3 boolean) (-3 offset))  ; to loop
      ((4 integer) <- copy (3 literal))
      (reply)
      ((3 integer) <- copy (34 literal))
     ])))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 2  2 4  3 nil  4 3))
  (prn "F - 'jump-if' can take a negative offset to make backward jumps"))

(reset)
(new-trace "jump-label")
(add-code
  '((function main [
      ((1 integer) <- copy (2 literal))
      ((2 integer) <- copy (1 literal))
      loop
      ((2 integer) <- add (2 integer) (2 integer))
      ((3 boolean) <- equal (1 integer) (2 integer))
      (jump-if (3 boolean) (loop offset))
      ((4 integer) <- copy (3 literal))
      (reply)
      ((3 integer) <- copy (34 literal))
     ])))
;? (set dump-trace*)
;? (= dump-trace* (obj whitelist '("-")))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 2  2 4  3 nil  4 3))
  (prn "F - 'jump-if' can take a negative offset to make backward jumps"))

; Data movement relies on addressing modes:
;   'direct' - refers to a memory location; default for most types.
;   'literal' - directly encoded in the code; implicit for some types like 'offset'.

(reset)
(new-trace "direct-addressing")
(add-code
  '((function main [
      ((1 integer) <- copy (34 literal))
      ((2 integer) <- copy (1 integer))
     ])))
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
(add-code
  '((function main [
      ((1 integer-address) <- copy (2 literal))  ; unsafe; can't do this in general
      ((2 integer) <- copy (34 literal))
      ((3 integer) <- copy (1 integer-address deref))
     ])))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 2  2 34  3 34))
  (prn "F - 'copy' performs indirect addressing"))

; Output args can use indirect addressing. In the test below the value is
; stored at the location stored in location 1 (i.e. location 2).

(reset)
(new-trace "indirect-addressing-oarg")
(add-code
  '((function main [
      ((1 integer-address) <- copy (2 literal))
      ((2 integer) <- copy (34 literal))
      ((1 integer-address deref) <- add (2 integer) (2 literal))
     ])))
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
(add-code
  '((function main [
      ((1 integer) <- copy (34 literal))
      ((2 boolean) <- copy (nil literal))
      ((3 boolean) <- get (1 integer-boolean-pair) (1 offset))
      ((4 integer) <- get (1 integer-boolean-pair) (0 offset))
     ])))
;? (set dump-trace*)
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 34  2 nil  3 nil  4 34))
  (prn "F - 'get' accesses fields of records"))

(reset)
(new-trace "get-indirect")
(add-code
  '((function main [
      ((1 integer) <- copy (34 literal))
      ((2 boolean) <- copy (nil literal))
      ((3 integer-boolean-pair-address) <- copy (1 literal))
      ((4 boolean) <- get (3 integer-boolean-pair-address deref) (1 offset))
      ((5 integer) <- get (3 integer-boolean-pair-address deref) (0 offset))
     ])))
;? (set dump-trace*)
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 34  2 nil  3 1  4 nil  5 34))
  (prn "F - 'get' accesses fields of record address"))

(reset)
(new-trace "get-indirect-repeated")
(add-code
  '((function main [
      ((1 integer) <- copy (34 literal))
      ((2 integer) <- copy (35 literal))
      ((3 integer) <- copy (36 literal))
      ((4 integer-point-pair-address) <- copy (1 literal))  ; unsafe
      ((5 integer-point-pair-address-address) <- copy (4 literal))  ; unsafe
      ((6 integer-integer-pair) <- get (5 integer-point-pair-address-address deref deref) (1 offset))
      ((8 integer) <- get (5 integer-point-pair-address-address deref deref) (0 offset))
     ])))
(run 'main)
(if (~memory-contains 6 '(35 36 34))
  (prn "F - 'get' can deref multiple times"))
;? (quit)

(reset)
(new-trace "get-compound-field")
(add-code
  '((function main [
      ((1 integer) <- copy (34 literal))
      ((2 integer) <- copy (35 literal))
      ((3 integer) <- copy (36 literal))
      ((4 integer-integer-pair) <- get (1 integer-point-pair) (1 offset))
     ])))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 34  2 35  3 36  4 35  5 36))
  (prn "F - 'get' accesses fields spanning multiple locations"))

(reset)
(new-trace "get-address")
(add-code
  '((function main [
      ((1 integer) <- copy (34 literal))
      ((2 boolean) <- copy (t literal))
      ((3 boolean-address) <- get-address (1 integer-boolean-pair) (1 offset))
     ])))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 34  2 t  3 2))
  (prn "F - 'get-address' returns address of fields of records"))

(reset)
(new-trace "get-address-indirect")
(add-code
  '((function main [
      ((1 integer) <- copy (34 literal))
      ((2 boolean) <- copy (t literal))
      ((3 integer-boolean-pair-address) <- copy (1 literal))
      ((4 boolean-address) <- get-address (3 integer-boolean-pair-address deref) (1 offset))
     ])))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 34  2 t  3 1  4 2))
  (prn "F - 'get-address' accesses fields of record address"))

(reset)
(new-trace "index-literal")
(add-code
  '((function main [
      ((1 integer) <- copy (2 literal))
      ((2 integer) <- copy (23 literal))
      ((3 boolean) <- copy (nil literal))
      ((4 integer) <- copy (24 literal))
      ((5 boolean) <- copy (t literal))
      ((6 integer-boolean-pair) <- index (1 integer-boolean-pair-array) (1 literal))
     ])))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 2  2 23 3 nil  4 24 5 t  6 24 7 t))
  (prn "F - 'index' accesses indices of arrays"))
;? (quit)

(reset)
(new-trace "index-direct")
(add-code
  '((function main [
      ((1 integer) <- copy (2 literal))
      ((2 integer) <- copy (23 literal))
      ((3 boolean) <- copy (nil literal))
      ((4 integer) <- copy (24 literal))
      ((5 boolean) <- copy (t literal))
      ((6 integer) <- copy (1 literal))
      ((7 integer-boolean-pair) <- index (1 integer-boolean-pair-array) (6 integer))
     ])))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 2  2 23 3 nil  4 24 5 t  6 1  7 24 8 t))
  (prn "F - 'index' accesses indices of arrays"))
;? (quit)

(reset)
(new-trace "index-indirect")
(add-code
  '((function main [
      ((1 integer) <- copy (2 literal))
      ((2 integer) <- copy (23 literal))
      ((3 boolean) <- copy (nil literal))
      ((4 integer) <- copy (24 literal))
      ((5 boolean) <- copy (t literal))
      ((6 integer) <- copy (1 literal))
      ((7 integer-boolean-pair-array-address) <- copy (1 literal))
      ((8 integer-boolean-pair) <- index (7 integer-boolean-pair-array-address deref) (6 integer))
     ])))
;? (= dump-trace* (obj blacklist '("sz" "m" "setm" "addr" "cvt0" "cvt1")))
;? (set dump-trace*)
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 2  2 23 3 nil  4 24 5 t  6 1  7 1  8 24 9 t))
  (prn "F - 'index' accesses indices of array address"))
;? (quit)

(reset)
(new-trace "index-indirect-multiple")
(add-code
  '((function main [
      ((1 integer) <- copy (4 literal))
      ((2 integer) <- copy (23 literal))
      ((3 integer) <- copy (24 literal))
      ((4 integer) <- copy (25 literal))
      ((5 integer) <- copy (26 literal))
      ((6 integer-array-address) <- copy (1 literal))  ; unsafe
      ((7 integer-array-address-address) <- copy (6 literal))  ; unsafe
      ((8 integer) <- index (7 integer-array-address-address deref deref) (1 literal))
     ])))
(run 'main)
(if (~is memory*.8 24)
  (prn "F - 'index' can deref multiple times"))

(reset)
(new-trace "index-address")
(add-code
  '((function main [
      ((1 integer) <- copy (2 literal))
      ((2 integer) <- copy (23 literal))
      ((3 boolean) <- copy (nil literal))
      ((4 integer) <- copy (24 literal))
      ((5 boolean) <- copy (t literal))
      ((6 integer) <- copy (1 literal))
      ((7 integer-boolean-pair-address) <- index-address (1 integer-boolean-pair-array) (6 integer))
     ])))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 2  2 23 3 nil  4 24 5 t  6 1  7 4))
  (prn "F - 'index-address' returns addresses of indices of arrays"))

(reset)
(new-trace "index-address-indirect")
(add-code
  '((function main [
      ((1 integer) <- copy (2 literal))
      ((2 integer) <- copy (23 literal))
      ((3 boolean) <- copy (nil literal))
      ((4 integer) <- copy (24 literal))
      ((5 boolean) <- copy (t literal))
      ((6 integer) <- copy (1 literal))
      ((7 integer-boolean-pair-array-address) <- copy (1 literal))
      ((8 integer-boolean-pair-address) <- index-address (7 integer-boolean-pair-array-address deref) (6 integer))
     ])))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 2  2 23 3 nil  4 24 5 t  6 1  7 1  8 4))
  (prn "F - 'index-address' returns addresses of indices of array addresses"))

; Array values know their length. Record lengths are saved in the types table.

(reset)
(new-trace "len-array")
(add-code
  '((function main [
      ((1 integer) <- copy (2 literal))
      ((2 integer) <- copy (23 literal))
      ((3 boolean) <- copy (nil literal))
      ((4 integer) <- copy (24 literal))
      ((5 boolean) <- copy (t literal))
      ((6 integer) <- length (1 integer-boolean-pair-array))
     ])))
(run 'main)
;? (prn memory*)
(if (~is memory*.6 2)
  (prn "F - 'length' of array"))

(reset)
(new-trace "len-array-indirect")
(add-code
  '((function main [
      ((1 integer) <- copy (2 literal))
      ((2 integer) <- copy (23 literal))
      ((3 boolean) <- copy (nil literal))
      ((4 integer) <- copy (24 literal))
      ((5 boolean) <- copy (t literal))
      ((6 integer-address) <- copy (1 literal))
      ((7 integer) <- length (6 integer-boolean-pair-array-address deref))
     ])))
;? (set dump-trace*)
;? (= dump-trace* (obj blacklist '("sz" "m" "setm" "addr" "cvt0" "cvt1")))
(run 'main)
;? (prn memory*)
(if (~is memory*.7 2)
  (prn "F - 'length' of array address"))

; 'sizeof' is a helper to determine the amount of memory required by a type.
; Only for non-arrays.

(reset)
(new-trace "sizeof-record")
(add-code
  '((function main [
      ((1 integer) <- sizeof (integer-boolean-pair literal))
     ])))
(run 'main)
;? (prn memory*)
(if (~is memory*.1 2)
  (prn "F - 'sizeof' returns space required by arg"))

(reset)
(new-trace "sizeof-record-not-len")
(add-code
  '((function main [
      ((1 integer) <- sizeof (integer-point-pair literal))
     ])))
(run 'main)
;? (prn memory*)
(if (is memory*.1 2)
  (prn "F - 'sizeof' is different from number of elems"))

; Regardless of a type's length, you can move it around just like a primitive.

(reset)
(new-trace "copy-record")
(add-code
  '((function main [
      ((1 integer) <- copy (34 literal))
      ((2 boolean) <- copy (nil literal))
      ((4 boolean) <- copy (t literal))
      ((3 integer-boolean-pair) <- copy (1 integer-boolean-pair))
     ])))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 34  2 nil  3 34  4 nil))
  (prn "F - ops can operate on records spanning multiple locations"))

(reset)
(new-trace "copy-record2")
(add-code
  '((function main [
      ((1 integer) <- copy (34 literal))
      ((2 integer) <- copy (35 literal))
      ((3 integer) <- copy (36 literal))
      ((4 integer) <- copy (0 literal))
      ((5 integer) <- copy (0 literal))
      ((6 integer) <- copy (0 literal))
      ((4 integer-point-pair) <- copy (1 integer-point-pair))
     ])))
;? (= dump-trace* (obj whitelist '("run" "sizeof")))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 34  2 35  3 36
                       ; result
                       4 34  5 35  6 36))
  (prn "F - ops can operate on records with fields spanning multiple locations"))

)  ; section 20

(section 100

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
(add-code
  '((function main [
      ((1 type) <- copy (integer-address literal))
      ((2 integer-address) <- copy (34 literal))  ; pointer to nowhere
      ((3 integer-address) (4 boolean) <- maybe-coerce (1 tagged-value) (integer-address literal))
     ])))
;? (set dump-trace*)
(run 'main)
;? (prn memory*)
;? (prn completed-routines*)
(each routine completed-routines*
  (aif rep.routine!error (prn "error - " it)))
(if (~memory-contains 3 '(34 t))
  (prn "F - 'maybe-coerce' copies value only if type tag matches"))
;? (quit)

(reset)
(new-trace "tagged-value-2")
;? (set dump-trace*)
(add-code
  '((function main [
      ((1 type) <- copy (integer-address literal))
      ((2 integer-address) <- copy (34 literal))  ; pointer to nowhere
      ((3 integer-address) (4 boolean) <- maybe-coerce (1 tagged-value) (boolean-address literal))
     ])))
(run 'main)
;? (prn memory*)
(if (~memory-contains 3 '(0 nil))
  (prn "F - 'maybe-coerce' doesn't copy value when type tag doesn't match"))

(reset)
(new-trace "save-type")
(add-code
  '((function main [
      ((1 integer-address) <- copy (34 literal))  ; pointer to nowhere
      ((2 tagged-value) <- save-type (1 integer-address))
     ])))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj  1 34  2 'integer-address  3 34))
  (prn "F - 'save-type' saves the type of a value at runtime, turning it into a tagged-value"))

(reset)
(new-trace "new-tagged-value")
(add-code
  '((function main [
      ((1 integer-address) <- copy (34 literal))  ; pointer to nowhere
      ((2 tagged-value-address) <- new-tagged-value (integer-address literal) (1 integer-address))
      ((3 integer-address) (4 boolean) <- maybe-coerce (2 tagged-value-address deref) (integer-address literal))
     ])))
;? (= dump-trace* (obj blacklist '("sz" "m" "setm" "addr" "cvt0" "cvt1" "sizeof")))
(run 'main)
;? (prn memory*)
(if (~memory-contains 3 '(34 t))
  (prn "F - 'new-tagged-value' is the converse of 'maybe-coerce'"))
;? (quit)

; Now that we can record types for values we can construct a dynamically typed
; list.

(reset)
(new-trace "list")
;? (set dump-trace*)
(add-code
  '((function main [
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
     ])))
(let routine make-routine!main
  (enq routine running-routines*)
  (let first rep.routine!alloc
    (run)
;?     (prn memory*)
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
      (prn "F - lists can contain elements of different types"))))
(add-code
  '((function test2 [
      ((10 list-address) <- list-next (1 list-address))
     ])))
(run 'test2)
;? (prn memory*)
(if (~is memory*.10 memory*.6)
  (prn "F - 'list-next can move a list pointer to the next node"))

; 'new-list' takes a variable number of args and constructs a list containing
; them.

(reset)
(new-trace "new-list")
(add-code
  '((function main [
      ((1 integer) <- new-list (3 literal) (4 literal) (5 literal))
     ])))
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

)  ; section 100

(section 20

;; Functions
;
; Just like the table of types is centralized, functions are conceptualized as
; a centralized table of operations just like the "primitives" we've seen so
; far. If you create a function you can call it like any other op.

(reset)
(new-trace "new-fn")
(add-code
  '((function test1 [
      ((3 integer) <- add (1 integer) (2 integer))
     ])
    (function main [
      ((1 integer) <- copy (1 literal))
      ((2 integer) <- copy (3 literal))
      (test1)
     ])))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 1  2 3  3 4))
  (prn "F - calling a user-defined function runs its instructions"))
;? (quit)

(reset)
(new-trace "new-fn-once")
(add-code
  '((function test1 [
      ((1 integer) <- copy (1 literal))
     ])
    (function main [
      (test1)
     ])))
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
(add-code
  '((function test1 [
      ((3 integer) <- add (1 integer) (2 integer))
      (reply)
      ((4 integer) <- copy (34 literal))
     ])
    (function main [
      ((1 integer) <- copy (1 literal))
      ((2 integer) <- copy (3 literal))
      (test1)
     ])))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 1  2 3  3 4))
  (prn "F - 'reply' stops executing the current function"))
;? (quit)

(reset)
(new-trace "new-fn-reply-nested")
(add-code
  '((function test1 [
      ((3 integer) <- test2)
     ])
    (function test2 [
      (reply (2 integer))
     ])
    (function main [
      ((2 integer) <- copy (34 literal))
      (test1)
     ])))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 2 34  3 34))
  (prn "F - 'reply' stops executing any callers as necessary"))
;? (quit)

(reset)
(new-trace "new-fn-reply-once")
(add-code
  '((function test1 [
      ((3 integer) <- add (1 integer) (2 integer))
      (reply)
      ((4 integer) <- copy (34 literal))
     ])
    (function main [
      ((1 integer) <- copy (1 literal))
      ((2 integer) <- copy (3 literal))
      (test1)
     ])))
;? (= dump-trace* (obj whitelist '("run")))
(run 'main)
(if (~is 5 curr-cycle*)
  (prn "F - 'reply' executes instructions exactly once " curr-cycle*))
;? (quit)

(reset)
(new-trace "new-fn-arg-sequential")
(add-code
  '((function test1 [
      ((4 integer) <- next-input)
      ((5 integer) <- next-input)
      ((3 integer) <- add (4 integer) (5 integer))
      (reply)
      ((4 integer) <- copy (34 literal))
     ])
    (function main [
      ((1 integer) <- copy (1 literal))
      ((2 integer) <- copy (3 literal))
      (test1 (1 integer) (2 integer))
     ])))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 1  2 3  3 4
                       ; test1's temporaries
                       4 1  5 3))
  (prn "F - 'arg' accesses in order the operands of the most recent function call (the caller)"))
;? (quit)

(reset)
(new-trace "new-fn-arg-random-access")
;? (set dump-trace*)
(add-code
  '((function test1 [
      ((5 integer) <- input (1 literal))
      ((4 integer) <- input (0 literal))
      ((3 integer) <- add (4 integer) (5 integer))
      (reply)
      ((4 integer) <- copy (34 literal))  ; should never run
     ])
    (function main [
      ((1 integer) <- copy (1 literal))
      ((2 integer) <- copy (3 literal))
      (test1 (1 integer) (2 integer))
     ])))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 1  2 3  3 4
                       ; test's temporaries
                       4 1  5 3))
  (prn "F - 'arg' with index can access function call arguments out of order"))
;? (quit)

(reset)
(new-trace "new-fn-arg-random-then-sequential")
;? (set dump-trace*)
(add-code
  '((function test1 [
      (_ <- input (1 literal))
      ((1 integer) <- next-input)  ; takes next arg after index 1
     ])  ; should never run
    (function main [
      (test1 (1 literal) (2 literal) (3 literal))
     ])))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 3))
  (prn "F - 'arg' with index resets index for later calls"))
;? (quit)

(reset)
(new-trace "new-fn-arg-status")
(add-code
  '((function test1 [
      ((4 integer) (5 boolean) <- next-input)
     ])
    (function main [
      (test1 (1 literal))
     ])))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 4 1  5 t))
  (prn "F - 'arg' sets a second oarg when arg exists"))
;? (quit)

(reset)
(new-trace "new-fn-arg-missing")
(add-code
  '((function test1 [
      ((4 integer) <- next-input)
      ((5 integer) <- next-input)
     ])
    (function main [
      (test1 (1 literal))
     ])))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 4 1))
  (prn "F - missing 'arg' doesn't cause error"))
;? (quit)

(reset)
(new-trace "new-fn-arg-missing-2")
(add-code
  '((function test1 [
      ((4 integer) <- next-input)
      ((5 integer) (6 boolean) <- next-input)
     ])
    (function main [
      (test1 (1 literal))
     ])))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 4 1  6 nil))
  (prn "F - missing 'arg' wipes second oarg when provided"))
;? (quit)

(reset)
(new-trace "new-fn-arg-missing-3")
(add-code
  '((function test1 [
      ((4 integer) <- next-input)
      ((5 integer) <- copy (34 literal))
      ((5 integer) (6 boolean) <- next-input)
    ])
    (function main [
      (test1 (1 literal))
    ])))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 4 1  6 nil))
  (prn "F - missing 'arg' consistently wipes its oarg"))
;? (quit)

(reset)
(new-trace "new-fn-arg-missing-4")
(add-code
  '((function test1 [
      ; if given two args, adds them; if given one arg, increments
      ((4 integer) <- next-input)
      ((5 integer) (6 boolean) <- next-input)
      { begin
        (break-if (6 boolean))
        ((5 integer) <- copy (1 literal))
      }
      ((7 integer) <- add (4 integer) (5 integer))
     ])
    (function main [
      (test1 (34 literal))
     ])))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 4 34  5 1  6 nil  7 35))
  (prn "F - function with optional second arg"))
;? (quit)

(reset)
(new-trace "new-fn-arg-by-value")
(add-code
  '((function test1 [
      ((1 integer) <- copy (0 literal))  ; overwrite caller memory
      ((2 integer) <- next-input)
     ])  ; arg not clobbered
    (function main [
      ((1 integer) <- copy (34 literal))
      (test1 (1 integer))
     ])))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 0  2 34))
  (prn "F - 'arg' passes by value"))

(reset)
(new-trace "arg-record")
(add-code
  '((function test1 [
      ((4 integer-boolean-pair) <- next-input)
     ])
    (function main [
      ((1 integer) <- copy (34 literal))
      ((2 boolean) <- copy (nil literal))
      (test1 (1 integer-boolean-pair))
     ])))
(run 'main)
(if (~iso memory* (obj 1 34  2 nil  4 34  5 nil))
  (prn "F - 'arg' can copy records spanning multiple locations"))

(reset)
(new-trace "arg-record-indirect")
;? (set dump-trace*)
(add-code
  '((function test1 [
      ((4 integer-boolean-pair) <- next-input)
     ])
    (function main [
      ((1 integer) <- copy (34 literal))
      ((2 boolean) <- copy (nil literal))
      ((3 integer-boolean-pair-address) <- copy (1 literal))
      (test1 (3 integer-boolean-pair-address deref))
     ])))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 34  2 nil  3 1  4 34  5 nil))
  (prn "F - 'arg' can copy records spanning multiple locations in indirect mode"))

(reset)
(new-trace "new-fn-reply-oarg")
(add-code
  '((function test1 [
      ((4 integer) <- next-input)
      ((5 integer) <- next-input)
      ((6 integer) <- add (4 integer) (5 integer))
      (reply (6 integer))
      ((4 integer) <- copy (34 literal))
     ])
    (function main [
      ((1 integer) <- copy (1 literal))
      ((2 integer) <- copy (3 literal))
      ((3 integer) <- test1 (1 integer) (2 integer))
     ])))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 1  2 3  3 4
                       ; test1's temporaries
                       4 1  5 3  6 4))
  (prn "F - 'reply' can take aguments that are returned, or written back into output args of caller"))

(reset)
(new-trace "new-fn-reply-oarg-multiple")
(add-code
  '((function test1 [
      ((4 integer) <- next-input)
      ((5 integer) <- next-input)
      ((6 integer) <- add (4 integer) (5 integer))
      (reply (6 integer) (5 integer))
      ((4 integer) <- copy (34 literal))
     ])
    (function main [
      ((1 integer) <- copy (1 literal))
      ((2 integer) <- copy (3 literal))
      ((3 integer) (7 integer) <- test1 (1 integer) (2 integer))
     ])))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 1  2 3  3 4    7 3
                         ; test1's temporaries
                         4 1  5 3  6 4))
  (prn "F - 'reply' permits a function to return multiple values at once"))

(reset)
(new-trace "new-fn-prepare-reply")
(add-code
  '((function test1 [
      ((4 integer) <- next-input)
      ((5 integer) <- next-input)
      ((6 integer) <- add (4 integer) (5 integer))
      (prepare-reply (6 integer) (5 integer))
      (reply)
      ((4 integer) <- copy (34 literal))
     ])
    (function main [
      ((1 integer) <- copy (1 literal))
      ((2 integer) <- copy (3 literal))
      ((3 integer) (7 integer) <- test1 (1 integer) (2 integer))
     ])))
(run 'main)
;? (prn memory*)
(if (~iso memory* (obj 1 1  2 3  3 4    7 3
                         ; test1's temporaries
                         4 1  5 3  6 4))
  (prn "F - without args, 'reply' returns values from previous 'prepare-reply'."))

)  ; section 20

(section 11

;; Structured programming
;
; Our jump operators are quite inconvenient to use, so mu provides a
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
; Braces are like labels in assembly language, they require no special
; parsing. The operations 'loop' and 'break' jump to just after the enclosing
; '{' and '}' respectively.
;
; Conditional and unconditional 'loop' and 'break' should give us 80% of the
; benefits of the control-flow primitives we're used to in other languages,
; like 'if', 'while', 'for', etc.
;
; Compare 'unquoted blocks' using {} with 'quoted blocks' using [] that we've
; gotten used to seeing. Quoted blocks are used by top-level instructions to
; provide code without running it.

(reset)
(new-trace "convert-braces")
(= traces* (queue))
;? (= dump-trace* (obj whitelist '("c{0" "c{1")))
(if (~iso (convert-braces
            '((((1 integer)) <- copy ((4 literal)))
              (((2 integer)) <- copy ((2 literal)))
              (((3 integer)) <- add ((2 integer)) ((2 integer)))
              { begin  ; 'begin' is just a hack because racket turns braces into parens
                (((4 boolean)) <- not-equal ((1 integer)) ((3 integer)))
                (break-if ((4 boolean)))
                (((5 integer)) <- copy ((34 literal)))
              }
              (reply)))
          '((((1 integer)) <- copy ((4 literal)))
            (((2 integer)) <- copy ((2 literal)))
            (((3 integer)) <- add ((2 integer)) ((2 integer)))
            (((4 boolean)) <- not-equal ((1 integer)) ((3 integer)))
            (jump-if ((4 boolean)) ((1 offset)))
            (((5 integer)) <- copy ((34 literal)))
            (reply)))
  (prn "F - convert-braces replaces break-if with a jump-if to after the next close-brace"))
;? (quit)

(reset)
(new-trace "convert-braces-empty-block")
(= traces* (queue))
;? (= dump-trace* (obj whitelist '("c{0" "c{1")))
(if (~iso (convert-braces
            '((((1 integer)) <- copy ((4 literal)))
              (((2 integer)) <- copy ((2 literal)))
              (((3 integer)) <- add ((2 integer)) ((2 integer)))
              { begin
                (break)
              }
              (reply)))
          '((((1 integer)) <- copy ((4 literal)))
            (((2 integer)) <- copy ((2 literal)))
            (((3 integer)) <- add ((2 integer)) ((2 integer)))
            (jump ((0 offset)))
            (reply)))
  (prn "F - convert-braces works for degenerate blocks"))
;? (quit)

(reset)
(new-trace "convert-braces-nested-break")
(= traces* (queue))
(if (~iso (convert-braces
            '((((1 integer)) <- copy ((4 literal)))
              (((2 integer)) <- copy ((2 literal)))
              (((3 integer)) <- add ((2 integer)) ((2 integer)))
              { begin
                (((4 boolean)) <- not-equal ((1 integer)) ((3 integer)))
                (break-if ((4 boolean)))
                { begin
                  (((5 integer)) <- copy ((34 literal)))
                }
              }
              (reply)))
          '((((1 integer)) <- copy ((4 literal)))
            (((2 integer)) <- copy ((2 literal)))
            (((3 integer)) <- add ((2 integer)) ((2 integer)))
            (((4 boolean)) <- not-equal ((1 integer)) ((3 integer)))
            (jump-if ((4 boolean)) ((1 offset)))
            (((5 integer)) <- copy ((34 literal)))
            (reply)))
  (prn "F - convert-braces balances braces when converting break"))

(reset)
(new-trace "convert-braces-repeated-jump")
(= traces* (queue))
;? (= dump-trace* (obj whitelist '("c{0" "c{1")))
(if (~iso (convert-braces
            '((((1 integer)) <- copy ((4 literal)))
              { begin
                (break)
                (((2 integer)) <- copy ((5 literal)))
              }
              { begin
                (break)
                (((3 integer)) <- copy ((6 literal)))
              }
              (((4 integer)) <- copy ((7 literal)))))
          '((((1 integer)) <- copy ((4 literal)))
            (jump ((1 offset)))
            (((2 integer)) <- copy ((5 literal)))
            (jump ((1 offset)))
            (((3 integer)) <- copy ((6 literal)))
            (((4 integer)) <- copy ((7 literal)))))
  (prn "F - convert-braces handles jumps on jumps"))
;? (quit)

(reset)
(new-trace "convert-braces-nested-loop")
(= traces* (queue))
(if (~iso (convert-braces
            '((((1 integer)) <- copy ((4 literal)))
              (((2 integer)) <- copy ((2 literal)))
              { begin
                (((3 integer)) <- add ((2 integer)) ((2 integer)))
                { begin
                  (((4 boolean)) <- not-equal ((1 integer)) ((3 integer)))
                }
                (loop-if ((4 boolean)))
                (((5 integer)) <- copy ((34 literal)))
              }
              (reply)))
          '((((1 integer)) <- copy ((4 literal)))
            (((2 integer)) <- copy ((2 literal)))
            (((3 integer)) <- add ((2 integer)) ((2 integer)))
            (((4 boolean)) <- not-equal ((1 integer)) ((3 integer)))
            (jump-if ((4 boolean)) ((-3 offset)))
            (((5 integer)) <- copy ((34 literal)))
            (reply)))
  (prn "F - convert-braces balances braces when converting 'loop'"))

(reset)
(new-trace "convert-braces-label")
(= traces* (queue))
(if (~iso (convert-braces
            '((((1 integer)) <- copy ((4 literal)))
              foo
              (((2 integer)) <- copy ((2 literal)))))
          '((((1 integer)) <- copy ((4 literal)))
            foo
            (((2 integer)) <- copy ((2 literal)))))
  (prn "F - convert-braces skips past labels"))
;? (quit)

(reset)
(new-trace "convert-braces-label-increments-offset")
(= traces* (queue))
(if (~iso (convert-braces
            '((((1 integer)) <- copy ((4 literal)))
              { begin
                (break)
                foo
              }
              (((2 integer)) <- copy ((2 literal)))))
          '((((1 integer)) <- copy ((4 literal)))
            (jump ((1 offset)))
            foo
            (((2 integer)) <- copy ((2 literal)))))
  (prn "F - convert-braces treats labels as instructions"))
;? (quit)

(reset)
(new-trace "convert-braces-label-increments-offset2")
(= traces* (queue))
;? (= dump-trace* (obj whitelist '("c{0" "c{1")))
(if (~iso (convert-braces
            '((((1 integer)) <- copy ((4 literal)))
              { begin
                (break)
                foo
              }
              (((2 integer)) <- copy ((5 literal)))
              { begin
                (break)
                (((3 integer)) <- copy ((6 literal)))
              }
              (((4 integer)) <- copy ((7 literal)))))
          '((((1 integer)) <- copy ((4 literal)))
            (jump ((1 offset)))
            foo
            (((2 integer)) <- copy ((5 literal)))
            (jump ((1 offset)))
            (((3 integer)) <- copy ((6 literal)))
            (((4 integer)) <- copy ((7 literal)))))
  (prn "F - convert-braces treats labels as instructions - 2"))
;? (quit)

(reset)
(new-trace "break-multiple")
(= traces* (queue))
;? (= dump-trace* (obj whitelist '("-")))
(if (~iso (convert-braces
            '((((1 integer)) <- copy ((0 literal)))
              { begin
                { begin
                  (break ((2 blocks)))
                }
                (((2 integer)) <- copy ((0 literal)))
                (((3 integer)) <- copy ((0 literal)))
                (((4 integer)) <- copy ((0 literal)))
                (((5 integer)) <- copy ((0 literal)))
              }))
          '((((1 integer)) <- copy ((0 literal)))
            (jump ((4 offset)))
            (((2 integer)) <- copy ((0 literal)))
            (((3 integer)) <- copy ((0 literal)))
            (((4 integer)) <- copy ((0 literal)))
            (((5 integer)) <- copy ((0 literal)))))
  (prn "F - 'break' can take an extra arg with number of nested blocks to exit"))
;? (quit)

(reset)
(new-trace "loop")
;? (set dump-trace*)
(if (~iso (convert-braces
            '((((1 integer)) <- copy ((0 literal)))
              (((2 integer)) <- copy ((0 literal)))
              { begin
                (((3 integer)) <- copy ((0 literal)))
                (loop)
              }))
          '((((1 integer)) <- copy ((0 literal)))
            (((2 integer)) <- copy ((0 literal)))
            (((3 integer)) <- copy ((0 literal)))
            (jump ((-2 offset)))))
  (prn "F - 'loop' jumps to start of containing block"))
;? (quit)

; todo: fuzz-test invariant: convert-braces offsets should be robust to any
; number of inner blocks inside but not around the loop block.

(reset)
(new-trace "loop-nested")
;? (set dump-trace*)
(if (~iso (convert-braces
            '((((1 integer)) <- copy ((0 literal)))
              (((2 integer)) <- copy ((0 literal)))
              { begin
                (((3 integer)) <- copy ((0 literal)))
                { begin
                  (((4 integer)) <- copy ((0 literal)))
                }
                (loop)
              }))
          '((((1 integer)) <- copy ((0 literal)))
            (((2 integer)) <- copy ((0 literal)))
            (((3 integer)) <- copy ((0 literal)))
            (((4 integer)) <- copy ((0 literal)))
            (jump ((-3 offset)))))
  (prn "F - 'loop' correctly jumps back past nested braces"))

(reset)
(new-trace "loop-multiple")
(= traces* (queue))
;? (= dump-trace* (obj whitelist '("-")))
(if (~iso (convert-braces
            '((((1 integer)) <- copy ((0 literal)))
              { begin
                (((2 integer)) <- copy ((0 literal)))
                (((3 integer)) <- copy ((0 literal)))
                { begin
                  (loop ((2 blocks)))
                }
              }))
          '((((1 integer)) <- copy ((0 literal)))
            (((2 integer)) <- copy ((0 literal)))
            (((3 integer)) <- copy ((0 literal)))
            (jump ((-3 offset)))))
  (prn "F - 'loop' can take an extra arg with number of nested blocks to exit"))
;? (quit)

;; Variables
;
; A big convenience high-level languages provide is the ability to name memory
; locations. In mu, a lightweight tool called 'convert-names' provides this
; convenience.

(reset)
(new-trace "convert-names")
(= traces* (queue))
;? (set dump-trace*)
(if (~iso (convert-names
            '((((x integer)) <- copy ((4 literal)))
              (((y integer)) <- copy ((2 literal)))
              (((z integer)) <- add ((x integer)) ((y integer)))))
          '((((1 integer)) <- copy ((4 literal)))
            (((2 integer)) <- copy ((2 literal)))
            (((3 integer)) <- add ((1 integer)) ((2 integer)))))
  (prn "F - convert-names renames symbolic names to integer locations"))

(reset)
(new-trace "convert-names-compound")
(= traces* (queue))
(if (~iso (convert-names
            '((((x integer-boolean-pair)) <- copy ((4 literal)))
              (((y integer)) <- copy ((2 literal)))))
          '((((1 integer-boolean-pair)) <- copy ((4 literal)))
            (((3 integer)) <- copy ((2 literal)))))
  (prn "F - convert-names increments integer locations by the size of the type of the previous var"))

(reset)
(new-trace "convert-names-nil")
(= traces* (queue))
;? (set dump-trace*)
(if (~iso (convert-names
            '((((x integer)) <- copy ((4 literal)))
              (((y integer)) <- copy ((2 literal)))
              ; nil location is meaningless; just for testing
              (((nil integer)) <- add ((x integer)) ((y integer)))))
          '((((1 integer)) <- copy ((4 literal)))
            (((2 integer)) <- copy ((2 literal)))
            (((nil integer)) <- add ((1 integer)) ((2 integer)))))
  (prn "F - convert-names never renames nil"))

(reset)
(new-trace "convert-names-global")
(= traces* (queue))
(if (~iso (convert-names
            '((((x integer)) <- copy ((4 literal)))
              (((y integer) (global)) <- copy ((2 literal)))
              (((default-scope integer)) <- add ((x integer)) ((y integer) (global)))))
          '((((1 integer)) <- copy ((4 literal)))
            (((y integer) (global)) <- copy ((2 literal)))
            (((default-scope integer)) <- add ((1 integer)) ((y integer) (global)))))
  (prn "F - convert-names never renames global operands"))

(reset)
(new-trace "convert-names-literal")
(= traces* (queue))
(if (~iso (convert-names
            ; meaningless; just for testing
            '((((x literal)) <- copy ((0 literal)))))
          '((((x literal)) <- copy ((0 literal)))))
  (prn "F - convert-names never renames literals"))

; kludgy support for 'fork' below
(reset)
(new-trace "convert-names-functions")
(= traces* (queue))
(if (~iso (convert-names
            '((((x integer)) <- copy ((4 literal)))
              (((y integer)) <- copy ((2 literal)))
              (((z fn)) <- add ((x integer)) ((y integer)))))
          '((((1 integer)) <- copy ((4 literal)))
            (((2 integer)) <- copy ((2 literal)))
            (((z fn)) <- add ((1 integer)) ((2 integer)))))
  (prn "F - convert-names never renames fns"))

(reset)
(new-trace "convert-names-record-fields")
(= traces* (queue))
(if (~iso (convert-names
            '((((x integer)) <- get ((34 integer-boolean-pair)) ((bool offset)))))
          '((((1 integer)) <- get ((34 integer-boolean-pair)) ((1 offset)))))
  (prn "F - convert-names replaces record field offsets"))

(reset)
(new-trace "convert-names-record-fields-ambiguous")
(= traces* (queue))
(if (errsafe (convert-names
               '((((bool boolean)) <- copy ((t literal)))
                 (((x integer)) <- get ((34 integer-boolean-pair)) ((bool offset))))))
  (prn "F - convert-names doesn't allow offsets and variables with the same name in a function"))

(reset)
(new-trace "convert-names-record-fields-ambiguous-2")
(= traces* (queue))
(if (errsafe (convert-names
               '((((x integer)) <- get ((34 integer-boolean-pair)) ((bool offset)))
                 (((bool boolean)) <- copy ((t literal))))))
  (prn "F - convert-names doesn't allow offsets and variables with the same name in a function - 2"))

(reset)
(new-trace "convert-names-record-fields-indirect")
(= traces* (queue))
(if (~iso (convert-names
            '((((x integer)) <- get ((34 integer-boolean-pair-address) (deref)) ((bool offset)))))
          '((((1 integer)) <- get ((34 integer-boolean-pair-address) (deref)) ((1 offset)))))
  (prn "F - convert-names replaces field offsets for record addresses"))

(reset)
(new-trace "convert-names-record-fields-multiple")
(= traces* (queue))
(if (~iso (convert-names
            '((((2 boolean)) <- get ((1 integer-boolean-pair)) ((bool offset)))
              (((3 boolean)) <- get ((1 integer-boolean-pair)) ((bool offset)))))
          '((((2 boolean)) <- get ((1 integer-boolean-pair)) ((1 offset)))
            (((3 boolean)) <- get ((1 integer-boolean-pair)) ((1 offset)))))
  (prn "F - convert-names replaces field offsets with multiple mentions"))
;? (quit)

(reset)
(new-trace "convert-names-label")
(= traces* (queue))
(if (~iso (convert-names
            '((((1 integer)) <- copy ((4 literal)))
              foo))
          '((((1 integer)) <- copy ((4 literal)))
            foo))
  (prn "F - convert-names skips past labels"))
;? (quit)

)  ; section 11

(section 20

; A rudimentary memory allocator. Eventually we want to write this in mu.
;
; No deallocation yet; let's see how much code we can build in mu before we
; feel the need for it.

(reset)
(new-trace "new-primitive")
(add-code
  '((function main [
      (((1 integer-address)) <- new (integer literal))
     ])))
(let routine make-routine!main
  (enq routine running-routines*)
  (let before rep.routine!alloc
;?     (set dump-trace*)
    (run)
  ;?   (prn memory*)
    (if (~iso memory*.1 before)
      (prn "F - 'new' returns current high-water mark"))
    (if (~iso rep.routine!alloc (+ before 1))
      (prn "F - 'new' on primitive types increments high-water mark by their size"))))

(reset)
(new-trace "new-array-literal")
(add-code
  '((function main [
      (((1 type-array-address)) <- new (type-array literal) ((5 literal)))
     ])))
(let routine make-routine!main
  (enq routine running-routines*)
  (let before rep.routine!alloc
    (run)
;?     (prn memory*)
    (if (~iso memory*.1 before)
      (prn "F - 'new' on array with literal size returns current high-water mark"))
    (if (~iso rep.routine!alloc (+ before 6))
      (prn "F - 'new' on primitive arrays increments high-water mark by their size"))))

(reset)
(new-trace "new-array-direct")
(add-code
  '((function main [
      (((1 integer)) <- copy ((5 literal)))
      (((2 type-array-address)) <- new (type-array literal) ((1 integer)))
     ])))
(let routine make-routine!main
  (enq routine running-routines*)
  (let before rep.routine!alloc
    (run)
;?     (prn memory*)
    (if (~iso memory*.2 before)
      (prn "F - 'new' on array with variable size returns current high-water mark"))
    (if (~iso rep.routine!alloc (+ before 6))
      (prn "F - 'new' on primitive arrays increments high-water mark by their (variable) size"))))

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
(add-code
  '((function main [
      ((default-scope scope-address) <- new (scope literal) ((2 literal)))
      (((1 integer)) <- copy ((23 literal)))
     ])))
(let routine make-routine!main
  (enq routine running-routines*)
  (let before rep.routine!alloc
;?     (set dump-trace*)
    (run)
;?     (prn memory*)
    (if (~and (~is 23 memory*.1)
              (is 23 (memory* (+ before 1))))
      (prn "F - default-scope implicitly modifies variable locations"))))

(reset)
(new-trace "set-default-scope-skips-offset")
(add-code
  '((function main [
      ((default-scope scope-address) <- new (scope literal) ((2 literal)))
      (((1 integer)) <- copy ((23 offset)))
     ])))
(let routine make-routine!main
  (enq routine running-routines*)
  (let before rep.routine!alloc
;?     (set dump-trace*)
    (run)
;?     (prn memory*)
    (if (~and (~is 23 memory*.1)
              (is 23 (memory* (+ before 1))))
      (prn "F - default-scope skips 'offset' types just like literals"))))

(reset)
(new-trace "default-scope-bounds-check")
(add-code
  '((function main [
      ((default-scope scope-address) <- new (scope literal) ((2 literal)))
      (((2 integer)) <- copy ((23 literal)))
     ])))
;? (set dump-trace*)
(run 'main)
;? (prn memory*)
(let routine (car completed-routines*)
  (if (no rep.routine!error)
    (prn "F - default-scope checks bounds")))

(reset)
(new-trace "default-scope-and-get-indirect")
(add-code
  '((function main [
      ((default-scope scope-address) <- new (scope literal) ((5 literal)))
      (((1 integer-boolean-pair-address)) <- new (integer-boolean-pair literal))
      (((2 integer-address)) <- get-address (1 integer-boolean-pair-address deref) ((0 offset)))
      ((2 integer-address deref) <- copy ((34 literal)))
      ((3 integer global) <- get (1 integer-boolean-pair-address deref) ((0 offset)))
     ])))
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
(add-code
  '((function main [
      ((default-scope scope-address) <- new (scope literal) ((5 literal)))
      (((1 integer-array-address)) <- new (integer-array literal) ((4 literal)))
      (((2 integer-address)) <- index-address (1 integer-array-address deref) ((2 offset)))
      ((2 integer-address deref) <- copy ((34 literal)))
      ((3 integer global) <- index (1 integer-array-address deref) ((2 offset)))
     ])))
;? (= dump-trace* (obj whitelist '("run" "array-info")))
(run 'main)
;? (prn memory*)
;? (prn completed-routines*)
(each routine completed-routines*
  (aif rep.routine!error (prn "error - " it)))
(if (~is 34 memory*.3)
  (prn "F - indirect 'index' works in the presence of default-scope"))
;? (quit)

(reset)
(new-trace "convert-names-default-scope")
(= traces* (queue))
(if (~iso (convert-names
            '(((x integer) <- copy ((4 literal)))
              ((y integer) <- copy ((2 literal)))
              ; unsafe in general; don't write random values to 'default-scope'
              ((default-scope integer) <- add (x integer) (y integer))))
          '((((1 integer)) <- copy ((4 literal)))
            (((2 integer)) <- copy ((2 literal)))
            ((default-scope integer) <- add ((1 integer)) ((2 integer)))))
  (prn "F - convert-names never renames default-scope"))

(reset)
(new-trace "suppress-default-scope")
(add-code
  '((function main [
      ((default-scope scope-address) <- new (scope literal) ((2 literal)))
      ((1 integer global) <- copy ((23 literal)))
     ])))
(let routine make-routine!main
  (enq routine running-routines*)
  (let before rep.routine!alloc
;?     (set dump-trace*)
    (run)
;?     (prn memory*)
    (if (~and (is 23 memory*.1)
              (~is 23 (memory* (+ before 1))))
      (prn "F - default-scope skipped for locations with metadata 'global'"))))
;? (quit)

(reset)
(new-trace "array-copy-indirect-scoped")
(add-code
  '((function main [
      (((10 integer)) <- copy ((30 literal)))  ; pretend allocation
      ((default-scope scope-address) <- copy ((10 literal)))  ; unsafe
      (((1 integer)) <- copy ((2 literal)))
      (((2 integer)) <- copy ((23 literal)))
      (((3 boolean)) <- copy (nil literal))
      (((4 integer)) <- copy ((24 literal)))
      (((5 boolean)) <- copy (t literal))
      (((6 integer-boolean-pair-array-address)) <- copy ((11 literal)))  ; unsafe
      (((7 integer-boolean-pair-array)) <- copy (6 integer-boolean-pair-array-address deref))
     ])))
;? (set dump-trace*)
;? (= dump-trace* (obj whitelist '("run" "m" "sizeof")))
(run 'main)
;? (prn memory*)
(each routine completed-routines*
  (aif rep.routine!error (prn "error - " it)))
(if (~iso memory*.17 2)
  (prn "F - indirect array copy in the presence of 'default-scope'"))
;? (quit)

(reset)
(new-trace "len-array-indirect-scoped")
(add-code
  '((function main [
      (((10 integer)) <- copy ((30 literal)))  ; pretend allocation
      ((default-scope scope-address) <- copy ((10 literal)))  ; unsafe
      (((1 integer)) <- copy ((2 literal)))
      (((2 integer)) <- copy ((23 literal)))
      (((3 boolean)) <- copy (nil literal))
      (((4 integer)) <- copy ((24 literal)))
      (((5 boolean)) <- copy (t literal))
      (((6 integer-address)) <- copy ((11 literal)))  ; unsafe
      (((7 integer)) <- length (6 integer-boolean-pair-array-address deref))
     ])))
;? (= dump-trace* (obj whitelist '("run" "addr" "sz" "array-len")))
(run 'main)
;? (prn memory*)
(if (~iso memory*.17 2)
  (prn "F - 'len' accesses length of array address"))
;? (quit)

)  ; section 20

(section 100

;; Dynamic dispatch
;
; Putting it all together, here's how you define generic functions that run
; different code based on the types of their args.

(reset)
(new-trace "dispatch-clause")
;? (set dump-trace*)
(add-code
  '((function test1 [
      ; doesn't matter too much how many locals you allocate space for (here 20)
      ; if it's slightly too many -- memory is plentiful
      ; if it's too few -- mu will raise an error
      ((default-scope scope-address) <- new (scope literal) (20 literal))
      ((first-arg-box tagged-value-address) <- next-input)
      ; if given integers, add them
      { begin
        ((first-arg integer) (match? boolean) <- maybe-coerce (first-arg-box tagged-value-address deref) (integer literal))
        (break-unless (match? boolean))
        ((second-arg-box tagged-value-address) <- next-input)
        ((second-arg integer) <- maybe-coerce (second-arg-box tagged-value-address deref) (integer literal))
        ((result integer) <- add (first-arg integer) (second-arg integer))
        (reply (result integer))
      }
      (reply (nil literal))
     ])
    (function main [
      ((1 tagged-value-address) <- new-tagged-value (integer literal) (34 literal))
      ((2 tagged-value-address) <- new-tagged-value (integer literal) (3 literal))
      ((3 integer) <- test1 (1 tagged-value-address) (2 tagged-value-address))
     ])))
(run 'main)
;? (prn memory*)
(if (~is memory*.3 37)
  (prn "F - an example function that checks that its oarg is an integer"))
;? (quit)

; todo - test that reply increments pc for caller frame after popping current frame

(reset)
(new-trace "dispatch-multiple-clauses")
;? (set dump-trace*)
(add-code
  '((function test1 [
      ((default-scope scope-address) <- new (scope literal) (20 literal))
      ((first-arg-box tagged-value-address) <- next-input)
      ; if given integers, add them
      { begin
        ((first-arg integer) (match? boolean) <- maybe-coerce (first-arg-box tagged-value-address deref) (integer literal))
        (break-unless (match? boolean))
        ((second-arg-box tagged-value-address) <- next-input)
        ((second-arg integer) <- maybe-coerce (second-arg-box tagged-value-address deref) (integer literal))
        ((result integer) <- add (first-arg integer) (second-arg integer))
        (reply (result integer))
      }
      ; if given booleans, or them (it's a silly kind of generic function)
      { begin
        ((first-arg boolean) (match? boolean) <- maybe-coerce (first-arg-box tagged-value-address deref) (boolean literal))
        (break-unless (match? boolean))
        ((second-arg-box tagged-value-address) <- next-input)
        ((second-arg boolean) <- maybe-coerce (second-arg-box tagged-value-address deref) (boolean literal))
        ((result boolean) <- or (first-arg boolean) (second-arg boolean))
        (reply (result integer))
      }
      (reply (nil literal))
     ])
    (function main [
      ((1 tagged-value-address) <- new-tagged-value (boolean literal) (t literal))
      ((2 tagged-value-address) <- new-tagged-value (boolean literal) (nil literal))
      ((3 boolean) <- test1 (1 tagged-value-address) (2 tagged-value-address))
     ])))
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
(add-code
  '((function test1 [
      ((default-scope scope-address) <- new (scope literal) (20 literal))
      ((first-arg-box tagged-value-address) <- next-input)
      ; if given integers, add them
      { begin
        ((first-arg integer) (match? boolean) <- maybe-coerce (first-arg-box tagged-value-address deref) (integer literal))
        (break-unless (match? boolean))
        ((second-arg-box tagged-value-address) <- next-input)
        ((second-arg integer) <- maybe-coerce (second-arg-box tagged-value-address deref) (integer literal))
        ((result integer) <- add (first-arg integer) (second-arg integer))
        (reply (result integer))
      }
      ; if given booleans, or them (it's a silly kind of generic function)
      { begin
        ((first-arg boolean) (match? boolean) <- maybe-coerce (first-arg-box tagged-value-address deref) (boolean literal))
        (break-unless (match? boolean))
        ((second-arg-box tagged-value-address) <- next-input)
        ((second-arg boolean) <- maybe-coerce (second-arg-box tagged-value-address deref) (boolean literal))
        ((result boolean) <- or (first-arg boolean) (second-arg boolean))
        (reply (result integer))
      }
      (reply (nil literal))
     ])
    (function main [
      ((1 tagged-value-address) <- new-tagged-value (boolean literal) (t literal))
      ((2 tagged-value-address) <- new-tagged-value (boolean literal) (nil literal))
      ((3 boolean) <- test1 (1 tagged-value-address) (2 tagged-value-address))
      ((10 tagged-value-address) <- new-tagged-value (integer literal) (34 literal))
      ((11 tagged-value-address) <- new-tagged-value (integer literal) (3 literal))
      ((12 integer) <- test1 (10 tagged-value-address) (11 tagged-value-address))
     ])))
(run 'main)
;? (prn memory*)
(if (~and (is memory*.3 t) (is memory*.12 37))
  (prn "F - different calls can exercise different clauses of the same function"))

)  ; section 100

(section 20

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
(= traces* (queue))
(add-code
  '((function f1 [
      ((1 integer) <- copy (3 literal))
     ])
    (function f2 [
      ((2 integer) <- copy (4 literal))
     ])))
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
(= traces* (queue))
(add-code
  '((function f1 [
      ((1 integer) <- copy (3 literal))
      ((1 integer) <- copy (3 literal))
     ])
    (function f2 [
      ((2 integer) <- copy (4 literal))
      ((2 integer) <- copy (4 literal))
     ])))
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
(= traces* (queue))
(add-code
  '((function f1 [
      ((1 integer) <- copy (3 literal))
     ])
    (function f2 [
      ((2 integer) <- copy (4 literal))
     ])))
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
(= traces* (queue))
(add-code
  '((function f1 [
      ((1 integer) <- copy (3 literal))
     ])
    (function f2 [
      ((2 integer) <- copy (4 literal))
     ])))
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
(= traces* (queue))
(add-code
  '((function f1 [
      ((1 integer) <- copy (3 literal))
     ])
    (function f2 [
      ((2 integer) <- copy (4 literal))
     ])))
; add one baseline routine to run (empty running-routines* handled below)
(enq make-routine!f1 running-routines*)
(assert (is 1 len.running-routines*))
; blocked routine waiting for location 23 to change
(let routine make-routine!f2
  (= rep.routine!sleep '(23 0))
  (set sleeping-routines*.routine))
; leave memory location 23 unchanged
(= memory*.23 0)
;? (prn memory*)
;? (prn running-routines*)
;? (prn sleeping-routines*)
;? (set dump-trace*)
;? (= dump-trace* (obj whitelist '("run" "schedule")))
(update-scheduler-state)
;? (prn running-routines*)
;? (prn sleeping-routines*)
; routine remains blocked
(if (~is 1 len.running-routines*)
  (prn "F - scheduler lets routines block on locations"))
;? (quit)

(reset)
(new-trace "scheduler-wakeup-location")
(= traces* (queue))
(add-code
  '((function f1 [
      ((1 integer) <- copy (3 literal))
     ])
    (function f2 [
      ((2 integer) <- copy (4 literal))
     ])))
; add one baseline routine to run (empty running-routines* handled below)
(enq make-routine!f1 running-routines*)
(assert (is 1 len.running-routines*))
; blocked routine waiting for location 23 to change
(let routine make-routine!f2
  (= rep.routine!sleep '(23 0))
  (set sleeping-routines*.routine))
; change memory location 23
(= memory*.23 1)
(update-scheduler-state)
; routine unblocked
(if (~is 2 len.running-routines*)
  (prn "F - scheduler unblocks routines blocked on locations"))

(reset)
(new-trace "scheduler-skip")
(= traces* (queue))
(add-code
  '((function f1 [
      ((1 integer) <- copy (3 literal))
     ])))
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
(= traces* (queue))
(add-code
  '((function f1 [
      ((1 integer) <- copy (3 literal))
     ])))
(assert (empty running-routines*))
(assert (empty completed-routines*))
; blocked routine
(let routine make-routine!f1
  (= rep.routine!sleep '(23 0))
  (set sleeping-routines*.routine))
; location it's waiting on is 'unchanged'
(= memory*.23 0)
(update-scheduler-state)
(assert (~empty completed-routines*))
;? (prn completed-routines*)
(let routine completed-routines*.0
  (when (~posmatch "deadlock" rep.routine!error)
    (prn "F - scheduler detects deadlock")))
;? (quit)

(reset)
(new-trace "scheduler-deadlock2")
(= traces* (queue))
(add-code
  '((function f1 [
      ((1 integer) <- copy (3 literal))
     ])))
; running-routines* is empty
(assert (empty running-routines*))
; blocked routine
(let routine make-routine!f1
  (= rep.routine!sleep '(23 0))
  (set sleeping-routines*.routine))
; but is about to become ready
(= memory*.23 1)
(update-scheduler-state)
(when (~empty completed-routines*)
  (prn "F - scheduler ignores sleeping but ready threads when detecting deadlock"))

(reset)
(new-trace "sleep")
(add-code
  '((function f1 [
      (sleep (1 literal))
      ((1 integer) <- copy (3 literal))
      ((1 integer) <- copy (3 literal))
     ])
    (function f2 [
      ((2 integer) <- copy (4 literal))
      ((2 integer) <- copy (4 literal))
     ])))
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
(add-code
  '((function f1 [
      (sleep (20 literal))
      ((1 integer) <- copy (3 literal))
      ((1 integer) <- copy (3 literal))
     ])
    (function f2 [
      ((2 integer) <- copy (4 literal))
      ((2 integer) <- copy (4 literal))
     ])))
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
(add-code
  '((function f1 [
      ; waits for memory location 1 to be set, before computing its successor
      ((1 integer) <- copy (0 literal))
      (sleep (1 integer))
      ((2 integer) <- add (1 integer) (1 literal))
     ])
    (function f2 [
      (sleep (30 literal))
      ((1 integer) <- copy (3 literal))  ; set to value
     ])))
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
(add-code
  '((function f1 [
      ; waits for memory location 1 to be changed, before computing its successor
      ((10 integer) <- copy (5 literal))  ; array of locals
      ((default-scope scope-address) <- copy (10 literal))
      ((1 integer) <- copy (23 literal))  ; really location 11
      (sleep (1 integer))
      ((2 integer) <- add (1 integer) (1 literal))
     ])
    (function f2 [
      (sleep (30 literal))
      ((11 integer) <- copy (3 literal))  ; set to value
     ])))
;? (= dump-trace* (obj whitelist '("run" "schedule")))
(run 'f1 'f2)
(if (~is memory*.12 4)  ; successor of value
  (prn "F - sleep can block on a scoped memory location"))
;? (quit)

(reset)
(new-trace "fork")
(add-code
  '((function f1 [
      (fork (f2 fn))
     ])
    (function f2 [
      ((2 integer) <- copy (4 literal))
     ])))
(run 'f1)
(if (~iso memory*.2 4)
  (prn "F - fork works"))

(reset)
(new-trace "fork-with-args")
(add-code
  '((function f1 [
      (fork (f2 fn) (4 literal))
     ])
    (function f2 [
      ((2 integer) <- next-input)
     ])))
(run 'f1)
(if (~iso memory*.2 4)
  (prn "F - fork can pass args"))

(reset)
(new-trace "fork-copies-args")
(add-code
  '((function f1 [
      ((default-scope scope-address) <- new (scope literal) (5 literal))
      ((x integer) <- copy (4 literal))
      (fork (f2 fn) (x integer))
      ((x integer) <- copy (0 literal))  ; should be ignored
     ])
    (function f2 [
      ((2 integer) <- next-input)
     ])))
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
(add-code
  '((function main [
      ((1 integer) <- copy (2 literal))
      ((2 integer) <- copy (23 literal))
      ((3 integer) <- copy (24 literal))
      ((4 integer) <- index (1 integer-array) (2 literal))
     ])))
;? (set dump-trace*)
(run 'main)
;? (prn memory*)
(let routine (car completed-routines*)
  (if (no rep.routine!error)
    (prn "F - 'index' throws an error if out of bounds")))

)  ; section 20

(section 100

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
(add-code
  '((function main [
      ((1 channel-address) <- new-channel (3 literal))
      ((2 integer) <- get (1 channel-address deref) (first-full offset))
      ((3 integer) <- get (1 channel-address deref) (first-free offset))
     ])))
;? (set dump-trace*)
(run 'main)
;? (prn memory*)
(if (or (~is 0 memory*.2)
        (~is 0 memory*.3))
  (prn "F - 'new-channel' initializes 'first-full and 'first-free to 0"))

(reset)
(new-trace "channel-write")
(add-code
  '((function main [
      ((1 channel-address) <- new-channel (3 literal))
      ((2 integer-address) <- new (integer literal))
      ((2 integer-address deref) <- copy (34 literal))
      ((3 tagged-value) <- save-type (2 integer-address))
      ((1 channel-address deref) <- write (1 channel-address) (3 tagged-value))
      ((5 integer) <- get (1 channel-address deref) (first-full offset))
      ((6 integer) <- get (1 channel-address deref) (first-free offset))
     ])))
;? (set dump-trace*)
;? (= dump-trace* (obj blacklist '("sz" "m" "setm" "addr" "array-len" "cvt0" "cvt1")))
;? (= dump-trace* (obj whitelist '("jump")))
(run 'main)
;? (prn canon.memory*)
(if (or (~is 0 memory*.5)
        (~is 1 memory*.6))
  (prn "F - 'write' enqueues item to channel"))
;? (quit)

(reset)
(new-trace "channel-read")
(add-code
  '((function main [
      ((1 channel-address) <- new-channel (3 literal))
      ((2 integer-address) <- new (integer literal))
      ((2 integer-address deref) <- copy (34 literal))
      ((3 tagged-value) <- save-type (2 integer-address))
      ((1 channel-address deref) <- write (1 channel-address) (3 tagged-value))
      ((5 tagged-value) (1 channel-address deref) <- read (1 channel-address))
      ((7 integer-address) <- maybe-coerce (5 tagged-value) (integer-address literal))
      ((8 integer) <- get (1 channel-address deref) (first-full offset))
      ((9 integer) <- get (1 channel-address deref) (first-free offset))
     ])))
;? (set dump-trace*)
;? (= dump-trace* (obj blacklist '("sz" "m" "setm" "addr" "array-len" "cvt0" "cvt1")))
(run 'main)
;? (prn int-canon.memory*)
(if (~is memory*.7 memory*.2)
  (prn "F - 'read' returns written value"))
(if (or (~is 1 memory*.8)
        (~is 1 memory*.9))
  (prn "F - 'read' dequeues item from channel"))

(reset)
(new-trace "channel-write-wrap")
(add-code
  '((function main [
      ; channel with 1 slot
      ((1 channel-address) <- new-channel (1 literal))
      ; write a value
      ((2 integer-address) <- new (integer literal))
      ((2 integer-address deref) <- copy (34 literal))
      ((3 tagged-value) <- save-type (2 integer-address))
      ((1 channel-address deref) <- write (1 channel-address) (3 tagged-value))
      ; first-free will now be 1
      ((5 integer) <- get (1 channel-address deref) (first-free offset))
      ; read one value
      (_ (1 channel-address deref) <- read (1 channel-address))
      ; write a second value; verify that first-free wraps around to 0.
      ((1 channel-address deref) <- write (1 channel-address) (3 tagged-value))
      ((6 integer) <- get (1 channel-address deref) (first-free offset))
     ])))
;? (set dump-trace*)
;? (= dump-trace* (obj blacklist '("sz" "m" "setm" "addr" "array-len" "cvt0" "cvt1")))
(run 'main)
;? (prn canon.memory*)
(if (or (~is 1 memory*.5)
        (~is 0 memory*.6))
  (prn "F - 'write' can wrap pointer back to start"))

(reset)
(new-trace "channel-read-wrap")
(add-code
  '((function main [
      ; channel with 1 slot
      ((1 channel-address) <- new-channel (1 literal))
      ; write a value
      ((2 integer-address) <- new (integer literal))
      ((2 integer-address deref) <- copy (34 literal))
      ((3 tagged-value) <- save-type (2 integer-address))
      ((1 channel-address deref) <- write (1 channel-address) (3 tagged-value))
      ; read one value
      (_ (1 channel-address deref) <- read (1 channel-address))
      ; first-full will now be 1
      ((5 integer) <- get (1 channel-address deref) (first-full offset))
      ; write a second value
      ((1 channel-address deref) <- write (1 channel-address) (3 tagged-value))
      ; read second value; verify that first-full wraps around to 0.
      (_ (1 channel-address deref) <- read (1 channel-address))
      ((6 integer) <- get (1 channel-address deref) (first-full offset))
     ])))
;? (set dump-trace*)
;? (= dump-trace* (obj blacklist '("sz" "m" "setm" "addr" "array-len" "cvt0" "cvt1")))
(run 'main)
;? (prn canon.memory*)
(if (or (~is 1 memory*.5)
        (~is 0 memory*.6))
  (prn "F - 'read' can wrap pointer back to start"))

(reset)
(new-trace "channel-new-empty-not-full")
(add-code
  '((function main [
      ((1 channel-address) <- new-channel (3 literal))
      ((2 boolean) <- empty? (1 channel-address deref))
      ((3 boolean) <- full? (1 channel-address deref))
     ])))
;? (set dump-trace*)
(run 'main)
;? (prn memory*)
(if (or (~is t memory*.2)
        (~is nil memory*.3))
  (prn "F - a new channel is always empty, never full"))

(reset)
(new-trace "channel-write-not-empty")
(add-code
  '((function main [
      ((1 channel-address) <- new-channel (3 literal))
      ((2 integer-address) <- new (integer literal))
      ((2 integer-address deref) <- copy (34 literal))
      ((3 tagged-value) <- save-type (2 integer-address))
      ((1 channel-address deref) <- write (1 channel-address) (3 tagged-value))
      ((5 boolean) <- empty? (1 channel-address deref))
      ((6 boolean) <- full? (1 channel-address deref))
     ])))
;? (set dump-trace*)
(run 'main)
;? (prn memory*)
(if (or (~is nil memory*.5)
        (~is nil memory*.6))
  (prn "F - a channel after writing is never empty"))

(reset)
(new-trace "channel-write-full")
(add-code
  '((function main [
      ((1 channel-address) <- new-channel (1 literal))
      ((2 integer-address) <- new (integer literal))
      ((2 integer-address deref) <- copy (34 literal))
      ((3 tagged-value) <- save-type (2 integer-address))
      ((1 channel-address deref) <- write (1 channel-address) (3 tagged-value))
      ((5 boolean) <- empty? (1 channel-address deref))
      ((6 boolean) <- full? (1 channel-address deref))
     ])))
;? (set dump-trace*)
(run 'main)
;? (prn memory*)
(if (or (~is nil memory*.5)
        (~is t memory*.6))
  (prn "F - a channel after writing may be full"))

(reset)
(new-trace "channel-read-not-full")
(add-code
  '((function main [
      ((1 channel-address) <- new-channel (3 literal))
      ((2 integer-address) <- new (integer literal))
      ((2 integer-address deref) <- copy (34 literal))
      ((3 tagged-value) <- save-type (2 integer-address))
      ((1 channel-address deref) <- write (1 channel-address) (3 tagged-value))
      ((1 channel-address deref) <- write (1 channel-address) (3 tagged-value))
      (_ (1 channel-address deref) <- read (1 channel-address))
      ((5 boolean) <- empty? (1 channel-address deref))
      ((6 boolean) <- full? (1 channel-address deref))
     ])))
;? (set dump-trace*)
(run 'main)
;? (prn memory*)
(if (or (~is nil memory*.5)
        (~is nil memory*.6))
  (prn "F - a channel after reading is never full"))

(reset)
(new-trace "channel-read-empty")
(add-code
  '((function main [
      ((1 channel-address) <- new-channel (3 literal))
      ((2 integer-address) <- new (integer literal))
      ((2 integer-address deref) <- copy (34 literal))
      ((3 tagged-value) <- save-type (2 integer-address))
      ((1 channel-address deref) <- write (1 channel-address) (3 tagged-value))
      (_ (1 channel-address deref) <- read (1 channel-address))
      ((5 boolean) <- empty? (1 channel-address deref))
      ((6 boolean) <- full? (1 channel-address deref))
     ])))
;? (set dump-trace*)
(run 'main)
;? (prn memory*)
(if (or (~is t memory*.5)
        (~is nil memory*.6))
  (prn "F - a channel after reading may be empty"))

; The key property of channels; writing to a full channel blocks the current
; routine until it creates space. Ditto reading from an empty channel.

(reset)
(new-trace "channel-read-block")
(add-code
  '((function main [
      ((1 channel-address) <- new-channel (3 literal))
      ; channel is empty, but receives a read
      ((2 tagged-value) (1 channel-address deref) <- read (1 channel-address))
     ])))
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
(add-code
  '((function main [
      ((1 channel-address) <- new-channel (1 literal))
      ((2 integer-address) <- new (integer literal))
      ((2 integer-address deref) <- copy (34 literal))
      ((3 tagged-value) <- save-type (2 integer-address))
      ((1 channel-address deref) <- write (1 channel-address) (3 tagged-value))
      ; channel has capacity 1, but receives a second write
      ((1 channel-address deref) <- write (1 channel-address) (3 tagged-value))
     ])))
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

(reset)
(new-trace "channel-handoff")
(add-code
  '((function f1 [
      ((default-scope scope-address) <- new (scope literal) (30 literal))
      ((chan channel-address) <- new-channel (3 literal))
      (fork (f2 fn) (chan channel-address))
      ((1 tagged-value global) <- read (chan channel-address))  ; output
     ])
    (function f2 [
      ((default-scope scope-address) <- new (scope literal) (30 literal))
      ((n integer-address) <- new (integer literal))
      ((n integer-address deref) <- copy (24 literal))
      ((ochan channel-address) <- next-input)
      ((x tagged-value) <- save-type (n integer-address))
      ((ochan channel-address deref) <- write (ochan channel-address) (x tagged-value))
     ])))
;? (set dump-trace*)
;? (= dump-trace* (obj whitelist '("schedule" "run" "addr")))
;? (= dump-trace* (obj whitelist '("-")))
(run 'f1)
;? (prn memory*)
(each routine completed-routines*
  (aif rep.routine!error (prn "error - " it)))
(if (~is 24 (memory* memory*.2))  ; location 1 contains tagged-value *x above
  (prn "F - channels are meant to be shared between routines"))
;? (quit)

)  ; section 100

(section 10

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
(new-trace "convert-quotes-defer")
(= traces* (queue))
(if (~iso (convert-quotes
            '((1:integer <- copy 4:literal)
              (defer [
                       (3:integer <- copy 6:literal)
                     ])
              (2:integer <- copy 5:literal)))
          '((1:integer <- copy 4:literal)
            (2:integer <- copy 5:literal)
            (3:integer <- copy 6:literal)))
  (prn "F - convert-quotes can handle 'defer'"))

(reset)
(new-trace "convert-quotes-defer-reply")
(= traces* (queue))
(if (~iso (convert-quotes
            '((1:integer <- copy 0:literal)
              (defer [
                       (5:integer <- copy 0:literal)
                     ])
              (2:integer <- copy 0:literal)
              (reply)
              (3:integer <- copy 0:literal)
              (4:integer <- copy 0:literal)))
          '((1:integer <- copy 0:literal)
            (2:integer <- copy 0:literal)
            (5:integer <- copy 0:literal)
            (reply)
            (3:integer <- copy 0:literal)
            (4:integer <- copy 0:literal)
            (5:integer <- copy 0:literal)))
  (prn "F - convert-quotes inserts code at early exits"))

(reset)
(new-trace "convert-quotes-defer-reply-arg")
(= traces* (queue))
(if (~iso (convert-quotes
            '((1:integer <- copy 0:literal)
              (defer [
                       (5:integer <- copy 0:literal)
                     ])
              (2:integer <- copy 0:literal)
              (reply 2:literal)
              (3:integer <- copy 0:literal)
              (4:integer <- copy 0:literal)))
          '((1:integer <- copy 0:literal)
            (2:integer <- copy 0:literal)
            (prepare-reply 2:literal)
            (5:integer <- copy 0:literal)
            (reply)
            (3:integer <- copy 0:literal)
            (4:integer <- copy 0:literal)
            (5:integer <- copy 0:literal)))
  (prn "F - convert-quotes inserts code at early exits"))

(reset)
(new-trace "convert-quotes-label")
(= traces* (queue))
(if (~iso (convert-quotes
            '((1:integer <- copy 4:literal)
              foo
              (2:integer <- copy 5:literal)))
          '((1:integer <- copy 4:literal)
            foo
            (2:integer <- copy 5:literal)))
  (prn "F - convert-quotes can handle labels"))

(reset)
(new-trace "before")
(= traces* (queue))
(add-code '((before label1 [
               (2:integer <- copy 0:literal)
             ])))
(if (~iso (as cons before*!label1)
          '(; fragment
            (
              (2:integer <- copy 0:literal))))
  (prn "F - 'before' records fragments of code to insert before labels"))

(if (~iso (insert-code
            '((1:integer <- copy 0:literal)
              label1
              (3:integer <- copy 0:literal)))
          '((1:integer <- copy 0:literal)
            (2:integer <- copy 0:literal)
            label1
            (3:integer <- copy 0:literal)))
  (prn "F - 'insert-code' can insert fragments before labels"))

(reset)
(new-trace "before-multiple")
(= traces* (queue))
(add-code '((before label1 [
               (2:integer <- copy 0:literal)
             ])
            (before label1 [
              (3:integer <- copy 0:literal)
             ])))
(if (~iso (as cons before*!label1)
          '(; fragment
            (
              (2:integer <- copy 0:literal))
            (
              (3:integer <- copy 0:literal))))
  (prn "F - 'before' records fragments in order"))

(if (~iso (insert-code
            '((1:integer <- copy 0:literal)
              label1
              (4:integer <- copy 0:literal)))
          '((1:integer <- copy 0:literal)
            (2:integer <- copy 0:literal)
            (3:integer <- copy 0:literal)
            label1
            (4:integer <- copy 0:literal)))
  (prn "F - 'insert-code' can insert multiple fragments in order before label"))

(reset)
(new-trace "before-scoped")
(= traces* (queue))
(add-code '((before f/label1 [  ; label1 only inside function f
               (2:integer <- copy 0:literal)
             ])))
(if (~iso (insert-code
            '((1:integer <- copy 0:literal)
              label1
              (3:integer <- copy 0:literal))
            'f)
          '((1:integer <- copy 0:literal)
            (2:integer <- copy 0:literal)
            label1
            (3:integer <- copy 0:literal)))
  (prn "F - 'insert-code' can insert fragments before labels just in specified functions"))

(reset)
(new-trace "before-scoped2")
(= traces* (queue))
(add-code '((before f/label1 [  ; label1 only inside function f
               (2:integer <- copy 0:literal)
             ])))
(if (~iso (insert-code
            '((1:integer <- copy 0:literal)
              label1
              (3:integer <- copy 0:literal)))
          '((1:integer <- copy 0:literal)
            label1
            (3:integer <- copy 0:literal)))
  (prn "F - 'insert-code' ignores labels not in specified functions"))

(reset)
(new-trace "after")
(= traces* (queue))
(add-code '((after label1 [
               (2:integer <- copy 0:literal)
             ])))
(if (~iso (as cons after*!label1)
          '(; fragment
            (
              (2:integer <- copy 0:literal))))
  (prn "F - 'after' records fragments of code to insert after labels"))

(if (~iso (insert-code
            '((1:integer <- copy 0:literal)
              label1
              (3:integer <- copy 0:literal)))
          '((1:integer <- copy 0:literal)
            label1
            (2:integer <- copy 0:literal)
            (3:integer <- copy 0:literal)))
  (prn "F - 'insert-code' can insert fragments after labels"))

(reset)
(new-trace "after-multiple")
(= traces* (queue))
(add-code '((after label1 [
               (2:integer <- copy 0:literal)
             ])
            (after label1 [
              (3:integer <- copy 0:literal)
             ])))
(if (~iso (as cons after*!label1)
          '(; fragment
            (
              (3:integer <- copy 0:literal))
            (
              (2:integer <- copy 0:literal))))
  (prn "F - 'after' records fragments in *reverse* order"))

(if (~iso (insert-code
            '((1:integer <- copy 0:literal)
              label1
              (4:integer <- copy 0:literal)))
          '((1:integer <- copy 0:literal)
            label1
            (3:integer <- copy 0:literal)
            (2:integer <- copy 0:literal)
            (4:integer <- copy 0:literal)))
  (prn "F - 'insert-code' can insert multiple fragments in order after label"))

(reset)
(new-trace "before-after")
(= traces* (queue))
(add-code '((before label1 [
               (2:integer <- copy 0:literal)
             ])
            (after label1 [
              (3:integer <- copy 0:literal)
             ])))
(if (and (~iso (as cons before*!label1)
               '(; fragment
                 (
                   (2:integer <- copy 0:literal))))
         (~iso (as cons after*!label1)
               '(; fragment
                 (
                   (3:integer <- copy 0:literal)))))
  (prn "F - 'before' and 'after' fragments work together"))

(if (~iso (insert-code
            '((1:integer <- copy 0:literal)
              label1
              (4:integer <- copy 0:literal)))
          '((1:integer <- copy 0:literal)
            (2:integer <- copy 0:literal)
            label1
            (3:integer <- copy 0:literal)
            (4:integer <- copy 0:literal)))
  (prn "F - 'insert-code' can insert multiple fragments around label"))

(reset)
(new-trace "before-after-multiple")
(= traces* (queue))
(add-code '((before label1 [
               (2:integer <- copy 0:literal)
               (3:integer <- copy 0:literal)
             ])
            (after label1 [
              (4:integer <- copy 0:literal)
             ])
            (before label1 [
              (5:integer <- copy 0:literal)
             ])
            (after label1 [
              (6:integer <- copy 0:literal)
              (7:integer <- copy 0:literal)
             ])))
(if (or (~iso (as cons before*!label1)
              '(; fragment
                (
                  (2:integer <- copy 0:literal)
                  (3:integer <- copy 0:literal))
                (
                  (5:integer <- copy 0:literal))))
        (~iso (as cons after*!label1)
              '(; fragment
                (
                  (6:integer <- copy 0:literal)
                  (7:integer <- copy 0:literal))
                (
                  (4:integer <- copy 0:literal)))))
  (prn "F - multiple 'before' and 'after' fragments at once"))

(if (~iso (insert-code
            '((1:integer <- copy 0:literal)
              label1
              (8:integer <- copy 0:literal)))
          '((1:integer <- copy 0:literal)
            (2:integer <- copy 0:literal)
            (3:integer <- copy 0:literal)
            (5:integer <- copy 0:literal)
            label1
            (6:integer <- copy 0:literal)
            (7:integer <- copy 0:literal)
            (4:integer <- copy 0:literal)
            (8:integer <- copy 0:literal)))
  (prn "F - 'insert-code' can insert multiple fragments around label - 2"))

(reset)
(new-trace "before-after-independent")
(= traces* (queue))
(if (~iso (do
            (reset)
            (add-code '((before label1 [
                           (2:integer <- copy 0:literal)
                         ])
                        (after label1 [
                          (3:integer <- copy 0:literal)
                         ])
                        (before label1 [
                          (4:integer <- copy 0:literal)
                         ])
                        (after label1 [
                          (5:integer <- copy 0:literal)
                         ])))
            (list before*!label1 after*!label1))
          (do
            (reset)
            (add-code '((before label1 [
                           (2:integer <- copy 0:literal)
                         ])
                        (before label1 [
                          (4:integer <- copy 0:literal)
                         ])
                        (after label1 [
                          (3:integer <- copy 0:literal)
                         ])
                        (after label1 [
                          (5:integer <- copy 0:literal)
                         ])))
            (list before*!label1 after*!label1)))
  (prn "F - order matters between 'before' and between 'after' fragments, but not *across* 'before' and 'after' fragments"))

(reset)
(new-trace "before-after-braces")
(= traces* (queue))
(= function* (table))
(add-code '((after label1 [
               (1:integer <- copy 0:literal)
             ])
            (function f1 [
              { begin
                label1
              }
             ])))
;? (= dump-trace* (obj whitelist '("cn0")))
(freeze-functions)
(if (~iso function*!f1
          '(label1
            (((1 integer)) <- ((copy)) ((0 literal)))))
  (prn "F - before/after works inside blocks"))

(reset)
(new-trace "before-after-any-order")
(= traces* (queue))
(= function* (table))
(add-code '((function f1 [
              { begin
                label1
              }
             ])
            (after label1 [
               (1:integer <- copy 0:literal)
             ])))
(freeze-functions)
(if (~iso function*!f1
          '(label1
            (((1 integer)) <- ((copy)) ((0 literal)))))
  (prn "F - before/after can come after the function they need to modify"))
;? (quit)

(reset)
(new-trace "multiple-defs")
(= traces* (queue))
(= function* (table))
(add-code '((function f1 [
              (1:integer <- copy 0:literal)
             ])
            (function f1 [
              (2:integer <- copy 0:literal)
             ])))
(freeze-functions)
(if (~iso function*!f1
          '((((2 integer)) <- ((copy)) ((0 literal)))
            (((1 integer)) <- ((copy)) ((0 literal)))))
  (prn "F - multiple 'def' of the same function add clauses"))

(reset)
(new-trace "def!")
(= traces* (queue))
(= function* (table))
(add-code '((function f1 [
              (1:integer <- copy 0:literal)
             ])
            (function! f1 [
              (2:integer <- copy 0:literal)
             ])))
(freeze-functions)
(if (~iso function*!f1
          '((((2 integer)) <- ((copy)) ((0 literal)))))
  (prn "F - 'def!' clears all previous clauses"))

)  ; section 10

;; ---

(section 100  ; string utilities

(reset)
(new-trace "string-new")
(add-code '((function main [
              ((1 string-address) <- new (string literal) (5 literal))
             ])))
(let routine make-routine!main
  (enq routine running-routines*)
  (let before rep.routine!alloc
    (run)
    (if (~iso rep.routine!alloc (+ before 5 1))
      (prn "F - 'new' allocates arrays of bytes for strings"))))

; Convenience: initialize strings using string literals
(reset)
(new-trace "string-literal")
(add-code '((function main [
              ((1 string-address) <- new "hello")
             ])))
(let routine make-routine!main
  (enq routine running-routines*)
  (let before rep.routine!alloc
    (run)
    (if (~iso rep.routine!alloc (+ before 5 1))
      (prn "F - 'new' allocates arrays of bytes for string literals"))
    (if (~memory-contains-array before "hello")
      (prn "F - 'new' initializes allocated memory to string literal"))))

(reset)
(new-trace "strcat")
(add-code '((function main [
              ((1 string-address) <- new "hello,")
              ((2 string-address) <- new " world!")
              ((3 string-address) <- strcat (1 string-address) (2 string-address))
             ])))
(run 'main)
(if (~memory-contains-array memory*.3 "hello, world!")
  (prn "F - 'strcat' concatenates strings"))

(reset)
(new-trace "interpolate")
(add-code '((function main [
              ((1 string-address) <- new "hello, _!")
              ((2 string-address) <- new "abc")
              ((3 string-address) <- interpolate (1 string-address) (2 string-address))
             ])))
;? (= dump-trace* (obj whitelist '("run")))
(run 'main)
(if (~memory-contains-array memory*.3 "hello, abc!")
  (prn "F - 'interpolate' splices strings"))

(reset)
(new-trace "interpolate-empty")
(add-code '((function main [
              ((1 string-address) <- new "hello!")
              ((2 string-address) <- new "abc")
              ((3 string-address) <- interpolate (1 string-address) (2 string-address))
             ])))
;? (= dump-trace* (obj whitelist '("run")))
(run 'main)
(if (~memory-contains-array memory*.3 "hello!")
  (prn "F - 'interpolate' without underscore returns template"))

(reset)
(new-trace "interpolate-at-start")
(add-code '((function main [
              ((1 string-address) <- new "_, hello!")
              ((2 string-address) <- new "abc")
              ((3 string-address) <- interpolate (1 string-address) (2 string-address))
             ])))
;? (= dump-trace* (obj whitelist '("run")))
(run 'main)
(if (~memory-contains-array memory*.3 "abc, hello")
  (prn "F - 'interpolate' splices strings at start"))

(reset)
(new-trace "interpolate-at-end")
(add-code '((function main [
              ((1 string-address) <- new "hello, _")
              ((2 string-address) <- new "abc")
              ((3 string-address) <- interpolate (1 string-address) (2 string-address))
             ])))
;? (= dump-trace* (obj whitelist '("run")))
(run 'main)
(if (~memory-contains-array memory*.3 "hello, abc")
  (prn "F - 'interpolate' splices strings at start"))

(reset)
(new-trace "interpolate-varargs")
(add-code '((function main [
              ((1 string-address) <- new "hello, _, _, and _!")
              ((2 string-address) <- new "abc")
              ((3 string-address) <- new "def")
              ((4 string-address) <- new "ghi")
              ((5 string-address) <- interpolate (1 string-address) (2 string-address) (3 string-address) (4 string-address))
             ])))
;? (= dump-trace* (obj whitelist '("run")))
;? (= dump-trace* (obj whitelist '("run" "array-info")))
;? (set dump-trace*)
(run 'main)
;? (quit)
;? (up i 1 (+ 1 (memory* memory*.5))
;?   (prn (memory* (+ memory*.5 i))))
(if (~memory-contains-array memory*.5 "hello, abc, def, and ghi!")
  (prn "F - 'interpolate' splices in any number of strings"))

)  ; section 100 for string utilities

;; unit tests for various helpers

; tokenize-args
(prn "tokenize-args")
(assert:iso '((a b) (c d))
            (tokenize-arg 'a:b/c:d))
(assert:iso '((a b) (1 d))
            (tokenize-arg 'a:b/1:d))
(assert:iso '<-
            (tokenize-arg '<-))
(assert:iso '_
            (tokenize-arg '_))

; support labels
(assert:iso '((((default-scope scope-address)) <- ((new)) ((scope literal)) ((30 literal)))
              foo)
            (tokenize-args
              '((default-scope:scope-address <- new scope:literal 30:literal)
                foo)))

; support braces
(assert:iso '((((default-scope scope-address)) <- ((new)) ((scope literal)) ((30 literal)))
              foo
              { begin
                bar
                (((a b)) <- ((op)) ((c d)) ((e f)))
              })
            (tokenize-args
              '((default-scope:scope-address <- new scope:literal 30:literal)
                foo
                { begin
                  bar
                  (a:b <- op c:d e:f)
                })))

; absolutize
(prn "absolutize")
(reset)
(if (~iso '((4 integer)) (absolutize '((4 integer))))
  (prn "F - 'absolutize' works without routine"))
(= routine* make-routine!foo)
(if (~iso '((4 integer)) (absolutize '((4 integer))))
  (prn "F - 'absolutize' works without default-scope"))
(= rep.routine*!call-stack.0!default-scope 10)
(= memory*.10 5)  ; bounds check for default-scope
(if (~iso '((14 integer) (global))
          (absolutize '((4 integer))))
  (prn "F - 'absolutize' works with default-scope"))
(absolutize '((5 integer)))
(if (~posmatch "no room" rep.routine*!error)
  (prn "F - 'absolutize' checks against default-scope bounds"))

; addr
(prn "addr")
(reset)
(= routine* nil)
;? (prn 111)
(if (~is 4 (addr '((4 integer))))
  (prn "F - directly addressed operands are their own address"))
;? (quit)
(if (~is 4 (addr '((4 integer-address))))
  (prn "F - directly addressed operands are their own address - 2"))
(if (~is 4 (addr '((4 literal))))
  (prn "F - 'addr' doesn't understand literals"))
;? (prn 201)
(= memory*.4 23)
;? (prn 202)
(if (~is 23 (addr '((4 integer-address) (deref))))
  (prn "F - 'addr' works with indirectly-addressed 'deref'"))
;? (quit)
(= memory*.3 4)
(if (~is 23 (addr '((3 integer-address-address) (deref) (deref))))
  (prn "F - 'addr' works with multiple 'deref'"))

(= routine* make-routine!foo)
(if (~is 4 (addr '((4 integer))))
  (prn "F - directly addressed operands are their own address inside routines"))
(if (~is 4 (addr '((4 integer-address))))
  (prn "F - directly addressed operands are their own address inside routines - 2"))
(if (~is 4 (addr '((4 literal))))
  (prn "F - 'addr' doesn't understand literals inside routines"))
(= memory*.4 23)
(if (~is 23 (addr '((4 integer-address) (deref))))
  (prn "F - 'addr' works with indirectly-addressed 'deref' inside routines"))

;? (prn 301)
(= rep.routine*!call-stack.0!default-scope 10)
;? (prn 302)
(= memory*.10 5)  ; bounds check for default-scope
;? (prn 303)
(if (~is 14 (addr '((4 integer))))
  (prn "F - directly addressed operands in routines add default-scope"))
;? (quit)
(if (~is 14 (addr '((4 integer-address))))
  (prn "F - directly addressed operands in routines add default-scope - 2"))
(if (~is 14 (addr '((4 literal))))
  (prn "F - 'addr' doesn't understand literals"))
(= memory*.14 23)
(if (~is 23 (addr '((4 integer-address) (deref))))
  (prn "F - 'addr' adds default-scope before 'deref', not after"))
;? (quit)

; deref
(prn "deref")
(reset)
(= memory*.3 4)
(if (~iso '((4 integer))
          (deref '((3 integer-address)
                   (deref))))
  (prn "F - 'deref' handles simple addresses"))
(if (~iso '((4 integer) (deref))
          (deref '((3 integer-address)
                   (deref)
                   (deref))))
  (prn "F - 'deref' deletes just one deref"))
(= memory*.4 5)
(if (~iso '((5 integer))
          (deref:deref '((3 integer-address-address)
                         (deref)
                         (deref))))
  (prn "F - 'deref' can be chained"))

; array-len
(prn "array-len")
(reset)
(= memory*.35 4)
(if (~is 4 (array-len '((35 integer-boolean-pair-array))))
  (prn "F - 'array-len'"))
(= memory*.34 35)
(if (~is 4 (array-len '((34 integer-boolean-pair-array-address) (deref))))
  (prn "F - 'array-len'"))
;? (quit)

; sizeof
(prn "sizeof")
(reset)
;? (prn 401)
(if (~is 1 sizeof!integer)
  (prn "F - 'sizeof' works on primitives"))
(if (~is 1 sizeof!integer-address)
  (prn "F - 'sizeof' works on addresses"))
(if (~is 2 sizeof!integer-boolean-pair)
  (prn "F - 'sizeof' works on records"))
(if (~is 3 sizeof!integer-point-pair)
  (prn "F - 'sizeof' works on records with record fields"))

;? (prn 410)
(if (~is 1 (sizeof '((34 integer))))
  (prn "F - 'sizeof' works on primitive operands"))
(if (~is 1 (sizeof '((34 integer-address))))
  (prn "F - 'sizeof' works on address operands"))
(if (~is 2 (sizeof '((34 integer-boolean-pair))))
  (prn "F - 'sizeof' works on record operands"))
(if (~is 3 (sizeof '((34 integer-point-pair))))
  (prn "F - 'sizeof' works on record operands with record fields"))
(if (~is 2 (sizeof '((34 integer-boolean-pair-address) (deref))))
  (prn "F - 'sizeof' works on pointers to records"))
(= memory*.35 4)  ; size of array
(= memory*.34 35)
;? (= dump-trace* (obj whitelist '("sizeof" "array-len")))
(if (~is 9 (sizeof '((34 integer-boolean-pair-array-address) (deref))))
  (prn "F - 'sizeof' works on pointers to arrays"))
;? (quit)

;? (prn 420)
(= memory*.4 23)
(if (~is 24 (sizeof '((4 integer-array))))
  (prn "F - 'sizeof' reads array lengths from memory"))
(= memory*.3 4)
(if (~is 24 (sizeof '((3 integer-array-address) (deref))))
  (prn "F - 'sizeof' handles pointers to arrays"))
(= memory*.14 34)
(= routine* make-routine!foo)
(if (~is 24 (sizeof '((4 integer-array))))
  (prn "F - 'sizeof' reads array lengths from memory inside routines"))
(= rep.routine*!call-stack.0!default-scope 10)
(= memory*.10 5)  ; bounds check for default-scope
(if (~is 35 (sizeof '((4 integer-array))))
  (prn "F - 'sizeof' reads array lengths from memory using default-scope"))
(= memory*.35 4)  ; size of array
(= memory*.14 35)
;? (= dump-trace* (obj whitelist '("sizeof")))
(aif rep.routine*!error (prn "error - " it))
(if (~is 9 (sizeof '((4 integer-boolean-pair-array-address) (deref))))
  (prn "F - 'sizeof' works on pointers to arrays using default-scope"))
;? (quit)

; m
(prn "m")
(reset)
(if (~is 4 (m '((4 literal))))
  (prn "F - 'm' avoids reading memory for literals"))
(if (~is 4 (m '((4 offset))))
  (prn "F - 'm' avoids reading memory for offsets"))
(= memory*.4 34)
(if (~is 34 (m '((4 integer))))
  (prn "F - 'm' reads memory for simple types"))
(= memory*.3 4)
(if (~is 34 (m '((3 integer-address) (deref))))
  (prn "F - 'm' redirects addresses"))
(= memory*.2 3)
(if (~is 34 (m '((2 integer-address-address) (deref) (deref))))
  (prn "F - 'm' multiply redirects addresses"))
(if (~iso (annotate 'record '(34 nil)) (m '((4 integer-boolean-pair))))
  (prn "F - 'm' supports compound records"))
(= memory*.5 35)
(= memory*.6 36)
(if (~iso (annotate 'record '(34 35 36)) (m '((4 integer-point-pair))))
  (prn "F - 'm' supports records with compound fields"))
(if (~iso (annotate 'record '(34 35 36)) (m '((3 integer-point-pair-address) (deref))))
  (prn "F - 'm' supports indirect access to records"))
(= memory*.4 2)
(if (~iso (annotate 'record '(2 35 36)) (m '((4 integer-array))))
  (prn "F - 'm' supports access to arrays"))
(if (~iso (annotate 'record '(2 35 36)) (m '((3 integer-array-address) (deref))))
  (prn "F - 'm' supports indirect access to arrays"))

; setm
(prn "setm")
(reset)
(setm '((4 integer)) 34)
(if (~is 34 memory*.4)
  (prn "F - 'setm' writes primitives to memory"))
(setm '((3 integer-address)) 4)
(if (~is 4 memory*.3)
  (prn "F - 'setm' writes addresses to memory"))
(setm '((3 integer-address) (deref)) 35)
(if (~is 35 memory*.4)
  (prn "F - 'setm' redirects writes"))
(= memory*.2 3)
(setm '((2 integer-address-address) (deref) (deref)) 36)
(if (~is 36 memory*.4)
  (prn "F - 'setm' multiply redirects writes"))
;? (prn 505)
(setm '((4 integer-integer-pair)) (annotate 'record '(23 24)))
(if (~memory-contains 4 '(23 24))
  (prn "F - 'setm' writes compound records"))
(assert (is memory*.7 nil))
;? (prn 506)
(setm '((7 integer-point-pair)) (annotate 'record '(23 24 25)))
(if (~memory-contains 7 '(23 24 25))
  (prn "F - 'setm' writes records with compound fields"))
(= routine* make-routine!foo)
(setm '((4 integer-point-pair)) (annotate 'record '(33 34)))
(if (~posmatch "incorrect size" rep.routine*!error)
  (prn "F - 'setm' checks size of target"))
(wipe routine*)
(setm '((3 integer-point-pair-address) (deref)) (annotate 'record '(43 44 45)))
(if (~memory-contains 4 '(43 44 45))
  (prn "F - 'setm' supports indirect writes to records"))
(setm '((2 integer-point-pair-address-address) (deref) (deref)) (annotate 'record '(53 54 55)))
(if (~memory-contains 4 '(53 54 55))
  (prn "F - 'setm' supports multiply indirect writes to records"))
(setm '((4 integer-array)) (annotate 'record '(2 31 32)))
(if (~memory-contains 4 '(2 31 32))
  (prn "F - 'setm' writes arrays"))
(setm '((3 integer-array-address) (deref)) (annotate 'record '(2 41 42)))
(if (~memory-contains 4 '(2 41 42))
  (prn "F - 'setm' supports indirect writes to arrays"))
(= routine* make-routine!foo)
(setm '((4 integer-array)) (annotate 'record '(2 31 32 33)))
(if (~posmatch "invalid array" rep.routine*!error)
  (prn "F - 'setm' checks that array written is well-formed"))
(= routine* make-routine!foo)
;? (prn 111)
;? (= dump-trace* (obj whitelist '("sizeof" "setm")))
(setm '((4 integer-boolean-pair-array)) (annotate 'record '(2 31 nil 32 nil 33)))
(if (~posmatch "invalid array" rep.routine*!error)
  (prn "F - 'setm' checks that array of records is well-formed"))
(= routine* make-routine!foo)
;? (prn 222)
(setm '((4 integer-boolean-pair-array)) (annotate 'record '(2 31 nil 32 nil)))
(if (posmatch "invalid array" rep.routine*!error)
  (prn "F - 'setm' checks that array of records is well-formed - 2"))
(wipe routine*)

(reset)  ; end file with this to persist the trace for the final test
