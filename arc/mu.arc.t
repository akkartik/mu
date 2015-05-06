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
(ero "running tests in mu.ar.c.t (takes ~30s)")
;? (quit)

(set allow-raw-addresses*)

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
; idealized syntax above. For now they will look like this:
;
;   (function f [
;     (oarg1 oarg2 ... <- op arg1 arg2 ...)
;     ...
;     ...
;    ])
;
; Each arg/oarg can contain metadata separated by slashes and colons. In this
; first example below, the only metadata is types: 'integer' for a memory
; location containing an integer, and 'literal' for a value included directly
; in code. (Assembly languages traditionally call them 'immediate' operands.)
; In the future a simple tool will check that the types line up as expected in
; each op. A different tool might add types where they aren't provided.
; Instead of a monolithic compiler I want to build simple, lightweight tools
; that can be combined in various ways, say for using different typecheckers
; in different subsystems.
;
; In our tests we'll define such mu functions using a call to 'add-code', so
; look for it when reading the code examples. Everything outside 'add-code' is
; just test-harness details that can be skipped at first.

(reset)
;? (set dump-trace*)
(new-trace "literal")
(add-code
  '((function main [
      (1:integer <- copy 23:literal)
     ])))
;? (set dump-trace*)
(run 'main)
;? (prn memory*)
(when (~is memory*.1 23)
  (prn "F - 'copy' writes its lone 'arg' after the instruction name to its lone 'oarg' or output arg before the arrow. After this test, the value 23 is stored in memory address 1."))
;? (reset) ;? 2
;? (quit) ;? 2

; Our basic arithmetic ops can operate on memory locations or literals.
; (Ignore hardware details like registers for now.)

(reset)
(new-trace "add")
(add-code
  '((function main [
      (1:integer <- copy 1:literal)
      (2:integer <- copy 3:literal)
      (3:integer <- add 1:integer 2:integer)
     ])))
(run 'main)
;? (prn memory*)
(when (~iso memory* (obj 1 1  2 3  3 4))
  (prn "F - 'add' operates on two addresses"))
;? (reset) ;? 1
;? (quit) ;? 1

(reset)
(new-trace "add-literal")
(add-code
  '((function main [
      (1:integer <- add 2:literal 3:literal)
     ])))
(run 'main)
(when (~is memory*.1 5)
  (prn "F - ops can take 'literal' operands (but not return them)"))

(reset)
(new-trace "sub-literal")
(add-code
  '((function main [
      (1:integer <- subtract 1:literal 3:literal)
     ])))
(run 'main)
;? (prn memory*)
(when (~is memory*.1 -2)
  (prn "F - 'subtract'"))

(reset)
(new-trace "mul-literal")
(add-code
  '((function main [
      (1:integer <- multiply 2:literal 3:literal)
     ])))
(run 'main)
;? (prn memory*)
(when (~is memory*.1 6)
  (prn "F - 'multiply'"))

(reset)
(new-trace "div-literal")
(add-code
  '((function main [
      (1:integer <- divide 8:literal 3:literal)
     ])))
(run 'main)
;? (prn memory*)
(when (~is memory*.1 (/ real.8 3))
  (prn "F - 'divide'"))

(reset)
(new-trace "idiv-literal")
(add-code
  '((function main [
      (1:integer 2:integer <- divide-with-remainder 23:literal 6:literal)
     ])))
(run 'main)
;? (prn memory*)
(when (~iso memory* (obj 1 3  2 5))
  (prn "F - 'divide-with-remainder' performs integer division"))

(reset)
(new-trace "dummy-oarg")
;? (set dump-trace*)
(add-code
  '((function main [
      (_ 2:integer <- divide-with-remainder 23:literal 6:literal)
     ])))
(run 'main)
(when (~iso memory* (obj 2 5))
  (prn "F - '_' oarg can ignore some results"))
;? (quit)

; Basic boolean operations: and, or, not
; There are easy ways to encode booleans in binary, but we'll skip past those
; details for now.

(reset)
(new-trace "and-literal")
(add-code
  '((function main [
      (1:boolean <- and t:literal nil:literal)
     ])))
;? (set dump-trace*)
(run 'main)
;? (prn memory*)
(when (~is memory*.1 nil)
  (prn "F - logical 'and' for booleans"))

; Basic comparison operations

(reset)
(new-trace "lt-literal")
(add-code
  '((function main [
      (1:boolean <- less-than 4:literal 3:literal)
     ])))
(run 'main)
;? (prn memory*)
(when (~is memory*.1 nil)
  (prn "F - 'less-than' inequality operator"))

(reset)
(new-trace "le-literal-false")
(add-code
  '((function main [
      (1:boolean <- lesser-or-equal 4:literal 3:literal)
     ])))
(run 'main)
;? (prn memory*)
(when (~is memory*.1 nil)
  (prn "F - 'lesser-or-equal'"))

(reset)
(new-trace "le-literal-true")
(add-code
  '((function main [
      (1:boolean <- lesser-or-equal 4:literal 4:literal)
     ])))
(run 'main)
;? (prn memory*)
(when (~is memory*.1 t)
  (prn "F - 'lesser-or-equal' returns true for equal operands"))

(reset)
(new-trace "le-literal-true-2")
(add-code
  '((function main [
      (1:boolean <- lesser-or-equal 4:literal 5:literal)
     ])))
(run 'main)
;? (prn memory*)
(when (~is memory*.1 t)
  (prn "F - 'lesser-or-equal' - 2"))

; Control flow operations: jump, jump-if, jump-unless
; These introduce a new type -- 'offset' -- for literals that refer to memory
; locations relative to the current location.

(reset)
(new-trace "jump-skip")
(add-code
  '((function main [
      (1:integer <- copy 8:literal)
      (jump 1:offset)
      (2:integer <- copy 3:literal)  ; should be skipped
      (reply)
     ])))
;? (set dump-trace*)
(run 'main)
;? (prn memory*)
(when (~iso memory* (obj 1 8))
  (prn "F - 'jump' skips some instructions"))
;? (quit)

(reset)
(new-trace "jump-target")
(add-code
  '((function main [
      (1:integer <- copy 8:literal)
      (jump 1:offset)
      (2:integer <- copy 3:literal)  ; should be skipped
      (reply)
      (3:integer <- copy 34:literal)
     ])))  ; never reached
(run 'main)
;? (prn memory*)
(when (~iso memory* (obj 1 8))
  (prn "F - 'jump' doesn't skip too many instructions"))
;? (quit)

(reset)
(new-trace "jump-if-skip")
(add-code
  '((function main [
      (2:integer <- copy 1:literal)
      (1:boolean <- equal 1:literal 2:integer)
      (jump-if 1:boolean 1:offset)
      (2:integer <- copy 3:literal)
      (reply)
      (3:integer <- copy 34:literal)
     ])))
(run 'main)
;? (prn memory*)
(when (~iso memory* (obj 1 t  2 1))
  (prn "F - 'jump-if' is a conditional 'jump'"))

(reset)
(new-trace "jump-if-fallthrough")
(add-code
  '((function main [
      (1:boolean <- equal 1:literal 2:literal)
      (jump-if 3:boolean 1:offset)
      (2:integer <- copy 3:literal)
      (reply)
      (3:integer <- copy 34:literal)
     ])))
(run 'main)
;? (prn memory*)
(when (~iso memory* (obj 1 nil  2 3))
  (prn "F - if 'jump-if's first arg is false, it doesn't skip any instructions"))

(reset)
(new-trace "jump-if-backward")
(add-code
  '((function main [
      (1:integer <- copy 2:literal)
      (2:integer <- copy 1:literal)
      ; loop
      (2:integer <- add 2:integer 2:integer)
      (3:boolean <- equal 1:integer 2:integer)
      (jump-if 3:boolean -3:offset)  ; to loop
      (4:integer <- copy 3:literal)
      (reply)
      (3:integer <- copy 34:literal)
     ])))
(run 'main)
;? (prn memory*)
(when (~iso memory* (obj 1 2  2 4  3 nil  4 3))
  (prn "F - 'jump-if' can take a negative offset to make backward jumps"))

(reset)
(new-trace "jump-label")
(add-code
  '((function main [
      (1:integer <- copy 2:literal)
      (2:integer <- copy 1:literal)
      loop
      (2:integer <- add 2:integer 2:integer)
      (3:boolean <- equal 1:integer 2:integer)
      (jump-if 3:boolean loop:offset)
      (4:integer <- copy 3:literal)
      (reply)
      (3:integer <- copy 34:literal)
     ])))
;? (set dump-trace*)
;? (= dump-trace* (obj whitelist '("-")))
(run 'main)
;? (prn memory*)
(when (~iso memory* (obj 1 2  2 4  3 nil  4 3))
  (prn "F - 'jump-if' can take a negative offset to make backward jumps"))
;? (quit)

; Data movement relies on addressing modes:
;   'direct' - refers to a memory location; default for most types.
;   'literal' - directly encoded in the code; implicit for some types like 'offset'.

(reset)
(new-trace "direct-addressing")
(add-code
  '((function main [
      (1:integer <- copy 34:literal)
      (2:integer <- copy 1:integer)
     ])))
(run 'main)
;? (prn memory*)
(when (~iso memory* (obj 1 34  2 34))
  (prn "F - 'copy' performs direct addressing"))

; 'Indirect' addressing refers to an address stored in a memory location.
; Indicated by the metadata '/deref'. Usually requires an address type.
; In the test below, the memory location 1 contains '2', so an indirect read
; of location 1 returns the value of location 2.

(reset)
(new-trace "indirect-addressing")
(add-code
  '((function main [
      (1:integer-address <- copy 2:literal)  ; unsafe; can't do this in general
      (2:integer <- copy 34:literal)
      (3:integer <- copy 1:integer-address/deref)
     ])))
(run 'main)
;? (prn memory*)
(when (~iso memory* (obj 1 2  2 34  3 34))
  (prn "F - 'copy' performs indirect addressing"))

; Output args can use indirect addressing. In the test below the value is
; stored at the location stored in location 1 (i.e. location 2).

(reset)
(new-trace "indirect-addressing-oarg")
(add-code
  '((function main [
      (1:integer-address <- copy 2:literal)
      (2:integer <- copy 34:literal)
      (1:integer-address/deref <- add 2:integer 2:literal)
     ])))
(run 'main)
;? (prn memory*)
(when (~iso memory* (obj 1 2  2 36))
  (prn "F - instructions can perform indirect addressing on output arg"))

;; Compound data types
;
; Until now we've dealt with scalar types like integers and booleans and
; addresses, where mu looks like other assembly languages. In addition, mu
; provides first-class support for compound types: arrays and and-records.
;
; 'get' accesses fields in and-records
; 'index' accesses indices in arrays
;
; Both operations require knowledge about the types being worked on, so all
; types used in mu programs are defined in a single global system-wide table
; (see type* in mu.arc for the complete list of types; we'll add to it over
; time).

; first a sanity check that the table of types is consistent
(reset)
(each (typ typeinfo) type*
  (when typeinfo!and-record
    (assert (is typeinfo!size (len typeinfo!elems)))
    (when typeinfo!fields
      (assert (is typeinfo!size (len typeinfo!fields))))))

(reset)
(new-trace "get-record")
(add-code
  '((function main [
      (1:integer <- copy 34:literal)
      (2:boolean <- copy nil:literal)
      (3:boolean <- get 1:integer-boolean-pair 1:offset)
      (4:integer <- get 1:integer-boolean-pair 0:offset)
     ])))
;? (set dump-trace*)
(run 'main)
;? (prn memory*)
(when (~iso memory* (obj 1 34  2 nil  3 nil  4 34))
  (prn "F - 'get' accesses fields of and-records"))
;? (quit)

(reset)
(new-trace "get-indirect")
(add-code
  '((function main [
      (1:integer <- copy 34:literal)
      (2:boolean <- copy nil:literal)
      (3:integer-boolean-pair-address <- copy 1:literal)
      (4:boolean <- get 3:integer-boolean-pair-address/deref 1:offset)
      (5:integer <- get 3:integer-boolean-pair-address/deref 0:offset)
     ])))
;? (set dump-trace*)
(run 'main)
;? (prn memory*)
(when (~iso memory* (obj 1 34  2 nil  3 1  4 nil  5 34))
  (prn "F - 'get' accesses fields of and-record address"))

(reset)
(new-trace "get-indirect-repeated")
(add-code
  '((function main [
      (1:integer <- copy 34:literal)
      (2:integer <- copy 35:literal)
      (3:integer <- copy 36:literal)
      (4:integer-point-pair-address <- copy 1:literal)  ; unsafe
      (5:integer-point-pair-address-address <- copy 4:literal)  ; unsafe
      (6:integer-integer-pair <- get 5:integer-point-pair-address-address/deref/deref 1:offset)
      (8:integer <- get 5:integer-point-pair-address-address/deref/deref 0:offset)
     ])))
(run 'main)
(when (~memory-contains 6 '(35 36 34))
  (prn "F - 'get' can deref multiple times"))
;? (quit)

(reset)
(new-trace "get-compound-field")
(add-code
  '((function main [
      (1:integer <- copy 34:literal)
      (2:integer <- copy 35:literal)
      (3:integer <- copy 36:literal)
      (4:integer-integer-pair <- get 1:integer-point-pair 1:offset)
     ])))
(run 'main)
;? (prn memory*)
(when (~iso memory* (obj 1 34  2 35  3 36  4 35  5 36))
  (prn "F - 'get' accesses fields spanning multiple locations"))

(reset)
(new-trace "get-address")
(add-code
  '((function main [
      (1:integer <- copy 34:literal)
      (2:boolean <- copy t:literal)
      (3:boolean-address <- get-address 1:integer-boolean-pair 1:offset)
     ])))
(run 'main)
;? (prn memory*)
(when (~iso memory* (obj 1 34  2 t  3 2))
  (prn "F - 'get-address' returns address of fields of and-records"))

(reset)
(new-trace "get-address-indirect")
(add-code
  '((function main [
      (1:integer <- copy 34:literal)
      (2:boolean <- copy t:literal)
      (3:integer-boolean-pair-address <- copy 1:literal)
      (4:boolean-address <- get-address 3:integer-boolean-pair-address/deref 1:offset)
     ])))
(run 'main)
;? (prn memory*)
(when (~iso memory* (obj 1 34  2 t  3 1  4 2))
  (prn "F - 'get-address' accesses fields of and-record address"))

(reset)
(new-trace "index-literal")
(add-code
  '((function main [
      (1:integer <- copy 2:literal)
      (2:integer <- copy 23:literal)
      (3:boolean <- copy nil:literal)
      (4:integer <- copy 24:literal)
      (5:boolean <- copy t:literal)
      (6:integer-boolean-pair <- index 1:integer-boolean-pair-array 1:literal)
     ])))
(run 'main)
;? (prn memory*)
(when (~iso memory* (obj 1 2  2 23 3 nil  4 24 5 t  6 24 7 t))
  (prn "F - 'index' accesses indices of arrays"))
;? (quit)

(reset)
(new-trace "index-direct")
(add-code
  '((function main [
      (1:integer <- copy 2:literal)
      (2:integer <- copy 23:literal)
      (3:boolean <- copy nil:literal)
      (4:integer <- copy 24:literal)
      (5:boolean <- copy t:literal)
      (6:integer <- copy 1:literal)
      (7:integer-boolean-pair <- index 1:integer-boolean-pair-array 6:integer)
     ])))
(run 'main)
;? (prn memory*)
(when (~iso memory* (obj 1 2  2 23 3 nil  4 24 5 t  6 1  7 24 8 t))
  (prn "F - 'index' accesses indices of arrays"))
;? (quit)

(reset)
(new-trace "index-indirect")
(add-code
  '((function main [
      (1:integer <- copy 2:literal)
      (2:integer <- copy 23:literal)
      (3:boolean <- copy nil:literal)
      (4:integer <- copy 24:literal)
      (5:boolean <- copy t:literal)
      (6:integer <- copy 1:literal)
      (7:integer-boolean-pair-array-address <- copy 1:literal)
      (8:integer-boolean-pair <- index 7:integer-boolean-pair-array-address/deref 6:integer)
     ])))
;? (= dump-trace* (obj blacklist '("sz" "mem" "addr" "cvt0" "cvt1")))
;? (set dump-trace*)
(run 'main)
;? (prn memory*)
(when (~iso memory* (obj 1 2  2 23 3 nil  4 24 5 t  6 1  7 1  8 24 9 t))
  (prn "F - 'index' accesses indices of array address"))
;? (quit)

(reset)
(new-trace "index-indirect-multiple")
(add-code
  '((function main [
      (1:integer <- copy 4:literal)
      (2:integer <- copy 23:literal)
      (3:integer <- copy 24:literal)
      (4:integer <- copy 25:literal)
      (5:integer <- copy 26:literal)
      (6:integer-array-address <- copy 1:literal)  ; unsafe
      (7:integer-array-address-address <- copy 6:literal)  ; unsafe
      (8:integer <- index 7:integer-array-address-address/deref/deref 1:literal)
     ])))
(run 'main)
(when (~is memory*.8 24)
  (prn "F - 'index' can deref multiple times"))

(reset)
(new-trace "index-address")
(add-code
  '((function main [
      (1:integer <- copy 2:literal)
      (2:integer <- copy 23:literal)
      (3:boolean <- copy nil:literal)
      (4:integer <- copy 24:literal)
      (5:boolean <- copy t:literal)
      (6:integer <- copy 1:literal)
      (7:integer-boolean-pair-address <- index-address 1:integer-boolean-pair-array 6:integer)
     ])))
(run 'main)
;? (prn memory*)
(when (~iso memory* (obj 1 2  2 23 3 nil  4 24 5 t  6 1  7 4))
  (prn "F - 'index-address' returns addresses of indices of arrays"))

(reset)
(new-trace "index-address-indirect")
(add-code
  '((function main [
      (1:integer <- copy 2:literal)
      (2:integer <- copy 23:literal)
      (3:boolean <- copy nil:literal)
      (4:integer <- copy 24:literal)
      (5:boolean <- copy t:literal)
      (6:integer <- copy 1:literal)
      (7:integer-boolean-pair-array-address <- copy 1:literal)
      (8:integer-boolean-pair-address <- index-address 7:integer-boolean-pair-array-address/deref 6:integer)
     ])))
(run 'main)
;? (prn memory*)
(when (~iso memory* (obj 1 2  2 23 3 nil  4 24 5 t  6 1  7 1  8 4))
  (prn "F - 'index-address' returns addresses of indices of array addresses"))

; Array values know their length. Record lengths are saved in the types table.

(reset)
(new-trace "len-array")
(add-code
  '((function main [
      (1:integer <- copy 2:literal)
      (2:integer <- copy 23:literal)
      (3:boolean <- copy nil:literal)
      (4:integer <- copy 24:literal)
      (5:boolean <- copy t:literal)
      (6:integer <- length 1:integer-boolean-pair-array)
     ])))
(run 'main)
;? (prn memory*)
(when (~is memory*.6 2)
  (prn "F - 'length' of array"))

(reset)
(new-trace "len-array-indirect")
(add-code
  '((function main [
      (1:integer <- copy 2:literal)
      (2:integer <- copy 23:literal)
      (3:boolean <- copy nil:literal)
      (4:integer <- copy 24:literal)
      (5:boolean <- copy t:literal)
      (6:integer-address <- copy 1:literal)
      (7:integer <- length 6:integer-boolean-pair-array-address/deref)
     ])))
;? (set dump-trace*)
;? (= dump-trace* (obj blacklist '("sz" "mem" "addr" "cvt0" "cvt1")))
(run 'main)
;? (prn memory*)
(when (~is memory*.7 2)
  (prn "F - 'length' of array address"))

; 'sizeof' is a helper to determine the amount of memory required by a type.
; Only for non-arrays.

(reset)
(new-trace "sizeof-record")
(add-code
  '((function main [
      (1:integer <- sizeof integer-boolean-pair:literal)
     ])))
(run 'main)
;? (prn memory*)
(when (~is memory*.1 2)
  (prn "F - 'sizeof' returns space required by arg"))

(reset)
(new-trace "sizeof-record-not-len")
(add-code
  '((function main [
      (1:integer <- sizeof integer-point-pair:literal)
     ])))
(run 'main)
;? (prn memory*)
(when (is memory*.1 2)
  (prn "F - 'sizeof' is different from number of elems"))

; Regardless of a type's length, you can move it around just like a primitive.

(reset)
(new-trace "copy-record")
(add-code
  '((function main [
      (1:integer <- copy 34:literal)
      (2:boolean <- copy nil:literal)
      (4:boolean <- copy t:literal)
      (3:integer-boolean-pair <- copy 1:integer-boolean-pair)
     ])))
(run 'main)
;? (prn memory*)
(when (~iso memory* (obj 1 34  2 nil  3 34  4 nil))
  (prn "F - ops can operate on records spanning multiple locations"))

(reset)
(new-trace "copy-record2")
(add-code
  '((function main [
      (1:integer <- copy 34:literal)
      (2:integer <- copy 35:literal)
      (3:integer <- copy 36:literal)
      (4:integer <- copy 0:literal)
      (5:integer <- copy 0:literal)
      (6:integer <- copy 0:literal)
      (4:integer-point-pair <- copy 1:integer-point-pair)
     ])))
;? (= dump-trace* (obj whitelist '("run" "sizeof")))
(run 'main)
;? (prn memory*)
(when (~iso memory* (obj 1 34  2 35  3 36
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
;
; The payload of a tagged value must occupy just one location. Save pointers
; to records.

(reset)
(new-trace "tagged-value")
;? (= dump-trace* (obj blacklist '("sz" "mem" "addr" "cvt0" "cvt1")))
(add-code
  '((function main [
      (1:type <- copy integer:literal)
      (2:integer <- copy 34:literal)
      (3:integer 4:boolean <- maybe-coerce 1:tagged-value integer:literal)
     ])))
;? (set dump-trace*)
(run 'main)
;? (prn completed-routines*)
(each routine completed-routines*
  (aif rep.routine!error (prn "error - " it)))
;? (prn memory*)
(when (or (~is memory*.3 34)
          (~is memory*.4 t))
  (prn "F - 'maybe-coerce' copies value only if type tag matches"))
;? (quit)

(reset)
(new-trace "tagged-value-2")
;? (set dump-trace*)
(add-code
  '((function main [
      (1:type <- copy integer-address:literal)
      (2:integer <- copy 34:literal)
      (3:boolean 4:boolean <- maybe-coerce 1:tagged-value boolean:literal)
     ])))
(run 'main)
;? (prn memory*)
(when (or (~is memory*.3 0)
          (~is memory*.4 nil))
  (prn "F - 'maybe-coerce' doesn't copy value when type tag doesn't match"))

(reset)
(new-trace "save-type")
(add-code
  '((function main [
      (1:integer <- copy 34:literal)
      (2:tagged-value <- save-type 1:integer)
     ])))
(run 'main)
;? (prn memory*)
(when (~iso memory* (obj  1 34  2 'integer  3 34))
  (prn "F - 'save-type' saves the type of a value at runtime, turning it into a tagged-value"))

(reset)
(new-trace "init-tagged-value")
(add-code
  '((function main [
      (1:integer <- copy 34:literal)
      (2:tagged-value-address <- init-tagged-value integer:literal 1:integer)
      (3:integer 4:boolean <- maybe-coerce 2:tagged-value-address/deref integer:literal)
     ])))
;? (= dump-trace* (obj blacklist '("sz" "mem" "addr" "cvt0" "cvt1" "sizeof")))
(run 'main)
;? (prn memory*)
(when (or (~is memory*.3 34)
          (~is memory*.4 t))
  (prn "F - 'init-tagged-value' is the converse of 'maybe-coerce'"))
;? (quit)

; Now that we can package values together with their types, we can construct a
; dynamically typed list.

(reset)
(new-trace "list")
;? (set dump-trace*)
(add-code
  '((function main [
      ; 1 points at first node: tagged-value (int 34)
      (1:list-address <- new list:literal)
      (2:tagged-value-address <- list-value-address 1:list-address)
      (3:type-address <- get-address 2:tagged-value-address/deref type:offset)
      (3:type-address/deref <- copy integer:literal)
      (4:location <- get-address 2:tagged-value-address/deref payload:offset)
      (4:location/deref <- copy 34:literal)
      (5:list-address-address <- get-address 1:list-address/deref cdr:offset)
      (5:list-address-address/deref <- new list:literal)
      ; 6 points at second node: tagged-value (boolean t)
      (6:list-address <- copy 5:list-address-address/deref)
      (7:tagged-value-address <- list-value-address 6:list-address)
      (8:type-address <- get-address 7:tagged-value-address/deref type:offset)
      (8:type-address/deref <- copy boolean:literal)
      (9:location <- get-address 7:tagged-value-address/deref payload:offset)
      (9:location/deref <- copy t:literal)
      (10:list-address <- get 6:list-address/deref 1:offset)
     ])))
(let routine make-routine!main
  (enq routine running-routines*)
  (let first rep.routine!alloc
;?     (= dump-trace* (obj whitelist '("run")))
;?     (set dump-trace*)
    (run)
;?     (prn memory*)
    (each routine completed-routines*
      (aif rep.routine!error (prn "error - " it)))
    (when (or (~all first (map memory* '(1 2 3)))
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
(run-code test2
  (10:list-address <- list-next 1:list-address))
(each routine completed-routines*
  (aif rep.routine!error (prn "error - " it)))
(when (~is memory*.10 memory*.6)
  (prn "F - 'list-next can move a list pointer to the next node"))
;? (quit)

; 'init-list' takes a variable number of args and constructs a list containing
; them. Just integers for now.

(reset)
(new-trace "init-list")
(add-code
  '((function main [
      (1:integer <- init-list 3:literal 4:literal 5:literal)
     ])))
;? (= dump-trace* (obj blacklist '("sz" "mem" "addr" "cvt0" "cvt1" "sizeof")))
(run 'main)
;? (prn memory*)
(let first memory*.1
;?   (prn first)
  (when (or (~is memory*.first  'integer)
            (~is (memory* (+ first 1))  3)
            (let second (memory* (+ first 2))
;?               (prn second)
              (or (~is memory*.second 'integer)
                  (~is (memory* (+ second 1)) 4)
                  (let third (memory* (+ second 2))
;?                     (prn third)
                    (or (~is memory*.third 'integer)
                        (~is (memory* (+ third 1)) 5)
                        (~is (memory* (+ third 2) nil)))))))
    (prn "F - 'init-list' can construct a list of integers")))

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
      (3:integer <- add 1:integer 2:integer)
     ])
    (function main [
      (1:integer <- copy 1:literal)
      (2:integer <- copy 3:literal)
      (test1)
     ])))
(run 'main)
;? (prn memory*)
(when (~iso memory* (obj 1 1  2 3  3 4))
  (prn "F - calling a user-defined function runs its instructions"))
;? (quit)

(reset)
(new-trace "new-fn-once")
(add-code
  '((function test1 [
      (1:integer <- copy 1:literal)
     ])
    (function main [
      (test1)
     ])))
;? (= dump-trace* (obj whitelist '("run")))
(run 'main)
(when (~is 2 curr-cycle*)
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
      (3:integer <- add 1:integer 2:integer)
      (reply)
      (4:integer <- copy 34:literal)
     ])
    (function main [
      (1:integer <- copy 1:literal)
      (2:integer <- copy 3:literal)
      (test1)
     ])))
(run 'main)
;? (prn memory*)
(when (~iso memory* (obj 1 1  2 3  3 4))
  (prn "F - 'reply' stops executing the current function"))
;? (quit)

(reset)
(new-trace "new-fn-reply-nested")
(add-code
  '((function test1 [
      (3:integer <- test2)
     ])
    (function test2 [
      (reply 2:integer)
     ])
    (function main [
      (2:integer <- copy 34:literal)
      (test1)
     ])))
(run 'main)
;? (prn memory*)
(when (~iso memory* (obj 2 34  3 34))
  (prn "F - 'reply' stops executing any callers as necessary"))
;? (quit)

(reset)
(new-trace "new-fn-reply-once")
(add-code
  '((function test1 [
      (3:integer <- add 1:integer 2:integer)
      (reply)
      (4:integer <- copy 34:literal)
     ])
    (function main [
      (1:integer <- copy 1:literal)
      (2:integer <- copy 3:literal)
      (test1)
     ])))
;? (= dump-trace* (obj whitelist '("run")))
(run 'main)
(when (~is 5 curr-cycle*)
  (prn "F - 'reply' executes instructions exactly once " curr-cycle*))
;? (quit)

(reset)
(new-trace "reply-increments-caller-pc")
(add-code
  '((function callee [
      (reply)
     ])
    (function caller [
      (1:integer <- copy 0:literal)
      (2:integer <- copy 0:literal)
     ])))
(freeze function*)
(= routine* (make-routine 'caller))
(assert (is 0 pc.routine*))
(push-stack routine* 'callee)  ; pretend call was at first instruction of caller
(run-for-time-slice 1)
(when (~is 1 pc.routine*)
  (prn "F - 'reply' increments pc in caller (to move past calling instruction)"))

(reset)
(new-trace "new-fn-arg-sequential")
(add-code
  '((function test1 [
      (4:integer <- next-input)
      (5:integer <- next-input)
      (3:integer <- add 4:integer 5:integer)
      (reply)
      (4:integer <- copy 34:literal)
     ])
    (function main [
      (1:integer <- copy 1:literal)
      (2:integer <- copy 3:literal)
      (test1 1:integer 2:integer)
     ])))
(run 'main)
;? (prn memory*)
(when (~iso memory* (obj 1 1  2 3  3 4
                         ; test1's temporaries
                         4 1  5 3))
  (prn "F - 'arg' accesses in order the operands of the most recent function call (the caller)"))
;? (quit)

(reset)
(new-trace "new-fn-arg-random-access")
;? (set dump-trace*)
(add-code
  '((function test1 [
      (5:integer <- input 1:literal)
      (4:integer <- input 0:literal)
      (3:integer <- add 4:integer 5:integer)
      (reply)
      (4:integer <- copy 34:literal)  ; should never run
     ])
    (function main [
      (1:integer <- copy 1:literal)
      (2:integer <- copy 3:literal)
      (test1 1:integer 2:integer)
     ])))
(run 'main)
;? (prn memory*)
(when (~iso memory* (obj 1 1  2 3  3 4
                         ; test's temporaries
                         4 1  5 3))
  (prn "F - 'arg' with index can access function call arguments out of order"))
;? (quit)

(reset)
(new-trace "new-fn-arg-random-then-sequential")
;? (set dump-trace*)
(add-code
  '((function test1 [
      (_ <- input 1:literal)
      (1:integer <- next-input)  ; takes next arg after index 1
     ])  ; should never run
    (function main [
      (test1 1:literal 2:literal 3:literal)
     ])))
(run 'main)
;? (prn memory*)
(when (~iso memory* (obj 1 3))
  (prn "F - 'arg' with index resets index for later calls"))
;? (quit)

(reset)
(new-trace "new-fn-arg-status")
(add-code
  '((function test1 [
      (4:integer 5:boolean <- next-input)
     ])
    (function main [
      (test1 1:literal)
     ])))
(run 'main)
;? (prn memory*)
(when (~iso memory* (obj 4 1  5 t))
  (prn "F - 'arg' sets a second oarg when arg exists"))
;? (quit)

(reset)
(new-trace "new-fn-arg-missing")
(add-code
  '((function test1 [
      (4:integer <- next-input)
      (5:integer <- next-input)
     ])
    (function main [
      (test1 1:literal)
     ])))
(run 'main)
;? (prn memory*)
(when (~iso memory* (obj 4 1))
  (prn "F - missing 'arg' doesn't cause error"))
;? (quit)

(reset)
(new-trace "new-fn-arg-missing-2")
(add-code
  '((function test1 [
      (4:integer <- next-input)
      (5:integer 6:boolean <- next-input)
     ])
    (function main [
      (test1 1:literal)
     ])))
(run 'main)
;? (prn memory*)
(when (~iso memory* (obj 4 1  6 nil))
  (prn "F - missing 'arg' wipes second oarg when provided"))
;? (quit)

(reset)
(new-trace "new-fn-arg-missing-3")
(add-code
  '((function test1 [
      (4:integer <- next-input)
      (5:integer <- copy 34:literal)
      (5:integer 6:boolean <- next-input)
    ])
    (function main [
      (test1 1:literal)
    ])))
(run 'main)
;? (prn memory*)
(when (~iso memory* (obj 4 1  6 nil))
  (prn "F - missing 'arg' consistently wipes its oarg"))
;? (quit)

(reset)
(new-trace "new-fn-arg-missing-4")
(add-code
  '((function test1 [
      ; if given two args, adds them; if given one arg, increments
      (4:integer <- next-input)
      (5:integer 6:boolean <- next-input)
      { begin
        (break-if 6:boolean)
        (5:integer <- copy 1:literal)
      }
      (7:integer <- add 4:integer 5:integer)
     ])
    (function main [
      (test1 34:literal)
     ])))
;? (set dump-trace*)
(run 'main)
;? (prn memory*)
(when (~iso memory* (obj 4 34  5 1  6 nil  7 35))
  (prn "F - function with optional second arg"))
;? (quit)

(reset)
(new-trace "new-fn-arg-by-value")
(add-code
  '((function test1 [
      (1:integer <- copy 0:literal)  ; overwrite caller memory
      (2:integer <- next-input)
     ])  ; arg not clobbered
    (function main [
      (1:integer <- copy 34:literal)
      (test1 1:integer)
     ])))
(run 'main)
;? (prn memory*)
(when (~iso memory* (obj 1 0  2 34))
  (prn "F - 'arg' passes by value"))

(reset)
(new-trace "arg-record")
(add-code
  '((function test1 [
      (4:integer-boolean-pair <- next-input)
     ])
    (function main [
      (1:integer <- copy 34:literal)
      (2:boolean <- copy nil:literal)
      (test1 1:integer-boolean-pair)
     ])))
(run 'main)
(when (~iso memory* (obj 1 34  2 nil  4 34  5 nil))
  (prn "F - 'arg' can copy records spanning multiple locations"))

(reset)
(new-trace "arg-record-indirect")
;? (set dump-trace*)
(add-code
  '((function test1 [
      (4:integer-boolean-pair <- next-input)
     ])
    (function main [
      (1:integer <- copy 34:literal)
      (2:boolean <- copy nil:literal)
      (3:integer-boolean-pair-address <- copy 1:literal)
      (test1 3:integer-boolean-pair-address/deref)
     ])))
(run 'main)
;? (prn memory*)
(when (~iso memory* (obj 1 34  2 nil  3 1  4 34  5 nil))
  (prn "F - 'arg' can copy records spanning multiple locations in indirect mode"))

(reset)
(new-trace "new-fn-reply-oarg")
(add-code
  '((function test1 [
      (4:integer <- next-input)
      (5:integer <- next-input)
      (6:integer <- add 4:integer 5:integer)
      (reply 6:integer)
      (4:integer <- copy 34:literal)
     ])
    (function main [
      (1:integer <- copy 1:literal)
      (2:integer <- copy 3:literal)
      (3:integer <- test1 1:integer 2:integer)
     ])))
(run 'main)
;? (prn memory*)
(when (~iso memory* (obj 1 1  2 3  3 4
                         ; test1's temporaries
                         4 1  5 3  6 4))
  (prn "F - 'reply' can take aguments that are returned, or written back into output args of caller"))

(reset)
(new-trace "new-fn-reply-oarg-multiple")
(add-code
  '((function test1 [
      (4:integer <- next-input)
      (5:integer <- next-input)
      (6:integer <- add 4:integer 5:integer)
      (reply 6:integer 5:integer)
      (4:integer <- copy 34:literal)
     ])
    (function main [
      (1:integer <- copy 1:literal)
      (2:integer <- copy 3:literal)
      (3:integer 7:integer <- test1 1:integer 2:integer)
     ])))
(run 'main)
;? (prn memory*)
(when (~iso memory* (obj 1 1  2 3  3 4    7 3
                         ; test1's temporaries
                         4 1  5 3  6 4))
  (prn "F - 'reply' permits a function to return multiple values at once"))

; 'prepare-reply' is useful for doing cleanup before exiting a function
(reset)
(new-trace "new-fn-prepare-reply")
(add-code
  '((function test1 [
      (4:integer <- next-input)
      (5:integer <- next-input)
      (6:integer <- add 4:integer 5:integer)
      (prepare-reply 6:integer 5:integer)
      (reply)
      (4:integer <- copy 34:literal)
     ])
    (function main [
      (1:integer <- copy 1:literal)
      (2:integer <- copy 3:literal)
      (3:integer 7:integer <- test1 1:integer 2:integer)
     ])))
(run 'main)
;? (prn memory*)
(when (~iso memory* (obj 1 1  2 3  3 4    7 3
                         ; test1's temporaries
                         4 1  5 3  6 4))
  (prn "F - without args, 'reply' returns values from previous 'prepare-reply'."))

; When you have arguments that are both read from and written to, include them
; redundantly in both ingredients and results. That'll help tools track what
; changed.

; To enforce that the result and ingredient must always match, use the
; 'same-as-arg' property. Results with 'same-as-arg' properties should only be
; copied to a caller output arg identical to the specified caller arg.
(reset)
(new-trace "new-fn-same-as-arg")
(add-code
  '((function test1 [
      ; increment the contents of an address
      (default-space:space-address <- new space:literal 2:literal)
      (x:integer-address <- next-input)
      (x:integer-address/deref <- add x:integer-address/deref 1:literal)
      (reply x:integer-address/same-as-arg:0)
    ])
    (function main [
      (2:integer-address <- new integer:literal)
      (2:integer-address/deref <- copy 0:literal)
      (3:integer-address <- test1 2:integer-address)
    ])))
(run 'main)
(let routine (car completed-routines*)
;?   (prn rep.routine!error) ;? 1
  (when (no rep.routine!error)
    (prn "F - 'same-as-arg' results must be identical to a given input")))
;? (quit) ;? 2

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
(when (~iso (convert-braces
              '((((1 integer)) <- ((copy)) ((0 literal)))
                (((2 integer)) <- ((copy)) ((0 literal)))
                (((3 integer)) <- ((copy)) ((0 literal)))
                { begin  ; 'begin' is just a hack because racket turns braces into parens
                  (((4 boolean)) <- ((not-equal)) ((1 integer)) ((3 integer)))
                  (((break-if)) ((4 boolean)))
                  (((5 integer)) <- ((copy)) ((0 literal)))
                }
                (((reply)))))
            '((((1 integer)) <- ((copy)) ((0 literal)))
              (((2 integer)) <- ((copy)) ((0 literal)))
              (((3 integer)) <- ((copy)) ((0 literal)))
              (((4 boolean)) <- ((not-equal)) ((1 integer)) ((3 integer)))
              (((jump-if)) ((4 boolean)) ((1 offset)))
              (((5 integer)) <- ((copy)) ((0 literal)))
              (((reply)))))
  (prn "F - convert-braces replaces break-if with a jump-if to after the next close-brace"))
;? (quit)

(reset)
(new-trace "convert-braces-empty-block")
(= traces* (queue))
;? (= dump-trace* (obj whitelist '("c{0" "c{1")))
(when (~iso (convert-braces
              '((((1 integer)) <- ((copy)) ((0 literal)))
                (((2 integer)) <- ((copy)) ((0 literal)))
                (((3 integer)) <- ((copy)) ((0 literal)))
                { begin
                  (((break)))
                }
                (((reply)))))
            '((((1 integer)) <- ((copy)) ((0 literal)))
              (((2 integer)) <- ((copy)) ((0 literal)))
              (((3 integer)) <- ((copy)) ((0 literal)))
              (((jump)) ((0 offset)))
              (((reply)))))
  (prn "F - convert-braces works for degenerate blocks"))
;? (quit)

(reset)
(new-trace "convert-braces-nested-break")
(= traces* (queue))
(when (~iso (convert-braces
              '((((1 integer)) <- ((copy)) ((0 literal)))
                (((2 integer)) <- ((copy)) ((0 literal)))
                (((3 integer)) <- ((copy)) ((0 literal)))
                { begin
                  (((4 boolean)) <- ((not-equal)) ((1 integer)) ((3 integer)))
                  (((break-if)) ((4 boolean)))
                  { begin
                    (((5 integer)) <- ((copy)) ((0 literal)))
                  }
                }
                (((reply)))))
            '((((1 integer)) <- ((copy)) ((0 literal)))
              (((2 integer)) <- ((copy)) ((0 literal)))
              (((3 integer)) <- ((copy)) ((0 literal)))
              (((4 boolean)) <- ((not-equal)) ((1 integer)) ((3 integer)))
              (((jump-if)) ((4 boolean)) ((1 offset)))
              (((5 integer)) <- ((copy)) ((0 literal)))
              (((reply)))))
  (prn "F - convert-braces balances braces when converting break"))

(reset)
(new-trace "convert-braces-repeated-jump")
(= traces* (queue))
;? (= dump-trace* (obj whitelist '("c{0" "c{1")))
(when (~iso (convert-braces
              '((((1 integer)) <- ((copy)) ((0 literal)))
                { begin
                  (((break)))
                  (((2 integer)) <- ((copy)) ((0 literal)))
                }
                { begin
                  (((break)))
                  (((3 integer)) <- ((copy)) ((0 literal)))
                }
                (((4 integer)) <- ((copy)) ((0 literal)))))
            '((((1 integer)) <- ((copy)) ((0 literal)))
              (((jump)) ((1 offset)))
              (((2 integer)) <- ((copy)) ((0 literal)))
              (((jump)) ((1 offset)))
              (((3 integer)) <- ((copy)) ((0 literal)))
              (((4 integer)) <- ((copy)) ((0 literal)))))
  (prn "F - convert-braces handles jumps on jumps"))
;? (quit)

(reset)
(new-trace "convert-braces-nested-loop")
(= traces* (queue))
(when (~iso (convert-braces
              '((((1 integer)) <- ((copy)) ((0 literal)))
                (((2 integer)) <- ((copy)) ((0 literal)))
                { begin
                  (((3 integer)) <- ((copy)) ((0 literal)))
                  { begin
                    (((4 boolean)) <- ((not-equal)) ((1 integer)) ((3 integer)))
                  }
                  (((loop-if)) ((4 boolean)))
                  (((5 integer)) <- ((copy)) ((0 literal)))
                }
                (((reply)))))
            '((((1 integer)) <- ((copy)) ((0 literal)))
              (((2 integer)) <- ((copy)) ((0 literal)))
              (((3 integer)) <- ((copy)) ((0 literal)))
              (((4 boolean)) <- ((not-equal)) ((1 integer)) ((3 integer)))
              (((jump-if)) ((4 boolean)) ((-3 offset)))
              (((5 integer)) <- ((copy)) ((0 literal)))
              (((reply)))))
  (prn "F - convert-braces balances braces when converting 'loop'"))

(reset)
(new-trace "convert-braces-label")
(= traces* (queue))
(when (~iso (convert-braces
              '((((1 integer)) <- ((copy)) ((0 literal)))
                foo
                (((2 integer)) <- ((copy)) ((0 literal)))))
            '((((1 integer)) <- ((copy)) ((0 literal)))
              foo
              (((2 integer)) <- ((copy)) ((0 literal)))))
  (prn "F - convert-braces skips past labels"))
;? (quit)

(reset)
(new-trace "convert-braces-label-increments-offset")
(= traces* (queue))
(when (~iso (convert-braces
              '((((1 integer)) <- ((copy)) ((0 literal)))
                { begin
                  (((break)))
                  foo
                }
                (((2 integer)) <- ((copy)) ((0 literal)))))
            '((((1 integer)) <- ((copy)) ((0 literal)))
              (((jump)) ((1 offset)))
              foo
              (((2 integer)) <- ((copy)) ((0 literal)))))
  (prn "F - convert-braces treats labels as instructions"))
;? (quit)

(reset)
(new-trace "convert-braces-label-increments-offset2")
(= traces* (queue))
;? (= dump-trace* (obj whitelist '("c{0" "c{1")))
(when (~iso (convert-braces
              '((((1 integer)) <- ((copy)) ((0 literal)))
                { begin
                  (((break)))
                  foo
                }
                (((2 integer)) <- ((copy)) ((0 literal)))
                { begin
                  (((break)))
                  (((3 integer)) <- ((copy)) ((0 literal)))
                }
                (((4 integer)) <- ((copy)) ((0 literal)))))
            '((((1 integer)) <- ((copy)) ((0 literal)))
              (((jump)) ((1 offset)))
              foo
              (((2 integer)) <- ((copy)) ((0 literal)))
              (((jump)) ((1 offset)))
              (((3 integer)) <- ((copy)) ((0 literal)))
              (((4 integer)) <- ((copy)) ((0 literal)))))
  (prn "F - convert-braces treats labels as instructions - 2"))
;? (quit)

(reset)
(new-trace "break-multiple")
(= traces* (queue))
;? (= dump-trace* (obj whitelist '("-")))
(when (~iso (convert-braces
              '((((1 integer)) <- ((copy)) ((0 literal)))
                { begin
                  { begin
                    (((break)) ((2 blocks)))
                  }
                  (((2 integer)) <- ((copy)) ((0 literal)))
                  (((3 integer)) <- ((copy)) ((0 literal)))
                  (((4 integer)) <- ((copy)) ((0 literal)))
                  (((5 integer)) <- ((copy)) ((0 literal)))
                }))
            '((((1 integer)) <- ((copy)) ((0 literal)))
              (((jump)) ((4 offset)))
              (((2 integer)) <- ((copy)) ((0 literal)))
              (((3 integer)) <- ((copy)) ((0 literal)))
              (((4 integer)) <- ((copy)) ((0 literal)))
              (((5 integer)) <- ((copy)) ((0 literal)))))
  (prn "F - 'break' can take an extra arg with number of nested blocks to exit"))
;? (quit)

(reset)
(new-trace "loop")
;? (set dump-trace*)
(when (~iso (convert-braces
              '((((1 integer)) <- ((copy)) ((0 literal)))
                (((2 integer)) <- ((copy)) ((0 literal)))
                { begin
                  (((3 integer)) <- ((copy)) ((0 literal)))
                  (((loop)))
                }))
            '((((1 integer)) <- ((copy)) ((0 literal)))
              (((2 integer)) <- ((copy)) ((0 literal)))
              (((3 integer)) <- ((copy)) ((0 literal)))
              (((jump)) ((-2 offset)))))
  (prn "F - 'loop' jumps to start of containing block"))
;? (quit)

; todo: fuzz-test invariant: convert-braces offsets should be robust to any
; number of inner blocks inside but not around the loop block.

(reset)
(new-trace "loop-nested")
;? (set dump-trace*)
(when (~iso (convert-braces
              '((((1 integer)) <- ((copy)) ((0 literal)))
                (((2 integer)) <- ((copy)) ((0 literal)))
                { begin
                  (((3 integer)) <- ((copy)) ((0 literal)))
                  { begin
                    (((4 integer)) <- ((copy)) ((0 literal)))
                  }
                  (((loop)))
                }))
            '((((1 integer)) <- ((copy)) ((0 literal)))
              (((2 integer)) <- ((copy)) ((0 literal)))
              (((3 integer)) <- ((copy)) ((0 literal)))
              (((4 integer)) <- ((copy)) ((0 literal)))
              (((jump)) ((-3 offset)))))
  (prn "F - 'loop' correctly jumps back past nested braces"))

(reset)
(new-trace "loop-multiple")
(= traces* (queue))
;? (= dump-trace* (obj whitelist '("-")))
(when (~iso (convert-braces
              '((((1 integer)) <- ((copy)) ((0 literal)))
                { begin
                  (((2 integer)) <- ((copy)) ((0 literal)))
                  (((3 integer)) <- ((copy)) ((0 literal)))
                  { begin
                    (((loop)) ((2 blocks)))
                  }
                }))
            '((((1 integer)) <- ((copy)) ((0 literal)))
              (((2 integer)) <- ((copy)) ((0 literal)))
              (((3 integer)) <- ((copy)) ((0 literal)))
              (((jump)) ((-3 offset)))))
  (prn "F - 'loop' can take an extra arg with number of nested blocks to exit"))
;? (quit)

(reset)
(new-trace "convert-labels")
(= traces* (queue))
(when (~iso (convert-labels
              '(loop
                (((jump)) ((loop offset)))))
            '(loop
              (((jump)) ((-2 offset)))))
  (prn "F - 'convert-labels' rewrites jumps to labels"))

;; Variables
;
; A big convenience high-level languages provide is the ability to name memory
; locations. In mu, a lightweight tool called 'convert-names' provides this
; convenience.

(reset)
(new-trace "convert-names")
(= traces* (queue))
;? (set dump-trace*)
(when (~iso (convert-names
              '((((x integer)) <- ((copy)) ((0 literal)))
                (((y integer)) <- ((copy)) ((0 literal)))
                (((z integer)) <- ((copy)) ((0 literal)))))
            '((((1 integer)) <- ((copy)) ((0 literal)))
              (((2 integer)) <- ((copy)) ((0 literal)))
              (((3 integer)) <- ((copy)) ((0 literal)))))
  (prn "F - convert-names renames symbolic names to integer locations"))

(reset)
(new-trace "convert-names-compound")
(= traces* (queue))
(when (~iso (convert-names
              ; copying 0 into pair is meaningless; just for testing
              '((((x integer-boolean-pair)) <- ((copy)) ((0 literal)))
                (((y integer)) <- ((copy)) ((0 literal)))))
            '((((1 integer-boolean-pair)) <- ((copy)) ((0 literal)))
              (((3 integer)) <- ((copy)) ((0 literal)))))
  (prn "F - convert-names increments integer locations by the size of the type of the previous var"))

(reset)
(new-trace "convert-names-nil")
(= traces* (queue))
;? (set dump-trace*)
(when (~iso (convert-names
              '((((x integer)) <- ((copy)) ((0 literal)))
                (((y integer)) <- ((copy)) ((0 literal)))
                ; nil location is meaningless; just for testing
                (((nil integer)) <- ((copy)) ((0 literal)))))
            '((((1 integer)) <- ((copy)) ((0 literal)))
              (((2 integer)) <- ((copy)) ((0 literal)))
              (((nil integer)) <- ((copy)) ((0 literal)))))
  (prn "F - convert-names never renames nil"))

(reset)
(new-trace "convert-names-string")
;? (set dump-trace*)
(when (~iso (convert-names
              '((((1 integer-address)) <- ((new)) "foo")))
            '((((1 integer-address)) <- ((new)) "foo")))
  (prn "convert-names passes through raw strings (just a convenience arg for 'new')"))

(reset)
(new-trace "convert-names-raw")
(= traces* (queue))
(when (~iso (convert-names
              '((((x integer)) <- ((copy)) ((0 literal)))
                (((y integer) (raw)) <- ((copy)) ((0 literal)))))
            '((((1 integer)) <- ((copy)) ((0 literal)))
              (((y integer) (raw)) <- ((copy)) ((0 literal)))))
  (prn "F - convert-names never renames raw operands"))

(reset)
(new-trace "convert-names-literal")
(= traces* (queue))
(when (~iso (convert-names
              ; meaningless; just for testing
              '((((x literal)) <- ((copy)) ((0 literal)))))
            '((((x literal)) <- ((copy)) ((0 literal)))))
  (prn "F - convert-names never renames literals"))

(reset)
(new-trace "convert-names-literal-2")
(= traces* (queue))
(when (~iso (convert-names
              '((((x boolean)) <- ((copy)) ((x literal)))))
            '((((1 boolean)) <- ((copy)) ((x literal)))))
  (prn "F - convert-names never renames literals, even when the name matches a variable"))

; kludgy support for 'fork' below
(reset)
(new-trace "convert-names-functions")
(= traces* (queue))
(when (~iso (convert-names
              '((((x integer)) <- ((copy)) ((0 literal)))
                (((y integer)) <- ((copy)) ((0 literal)))
                ; meaningless; just for testing
                (((z fn)) <- ((copy)) ((0 literal)))))
            '((((1 integer)) <- ((copy)) ((0 literal)))
              (((2 integer)) <- ((copy)) ((0 literal)))
              (((z fn)) <- ((copy)) ((0 literal)))))
  (prn "F - convert-names never renames fns"))

(reset)
(new-trace "convert-names-record-fields")
(= traces* (queue))
;? (= dump-trace* (obj whitelist '("cn0")))
(when (~iso (convert-names
              '((((x integer)) <- ((get)) ((34 integer-boolean-pair)) ((bool offset)))))
            '((((1 integer)) <- ((get)) ((34 integer-boolean-pair)) ((1 offset)))))
  (prn "F - convert-names replaces record field offsets"))

(reset)
(new-trace "convert-names-record-fields-ambiguous")
(= traces* (queue))
(when (errsafe (convert-names
                 '((((bool boolean)) <- ((copy)) ((t literal)))
                   (((x integer)) <- ((get)) ((34 integer-boolean-pair)) ((bool offset))))))
  (prn "F - convert-names doesn't allow offsets and variables with the same name in a function"))

(reset)
(new-trace "convert-names-record-fields-ambiguous-2")
(= traces* (queue))
(when (errsafe (convert-names
                 '((((x integer)) <- ((get)) ((34 integer-boolean-pair)) ((bool offset)))
                   (((bool boolean)) <- ((copy)) ((t literal))))))
  (prn "F - convert-names doesn't allow offsets and variables with the same name in a function - 2"))

(reset)
(new-trace "convert-names-record-fields-indirect")
(= traces* (queue))
;? (= dump-trace* (obj whitelist '("cn0")))
(when (~iso (convert-names
              '((((x integer)) <- ((get)) ((34 integer-boolean-pair-address) (deref)) ((bool offset)))))
            '((((1 integer)) <- ((get)) ((34 integer-boolean-pair-address) (deref)) ((1 offset)))))
  (prn "F - convert-names replaces field offsets for record addresses"))
;? (quit)

(reset)
(new-trace "convert-names-record-fields-multiple")
(= traces* (queue))
(when (~iso (convert-names
              '((((2 boolean)) <- ((get)) ((1 integer-boolean-pair)) ((bool offset)))
                (((3 boolean)) <- ((get)) ((1 integer-boolean-pair)) ((bool offset)))))
            '((((2 boolean)) <- ((get)) ((1 integer-boolean-pair)) ((1 offset)))
              (((3 boolean)) <- ((get)) ((1 integer-boolean-pair)) ((1 offset)))))
  (prn "F - convert-names replaces field offsets with multiple mentions"))
;? (quit)

(reset)
(new-trace "convert-names-label")
(= traces* (queue))
(when (~iso (convert-names
              '((((1 integer)) <- ((copy)) ((0 literal)))
                foo))
            '((((1 integer)) <- ((copy)) ((0 literal)))
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
      (1:integer-address <- new integer:literal)
     ])))
(let routine make-routine!main
  (enq routine running-routines*)
  (let before rep.routine!alloc
;?     (set dump-trace*)
    (run)
;?     (prn memory*)
    (when (~iso memory*.1 before)
      (prn "F - 'new' returns current high-water mark"))
    (when (~iso rep.routine!alloc (+ before 1))
      (prn "F - 'new' on primitive types increments high-water mark by their size"))))
;? (quit)

(reset)
(new-trace "new-array-literal")
(add-code
  '((function main [
      (1:type-array-address <- new type-array:literal 5:literal)
     ])))
(let routine make-routine!main
  (enq routine running-routines*)
  (let before rep.routine!alloc
    (run)
;?     (prn memory*)
    (when (~iso memory*.1 before)
      (prn "F - 'new' on array with literal size returns current high-water mark"))
    (when (~iso rep.routine!alloc (+ before 6))
      (prn "F - 'new' on primitive arrays increments high-water mark by their size"))))

(reset)
(new-trace "new-array-direct")
(add-code
  '((function main [
      (1:integer <- copy 5:literal)
      (2:type-array-address <- new type-array:literal 1:integer)
     ])))
(let routine make-routine!main
  (enq routine running-routines*)
  (let before rep.routine!alloc
    (run)
;?     (prn memory*)
    (when (~iso memory*.2 before)
      (prn "F - 'new' on array with variable size returns current high-water mark"))
    (when (~iso rep.routine!alloc (+ before 6))
      (prn "F - 'new' on primitive arrays increments high-water mark by their (variable) size"))))

(reset)
(new-trace "new-allocation-chunk")
(add-code
  '((function main [
      (1:integer-address <- new integer:literal)
     ])))
; start allocating from address 30, in chunks of 10 locations each
(= Memory-allocated-until 30
   Allocation-chunk 10)
(let routine make-routine!main
  (assert:is rep.routine!alloc 30)
  (assert:is rep.routine!alloc-max 40)
  ; pretend the current chunk is full
  (= rep.routine!alloc 40)
  (enq routine running-routines*)
  (run)
  (each routine completed-routines*
    (aif rep.routine!error (prn "error - " it)))
  (when (~is rep.routine!alloc 41)
    (prn "F - 'new' can allocate past initial routine memory"))
  (when (~is rep.routine!alloc-max 50)
    (prn "F - 'new' updates upper bound for routine memory @rep.routine!alloc-max")))

(reset)
(new-trace "new-skip")
(add-code
  '((function main [
      (1:integer-boolean-pair-address <- new integer-boolean-pair:literal)
     ])))
; start allocating from address 30, in chunks of 10 locations each
(= Memory-allocated-until 30
   Allocation-chunk 10)
(let routine make-routine!main
  (assert:is rep.routine!alloc 30)
  (assert:is rep.routine!alloc-max 40)
  ; pretend the current chunk has just one location left
  (= rep.routine!alloc 39)
  (enq routine running-routines*)
  ; request 2 locations
  (run)
  (each routine completed-routines*
    (aif rep.routine!error (prn "error - " it)))
  (when (or (~is memory*.1 40)
            (~is rep.routine!alloc 42)
            (~is rep.routine!alloc-max 50)
            (~is Memory-allocated-until 50))
    (prn "F - 'new' skips past current chunk if insufficient space")))

(reset)
(new-trace "new-skip-noncontiguous")
(add-code
  '((function main [
      (1:integer-boolean-pair-address <- new integer-boolean-pair:literal)
     ])))
; start allocating from address 30, in chunks of 10 locations each
(= Memory-allocated-until 30
   Allocation-chunk 10)
(let routine make-routine!main
  (assert:is rep.routine!alloc 30)
  (assert:is rep.routine!alloc-max 40)
  ; pretend the current chunk has just one location left
  (= rep.routine!alloc 39)
  ; pretend we allocated more memory since we created the routine
  (= Memory-allocated-until 90)
  (enq routine running-routines*)
  ; request 2 locations
  (run)
  (each routine completed-routines*
    (aif rep.routine!error (prn "error - " it)))
  (when (or (~is memory*.1 90)
            (~is rep.routine!alloc 92)
            (~is rep.routine!alloc-max 100)
            (~is Memory-allocated-until 100))
    (prn "F - 'new' allocates a new chunk if insufficient space")))

(reset)
(new-trace "new-array-skip-noncontiguous")
(add-code
  '((function main [
      (1:integer-array-address <- new integer-array:literal 4:literal)
     ])))
; start allocating from address 30, in chunks of 10 locations each
(= Memory-allocated-until 30
   Allocation-chunk 10)
(let routine make-routine!main
  (assert:is rep.routine!alloc 30)
  (assert:is rep.routine!alloc-max 40)
  ; pretend the current chunk has just one location left
  (= rep.routine!alloc 39)
  ; pretend we allocated more memory since we created the routine
  (= Memory-allocated-until 90)
  (enq routine running-routines*)
  ; request 4 locations
  (run)
  (each routine completed-routines*
    (aif rep.routine!error (prn "error - " it)))
;?   (prn memory*.1) ;? 1
;?   (prn rep.routine) ;? 1
;?   (prn Memory-allocated-until) ;? 1
  (when (or (~is memory*.1 90)
            (~is rep.routine!alloc 95)
            (~is rep.routine!alloc-max 100)
            (~is Memory-allocated-until 100))
    (prn "F - 'new-array' allocates a new chunk if insufficient space")))

;? (quit) ;? 1

; Even though our memory locations can now have names, the names are all
; globals, accessible from any function. To isolate functions from their
; callers we need local variables, and mu provides them using a special
; variable called default-space. When you initialize such a variable (likely
; with a call to our just-defined memory allocator) mu interprets memory
; locations as offsets from its value. If default-space is set to 1000, for
; example, reads and writes to memory location 1 will really go to 1001.
;
; 'default-space' is itself hard-coded to be function-local; it's nil in a new
; function, and it's restored when functions return to their callers. But the
; actual space allocation is independent. So you can define closures, or do
; even more funky things like share locals between two coroutines.

(reset)
(new-trace "set-default-space")
(add-code
  '((function main [
      (default-space:space-address <- new space:literal 2:literal)
      (1:integer <- copy 23:literal)
     ])))
(let routine make-routine!main
  (enq routine running-routines*)
  (let before rep.routine!alloc
;?     (set dump-trace*)
    (run)
;?     (prn memory*)
    (when (~and (~is 23 memory*.1)
                (is 23 (memory* (+ before 2))))
      (prn "F - default-space implicitly modifies variable locations"))))
;? (quit)

(reset)
(new-trace "set-default-space-skips-offset")
(add-code
  '((function main [
      (default-space:space-address <- new space:literal 2:literal)
      (1:integer <- copy 23:offset)
     ])))
(let routine make-routine!main
  (enq routine running-routines*)
  (let before rep.routine!alloc
;?     (set dump-trace*)
    (run)
;?     (prn memory*)
    (when (~and (~is 23 memory*.1)
                (is 23 (memory* (+ before 2))))
      (prn "F - default-space skips 'offset' types just like literals"))))

(reset)
(new-trace "default-space-bounds-check")
(add-code
  '((function main [
      (default-space:space-address <- new space:literal 2:literal)
      (2:integer <- copy 23:literal)
     ])))
;? (set dump-trace*)
(run 'main)
;? (prn memory*)
(let routine (car completed-routines*)
  (when (no rep.routine!error)
    (prn "F - default-space checks bounds")))

(reset)
(new-trace "default-space-and-get-indirect")
(add-code
  '((function main [
      (default-space:space-address <- new space:literal 5:literal)
      (1:integer-boolean-pair-address <- new integer-boolean-pair:literal)
      (2:integer-address <- get-address 1:integer-boolean-pair-address/deref 0:offset)
      (2:integer-address/deref <- copy 34:literal)
      (3:integer/raw <- get 1:integer-boolean-pair-address/deref 0:offset)
     ])))
;? (= dump-trace* (obj blacklist '("sz" "mem" "addr" "cvt0" "cvt1")))
(run 'main)
;? (prn memory*)
;? (prn completed-routines*)
(each routine completed-routines*
  (aif rep.routine!error (prn "error - " it)))
(when (~is 34 memory*.3)
  (prn "F - indirect 'get' works in the presence of default-space"))
;? (quit)

(reset)
(new-trace "default-space-and-index-indirect")
(add-code
  '((function main [
      (default-space:space-address <- new space:literal 5:literal)
      (1:integer-array-address <- new integer-array:literal 4:literal)
      (2:integer-address <- index-address 1:integer-array-address/deref 2:offset)
      (2:integer-address/deref <- copy 34:literal)
      (3:integer/raw <- index 1:integer-array-address/deref 2:offset)
     ])))
;? (= dump-trace* (obj whitelist '("run" "array-info")))
(run 'main)
;? (prn memory*)
;? (prn completed-routines*)
(each routine completed-routines*
  (aif rep.routine!error (prn "error - " it)))
(when (~is 34 memory*.3)
  (prn "F - indirect 'index' works in the presence of default-space"))
;? (quit)

(reset)
(new-trace "convert-names-default-space")
(= traces* (queue))
(when (~iso (convert-names
              '((((x integer)) <- ((copy)) ((4 literal)))
                (((y integer)) <- ((copy)) ((2 literal)))
                ; unsafe in general; don't write random values to 'default-space'
                (((default-space integer)) <- ((add)) ((x integer)) ((y integer)))))
            '((((1 integer)) <- ((copy)) ((4 literal)))
              (((2 integer)) <- ((copy)) ((2 literal)))
              (((default-space integer)) <- ((add)) ((1 integer)) ((2 integer)))))
  (prn "F - convert-names never renames default-space"))

(reset)
(new-trace "suppress-default-space")
(add-code
  '((function main [
      (default-space:space-address <- new space:literal 2:literal)
      (1:integer/raw <- copy 23:literal)
     ])))
(let routine make-routine!main
  (enq routine running-routines*)
  (let before rep.routine!alloc
;?     (set dump-trace*)
    (run)
;?     (prn memory*)
    (when (~and (is 23 memory*.1)
                (~is 23 (memory* (+ before 1))))
      (prn "F - default-space skipped for locations with metadata 'raw'"))))
;? (quit)

(reset)
(new-trace "array-copy-indirect-scoped")
(add-code
  '((function main [
      (10:integer <- copy 30:literal)  ; pretend allocation
      (default-space:space-address <- copy 10:literal)  ; unsafe
      (1:integer <- copy 2:literal)  ; raw location 12
      (2:integer <- copy 23:literal)
      (3:boolean <- copy nil:literal)
      (4:integer <- copy 24:literal)
      (5:boolean <- copy t:literal)
      (6:integer-boolean-pair-array-address <- copy 12:literal)  ; unsafe
      (7:integer-boolean-pair-array <- copy 6:integer-boolean-pair-array-address/deref)
     ])))
;? (set dump-trace*)
;? (= dump-trace* (obj whitelist '("run" "mem" "sizeof")))
(run 'main)
;? (prn memory*)
(each routine completed-routines*
  (aif rep.routine!error (prn "error - " it)))
(when (~iso memory*.18 2)  ; variable 7
  (prn "F - indirect array copy in the presence of 'default-space'"))
;? (quit)

(reset)
(new-trace "len-array-indirect-scoped")
(add-code
  '((function main [
      (10:integer <- copy 30:literal)  ; pretend allocation
      (default-space:space-address <- copy 10:literal)  ; unsafe
      (1:integer <- copy 2:literal)  ; raw location 12
      (2:integer <- copy 23:literal)
      (3:boolean <- copy nil:literal)
      (4:integer <- copy 24:literal)
      (5:boolean <- copy t:literal)
      (6:integer-address <- copy 12:literal)  ; unsafe
      (7:integer <- length 6:integer-boolean-pair-array-address/deref)
     ])))
;? (= dump-trace* (obj whitelist '("run" "addr" "sz" "array-len")))
(run 'main)
;? (prn memory*)
(when (~iso memory*.18 2)
  (prn "F - 'len' accesses length of array address"))
;? (quit)

(reset)
(new-trace "default-space-shared")
(add-code
  '((function init-counter [
      (default-space:space-address <- new space:literal 30:literal)
      (1:integer <- copy 3:literal)  ; initialize to 3
      (reply default-space:space-address)
     ])
    (function increment-counter [
      (default-space:space-address <- next-input)
      (1:integer <- add 1:integer 1:literal)  ; increment
      (reply 1:integer)
     ])
    (function main [
      (1:space-address <- init-counter)
      (2:integer <- increment-counter 1:space-address)
      (3:integer <- increment-counter 1:space-address)
     ])))
(run 'main)
(each routine completed-routines*
  (aif rep.routine!error (prn "error - " it)))
;? (prn memory*)
(when (or (~is memory*.2 4)
          (~is memory*.3 5))
  (prn "F - multiple calls to a function can share locals"))
;? (quit)

(reset)
(new-trace "default-space-closure")
(add-code
  '((function init-counter [
      (default-space:space-address <- new space:literal 30:literal)
      (1:integer <- copy 3:literal)  ; initialize to 3
      (reply default-space:space-address)
     ])
    (function increment-counter [
      (default-space:space-address <- new space:literal 30:literal)
      (0:space-address <- next-input)  ; share outer space
      (1:integer/space:1 <- add 1:integer/space:1 1:literal)  ; increment
      (1:integer <- copy 34:literal)  ; dummy
      (reply 1:integer/space:1)
     ])
    (function main [
      (1:space-address <- init-counter)
      (2:integer <- increment-counter 1:space-address)
      (3:integer <- increment-counter 1:space-address)
     ])))
;? (set dump-trace*)
(run 'main)
(each routine completed-routines*
  (aif rep.routine!error (prn "error - " it)))
;? (prn memory*)
(when (or (~is memory*.2 4)
          (~is memory*.3 5))
  (prn "F - closures using /space metadata"))
;? (quit)

(reset)
(new-trace "default-space-closure-with-names")
(add-code
  '((function init-counter [
      (default-space:space-address <- new space:literal 30:literal)
      (x:integer <- copy 23:literal)
      (y:integer <- copy 3:literal)  ; correct copy of y
      (reply default-space:space-address)
     ])
    (function increment-counter [
      (default-space:space-address <- new space:literal 30:literal)
      (0:space-address/names:init-counter <- next-input)  ; outer space must be created by 'init-counter' above
      (y:integer/space:1 <- add y:integer/space:1 1:literal)  ; increment
      (y:integer <- copy 34:literal)  ; dummy
      (reply y:integer/space:1)
     ])
    (function main [
      (1:space-address/names:init-counter <- init-counter)
      (2:integer <- increment-counter 1:space-address/names:init-counter)
      (3:integer <- increment-counter 1:space-address/names:init-counter)
     ])))
;? (set dump-trace*)
(run 'main)
(each routine completed-routines*
  (aif rep.routine!error (prn "error - " it)))
;? (prn memory*)
(when (or (~is memory*.2 4)
          (~is memory*.3 5))
  (prn "F - /names to name variables in outer spaces"))
;? (quit)

(reset)
(new-trace "default-space-shared-with-names")
(add-code
  '((function f [
      (default-space:space-address <- new space:literal 30:literal)
      (x:integer <- copy 3:literal)
      (y:integer <- copy 4:literal)
      (reply default-space:space-address)
     ])
    (function g [
      (default-space:space-address/names:f <- next-input)
      (y:integer <- add y:integer 1:literal)
      (x:integer <- add x:integer 2:literal)
      (reply x:integer y:integer)
     ])
    (function main [
      (1:space-address <- f)
      (2:integer 3:integer <- g 1:space-address)
     ])))
(run 'main)
(each routine completed-routines*
  (aif rep.routine!error (prn "error - " it)))
(when (or (~is memory*.2 5)
          (~is memory*.3 5))
  (prn "F - override names for the default space"))

(reset)
(new-trace "default-space-shared-with-extra-names")
(add-code
  '((function f [
      (default-space:space-address <- new space:literal 30:literal)
      (x:integer <- copy 3:literal)
      (y:integer <- copy 4:literal)
      (reply default-space:space-address)
     ])
    (function g [
      (default-space:space-address/names:f <- next-input)
      (y:integer <- add y:integer 1:literal)
      (x:integer <- add x:integer 2:literal)
      (z:integer <- add x:integer y:integer)
      (reply z:integer)
     ])
    (function main [
      (1:space-address <- f)
      (2:integer <- g 1:space-address)
     ])))
(run 'main)
(each routine completed-routines*
  (aif rep.routine!error (prn "error - " it)))
(when (~is memory*.2 10)
  (prn "F - shared spaces can add new names"))

(reset)
(new-trace "default-space-shared-extra-names-dont-overlap-bindings")
(add-code
  '((function f [
      (default-space:space-address <- new space:literal 30:literal)
      (x:integer <- copy 3:literal)
      (y:integer <- copy 4:literal)
      (reply default-space:space-address)
     ])
    (function g [
      (default-space:space-address/names:f <- next-input)
      (y:integer <- add y:integer 1:literal)
      (x:integer <- add x:integer 2:literal)
      (z:integer <- copy 2:literal)
      (reply x:integer y:integer)
     ])
    (function main [
      (1:space-address <- f)
      (2:integer 3:integer <- g 1:space-address)
     ])))
(run 'main)
(each routine completed-routines*
  (aif rep.routine!error (prn "error - " it)))
;? (prn memory*) ;? 1
(when (or (~is memory*.2 5)
          (~is memory*.3 5))
  (prn "F - new names in shared spaces don't override old ones"))
;? (quit) ;? 1

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
      (default-space:space-address <- new space:literal 20:literal)
      (first-arg-box:tagged-value-address <- next-input)
      ; if given integers, add them
      { begin
        (first-arg:integer match?:boolean <- maybe-coerce first-arg-box:tagged-value-address/deref integer:literal)
        (break-unless match?:boolean)
        (second-arg-box:tagged-value-address <- next-input)
        (second-arg:integer <- maybe-coerce second-arg-box:tagged-value-address/deref integer:literal)
        (result:integer <- add first-arg:integer second-arg:integer)
        (reply result:integer)
      }
      (reply nil:literal)
     ])
    (function main [
      (1:tagged-value-address <- init-tagged-value integer:literal 34:literal)
      (2:tagged-value-address <- init-tagged-value integer:literal 3:literal)
      (3:integer <- test1 1:tagged-value-address 2:tagged-value-address)
     ])))
(run 'main)
;? (prn memory*)
(when (~is memory*.3 37)
  (prn "F - an example function that checks that its oarg is an integer"))
;? (quit)

(reset)
(new-trace "dispatch-multiple-clauses")
;? (set dump-trace*)
(add-code
  '((function test1 [
      (default-space:space-address <- new space:literal 20:literal)
      (first-arg-box:tagged-value-address <- next-input)
      ; if given integers, add them
      { begin
        (first-arg:integer match?:boolean <- maybe-coerce first-arg-box:tagged-value-address/deref integer:literal)
        (break-unless match?:boolean)
        (second-arg-box:tagged-value-address <- next-input)
        (second-arg:integer <- maybe-coerce second-arg-box:tagged-value-address/deref integer:literal)
        (result:integer <- add first-arg:integer second-arg:integer)
        (reply result:integer)
      }
      ; if given booleans, or them (it's a silly kind of generic function)
      { begin
        (first-arg:boolean match?:boolean <- maybe-coerce first-arg-box:tagged-value-address/deref boolean:literal)
        (break-unless match?:boolean)
        (second-arg-box:tagged-value-address <- next-input)
        (second-arg:boolean <- maybe-coerce second-arg-box:tagged-value-address/deref boolean:literal)
        (result:boolean <- or first-arg:boolean second-arg:boolean)
        (reply result:integer)
      }
      (reply nil:literal)
     ])
    (function main [
      (1:tagged-value-address <- init-tagged-value boolean:literal t:literal)
      (2:tagged-value-address <- init-tagged-value boolean:literal nil:literal)
      (3:boolean <- test1 1:tagged-value-address 2:tagged-value-address)
     ])))
;? (each stmt function*!test-fn
;?   (prn "  " stmt))
(run 'main)
;? (wipe dump-trace*)
;? (prn memory*)
(when (~is memory*.3 t)
  (prn "F - an example function that can do different things (dispatch) based on the type of its args or oargs"))
;? (quit)

(reset)
(new-trace "dispatch-multiple-calls")
(add-code
  '((function test1 [
      (default-space:space-address <- new space:literal 20:literal)
      (first-arg-box:tagged-value-address <- next-input)
      ; if given integers, add them
      { begin
        (first-arg:integer match?:boolean <- maybe-coerce first-arg-box:tagged-value-address/deref integer:literal)
        (break-unless match?:boolean)
        (second-arg-box:tagged-value-address <- next-input)
        (second-arg:integer <- maybe-coerce second-arg-box:tagged-value-address/deref integer:literal)
        (result:integer <- add first-arg:integer second-arg:integer)
        (reply result:integer)
      }
      ; if given booleans, or them (it's a silly kind of generic function)
      { begin
        (first-arg:boolean match?:boolean <- maybe-coerce first-arg-box:tagged-value-address/deref boolean:literal)
        (break-unless match?:boolean)
        (second-arg-box:tagged-value-address <- next-input)
        (second-arg:boolean <- maybe-coerce second-arg-box:tagged-value-address/deref boolean:literal)
        (result:boolean <- or first-arg:boolean second-arg:boolean)
        (reply result:integer)
      }
      (reply nil:literal)
     ])
    (function main [
      (1:tagged-value-address <- init-tagged-value boolean:literal t:literal)
      (2:tagged-value-address <- init-tagged-value boolean:literal nil:literal)
      (3:boolean <- test1 1:tagged-value-address 2:tagged-value-address)
      (10:tagged-value-address <- init-tagged-value integer:literal 34:literal)
      (11:tagged-value-address <- init-tagged-value integer:literal 3:literal)
      (12:integer <- test1 10:tagged-value-address 11:tagged-value-address)
     ])))
(run 'main)
;? (prn memory*)
(when (~and (is memory*.3 t) (is memory*.12 37))
  (prn "F - different calls can exercise different clauses of the same function"))

; We can also dispatch based on the type of the operands or results at the
; caller.

(reset)
(new-trace "dispatch-otype")
(add-code
  '((function test1 [
      (4:type <- otype 0:offset)
      { begin
        (5:boolean <- equal 4:type integer:literal)
        (break-unless 5:boolean)
        (6:integer <- next-input)
        (7:integer <- next-input)
        (8:integer <- add 6:integer 7:integer)
      }
      (reply 8:integer)
     ])
    (function main [
      (1:integer <- test1 1:literal 3:literal)
     ])))
(run 'main)
;? (prn memory*)
(when (~iso memory*.1 4)
  (prn "F - an example function that checks that its oarg is an integer"))
;? (quit)

(reset)
(new-trace "dispatch-otype-multiple-clauses")
;? (set dump-trace*)
(add-code
  '((function test1 [
      (4:type <- otype 0:offset)
      { begin
        ; integer needed? add args
        (5:boolean <- equal 4:type integer:literal)
        (break-unless 5:boolean)
        (6:integer <- next-input)
        (7:integer <- next-input)
        (8:integer <- add 6:integer 7:integer)
        (reply 8:integer)
      }
      { begin
        ; boolean needed? 'or' args
        (5:boolean <- equal 4:type boolean:literal)
        (break-unless 5:boolean 4:offset)
        (6:boolean <- next-input)
        (7:boolean <- next-input)
        (8:boolean <- or 6:boolean 7:boolean)
        (reply 8:boolean)
      }])
    (function main [
      (1:boolean <- test1 t:literal t:literal)
     ])))
;? (each stmt function*!test1
;?   (prn "  " stmt))
(run 'main)
;? (wipe dump-trace*)
;? (prn memory*)
(when (~is memory*.1 t)
  (prn "F - an example function that can do different things (dispatch) based on the type of its args or oargs"))
;? (quit)

(reset)
(new-trace "dispatch-otype-multiple-calls")
(add-code
  '((function test1 [
      (4:type <- otype 0:offset)
      { begin
        (5:boolean <- equal 4:type integer:literal)
        (break-unless 5:boolean)
        (6:integer <- next-input)
        (7:integer <- next-input)
        (8:integer <- add 6:integer 7:integer)
        (reply 8:integer)
      }
      { begin
        (5:boolean <- equal 4:type boolean:literal)
        (break-unless 5:boolean)
        (6:boolean <- next-input)
        (7:boolean <- next-input)
        (8:boolean <- or 6:boolean 7:boolean)
        (reply 8:boolean)
      }])
    (function main [
      (1:boolean <- test1 t:literal t:literal)
      (2:integer <- test1 3:literal 4:literal)
     ])))
(run 'main)
;? (prn memory*)
(when (~and (is memory*.1 t) (is memory*.2 7))
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
      (1:integer <- copy 3:literal)
     ])
    (function f2 [
      (2:integer <- copy 4:literal)
     ])))
(run 'f1 'f2)
(when (~iso 2 curr-cycle*)
  (prn "F - scheduler didn't run the right number of instructions: " curr-cycle*))
(when (~iso memory* (obj 1 3  2 4))
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
      (1:integer <- copy 0:literal)
      (1:integer <- copy 0:literal)
     ])
    (function f2 [
      (2:integer <- copy 0:literal)
      (2:integer <- copy 0:literal)
     ])))
;? (= dump-trace* (obj whitelist '("schedule")))
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
      (1:integer <- copy 0:literal)
     ])
    (function f2 [
      (2:integer <- copy 0:literal)
     ])))
; add one baseline routine to run (empty running-routines* handled below)
(enq make-routine!f1 running-routines*)
(assert (is 1 len.running-routines*))
; sleeping routine
(let routine make-routine!f2
  (= rep.routine!sleep '(until 23))
  (set sleeping-routines*.routine))
; not yet time for it to wake up
(= curr-cycle* 23)
;? (set dump-trace*)
;? (= dump-trace* (obj whitelist '("run" "schedule")))
(update-scheduler-state)
(when (~is 1 len.running-routines*)
  (prn "F - scheduler lets routines sleep"))

(reset)
(new-trace "scheduler-wakeup")
(= traces* (queue))
(add-code
  '((function f1 [
      (1:integer <- copy 0:literal)
     ])
    (function f2 [
      (2:integer <- copy 0:literal)
     ])))
; add one baseline routine to run (empty running-routines* handled below)
(enq make-routine!f1 running-routines*)
(assert (is 1 len.running-routines*))
; sleeping routine
(let routine make-routine!f2
  (= rep.routine!sleep '(until 23))
  (set sleeping-routines*.routine))
; time for it to wake up
(= curr-cycle* 24)
(update-scheduler-state)
(when (~is 2 len.running-routines*)
  (prn "F - scheduler wakes up sleeping routines at the right time"))

(reset)
(new-trace "scheduler-sleep-location")
(= traces* (queue))
(add-code
  '((function f1 [
      (1:integer <- copy 0:literal)
     ])
    (function f2 [
      (2:integer <- copy 0:literal)
     ])))
; add one baseline routine to run (empty running-routines* handled below)
(enq make-routine!f1 running-routines*)
(assert (is 1 len.running-routines*))
; blocked routine waiting for location 23 to change
(let routine make-routine!f2
  (= rep.routine!sleep '(until-location-changes 23 0))
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
(when (~is 1 len.running-routines*)
  (prn "F - scheduler lets routines block on locations"))
;? (quit)

(reset)
(new-trace "scheduler-wakeup-location")
(= traces* (queue))
(add-code
  '((function f1 [
      (1:integer <- copy 0:literal)
     ])
    (function f2 [
      (2:integer <- copy 0:literal)
     ])))
; add one baseline routine to run (empty running-routines* handled below)
(enq make-routine!f1 running-routines*)
(assert (is 1 len.running-routines*))
; blocked routine waiting for location 23 to change
(let routine make-routine!f2
  (= rep.routine!sleep '(until-location-changes 23 0))
  (set sleeping-routines*.routine))
; change memory location 23
(= memory*.23 1)
(update-scheduler-state)
; routine unblocked
(when (~is 2 len.running-routines*)
  (prn "F - scheduler unblocks routines blocked on locations"))

(reset)
(new-trace "scheduler-skip")
(= traces* (queue))
(add-code
  '((function f1 [
      (1:integer <- copy 0:literal)
     ])))
; running-routines* is empty
(assert (empty running-routines*))
; sleeping routine
(let routine make-routine!f1
  (= rep.routine!sleep '(until 34))
  (set sleeping-routines*.routine))
; long time left for it to wake up
(= curr-cycle* 0)
(update-scheduler-state)
;? (prn curr-cycle*)
(assert (is curr-cycle* 35))
(when (~is 1 len.running-routines*)
  (prn "F - scheduler skips ahead to earliest sleeping routines when nothing to run"))

(reset)
(new-trace "scheduler-deadlock")
(= traces* (queue))
(add-code
  '((function f1 [
      (1:integer <- copy 0:literal)
     ])))
(assert (empty running-routines*))
(assert (empty completed-routines*))
; blocked routine
(let routine make-routine!f1
  (= rep.routine!sleep '(until-location-changes 23 0))
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
      (1:integer <- copy 0:literal)
     ])))
; running-routines* is empty
(assert (empty running-routines*))
; blocked routine
(let routine make-routine!f1
  (= rep.routine!sleep '(until-location-changes 23 0))
  (set sleeping-routines*.routine))
; but is about to become ready
(= memory*.23 1)
(update-scheduler-state)
(when (~empty completed-routines*)
  (prn "F - scheduler ignores sleeping but ready threads when detecting deadlock"))

; Helper routines are just to sidestep the deadlock test; they stop running
; when there's no non-helper routines left to run.
;
; Be careful not to overuse them. In particular, the component under test
; should never run in a helper routine; that'll make interrupting and
; restarting it very brittle.
(reset)
(new-trace "scheduler-helper")
(= traces* (queue))
(add-code
  '((function f1 [
      (1:integer <- copy 0:literal)
     ])))
; just a helper routine
(= routine* make-routine!f1)
(set rep.routine*!helper)
;? (= dump-trace* (obj whitelist '("schedule")))
(update-scheduler-state)
(when (or (~empty running-routines*) (~empty sleeping-routines*))
  (prn "F - scheduler stops when there's only helper routines left"))

(reset)
(new-trace "scheduler-helper-sleeping")
(= traces* (queue))
(add-code
  '((function f1 [
      (1:integer <- copy 0:literal)
     ])))
; just a helper routine
(let routine make-routine!f1
  (set rep.routine!helper)
  (= rep.routine!sleep '(until-location-changes 23 nil))
  (set sleeping-routines*.routine))
;? (= dump-trace* (obj whitelist '("schedule")))
;? (prn "1 " running-routines*)
;? (prn sleeping-routines*)
(update-scheduler-state)
;? (prn "2 " running-routines*)
;? (prn sleeping-routines*)
(when (or (~empty running-routines*) (~empty sleeping-routines*))
  (prn "F - scheduler stops when there's only sleeping helper routines left"))

(reset)
(new-trace "scheduler-termination")
(= traces* (queue))
(add-code
  '((function f1 [
      (1:integer <- copy 0:literal)
     ])))
; all routines done
(update-scheduler-state)
(check-trace-doesnt-contain "scheduler helper check shouldn't trigger unless necessary"
  '(("schedule" "just helpers left")))

; both running and sleeping helpers
; running helper and sleeping non-helper
; sleeping helper and running non-helper

(reset)
(new-trace "scheduler-account-slice")
; function running an infinite loop
(add-code
  '((function f1 [
      { begin
        (1:integer <- copy 0:literal)
        (loop)
      }
     ])))
(let routine make-routine!f1
  (= rep.routine!limit 10)
  (enq routine running-routines*))
(= scheduling-interval* 20)
(run)
(when (or (empty completed-routines*)
          (~is -10 ((rep completed-routines*.0) 'limit)))
  (prn "F - when given a low cycle limit, a routine runs to end of time slice"))

(reset)
(new-trace "scheduler-account-slice-multiple")
; function running an infinite loop
(add-code
  '((function f1 [
      { begin
        (1:integer <- copy 0:literal)
        (loop)
      }
     ])))
(let routine make-routine!f1
  (= rep.routine!limit 100)
  (enq routine running-routines*))
(= scheduling-interval* 20)
(run)
(when (or (empty completed-routines*)
          (~is -0 ((rep completed-routines*.0) 'limit)))
  (prn "F - when given a high limit, a routine successfully stops after multiple time slices"))

(reset)
(new-trace "scheduler-account-run-while-asleep")
(add-code
    ; f1 needs 4 cycles of sleep time, 4 cycles of work
  '((function f1 [
      (sleep for-some-cycles:literal 4:literal)
      (i:integer <- copy 0:literal)
      (i:integer <- copy 0:literal)
      (i:integer <- copy 0:literal)
      (i:integer <- copy 0:literal)
     ])))
(let routine make-routine!f1
  (= rep.routine!limit 6)  ; enough time excluding sleep
  (enq routine running-routines*))
(= scheduling-interval* 1)
;? (= dump-trace* (obj whitelist '("schedule")))
(run)
; if time slept counts against limit, routine doesn't have time to complete
(when (ran-to-completion 'f1)
  (prn "F - time slept counts against a routine's cycle limit"))
;? (quit)

(reset)
(new-trace "scheduler-account-stop-on-preempt")
(add-code
  '((function baseline [
      (i:integer <- copy 0:literal)
      { begin
        (done?:boolean <- greater-or-equal i:integer 10:literal)
        (break-if done?:boolean)
        (1:integer <- add i:integer 1:literal)
        (loop)
      }
     ])
    (function f1 [
      (i:integer <- copy 0:literal)
      { begin
        (done?:boolean <- greater-or-equal i:integer 6:literal)
        (break-if done?:boolean)
        (1:integer <- add i:integer 1:literal)
        (loop)
      }
     ])))
(let routine make-routine!baseline
  (enq routine running-routines*))
; now add the routine we care about
(let routine make-routine!f1
  (= rep.routine!limit 40)  ; less than 2x time f1 needs to complete
  (enq routine running-routines*))
(= scheduling-interval* 1)
; if baseline's time were to count against f1's limit, it wouldn't be able to
; complete.
(when (~ran-to-completion 'f1)
  (prn "F - preempted time doesn't count against a routine's limit"))
;? (quit)

(reset)
(new-trace "scheduler-sleep-timeout")
(add-code
  '((function baseline [
      (i:integer <- copy 0:literal)
      { begin
        (done?:boolean <- greater-or-equal i:integer 10:literal)
        (break-if done?:boolean)
        (1:integer <- add i:integer 1:literal)
        (loop)
      }
     ])
    (function f1 [
      (sleep for-some-cycles:literal 10:literal)  ; less time than baseline would take to run
     ])))
; add baseline routine to prevent cycle-skipping
(let routine make-routine!baseline
  (enq routine running-routines*))
; now add the routine we care about
(let routine make-routine!f1
  (= rep.routine!limit 4)  ; less time than f1 would take to run
  (enq routine running-routines*))
(= scheduling-interval* 1)
;? (= dump-trace* (obj whitelist '("schedule")))
(run)
(when (ran-to-completion 'f1)
  (prn "F - sleeping routines can time out"))
;? (quit)

(reset)
(new-trace "sleep")
(add-code
  '((function f1 [
      (sleep for-some-cycles:literal 1:literal)
      (1:integer <- copy 0:literal)
      (1:integer <- copy 0:literal)
     ])
    (function f2 [
      (2:integer <- copy 0:literal)
      (2:integer <- copy 0:literal)
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
      (sleep for-some-cycles:literal 20:literal)
      (1:integer <- copy 0:literal)
      (1:integer <- copy 0:literal)
     ])
    (function f2 [
      (2:integer <- copy 0:literal)
      (2:integer <- copy 0:literal)
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
      (1:integer <- copy 0:literal)
      (sleep until-location-changes:literal 1:integer)
      (2:integer <- add 1:integer 1:literal)
     ])
    (function f2 [
      (sleep for-some-cycles:literal 30:literal)
      (1:integer <- copy 3:literal)  ; set to value
     ])))
;? (= dump-trace* (obj whitelist '("run" "schedule")))
;? (set dump-trace*)
(run 'f1 'f2)
;? (prn int-canon.memory*)
(each routine completed-routines*
  (aif rep.routine!error (prn "error - " it)))
(when (~is memory*.2 4)  ; successor of value
  (prn "F - sleep can block on a memory location"))
;? (quit)

(reset)
(new-trace "sleep-scoped-location")
(add-code
  '((function f1 [
      ; waits for memory location 1 to be changed, before computing its successor
      (10:integer <- copy 5:literal)  ; array of locals
      (default-space:space-address <- copy 10:literal)
      (1:integer <- copy 23:literal)  ; really location 12
      (sleep until-location-changes:literal 1:integer)
      (2:integer <- add 1:integer 1:literal)
     ])
    (function f2 [
      (sleep for-some-cycles:literal 30:literal)
      (12:integer <- copy 3:literal)  ; set to value
     ])))
;? (= dump-trace* (obj whitelist '("run" "schedule")))
(run 'f1 'f2)
(when (~is memory*.13 4)  ; successor of value
  (prn "F - sleep can block on a scoped memory location"))
;? (quit)

(reset)
(new-trace "fork")
(add-code
  '((function f1 [
      (1:integer <- copy 4:literal)
     ])
    (function main [
      (fork f1:fn)
     ])))
(run 'main)
(when (~iso memory*.1 4)
  (prn "F - fork works"))

(reset)
(new-trace "fork-returns-id")
(add-code
  '((function f1 [
      (1:integer <- copy 4:literal)
     ])
    (function main [
      (2:integer <- fork f1:fn)
     ])))
(run 'main)
;? (prn memory*)
(when (no memory*.2)
  (prn "F - fork returns a pid for the new routine"))

(reset)
(new-trace "fork-returns-unique-id")
(add-code
  '((function f1 [
      (1:integer <- copy 4:literal)
     ])
    (function main [
      (2:integer <- fork f1:fn)
      (3:integer <- fork f1:fn)
     ])))
(run 'main)
(when (or (no memory*.2)
          (no memory*.3)
          (is memory*.2 memory*.3))
  (prn "F - fork returns a unique pid everytime"))

(reset)
(new-trace "fork-with-args")
(add-code
  '((function f1 [
      (2:integer <- next-input)
     ])
    (function main [
      (fork f1:fn nil:literal/globals nil:literal/limit 4:literal)
     ])))
(run 'main)
(when (~iso memory*.2 4)
  (prn "F - fork can pass args"))

(reset)
(new-trace "fork-copies-args")
(add-code
  '((function f1 [
      (2:integer <- next-input)
     ])
    (function main [
      (default-space:space-address <- new space:literal 5:literal)
      (x:integer <- copy 4:literal)
      (fork f1:fn nil:literal/globals nil:literal/limit x:integer)
      (x:integer <- copy 0:literal)  ; should be ignored
     ])))
(run 'main)
(when (~iso memory*.2 4)
  (prn "F - fork passes args by value"))

(reset)
(new-trace "fork-global")
(add-code
  '((function f1 [
      (1:integer/raw <- copy 2:integer/space:global)
     ])
    (function main [
      (default-space:space-address <- new space:literal 5:literal)
      (2:integer <- copy 4:literal)
      (fork f1:fn default-space:space-address/globals nil:literal/limit)
     ])))
(run 'main)
(each routine completed-routines*
  (awhen rep.routine!error (prn "error - " it)))
(when (~iso memory*.1 4)
  (prn "F - fork can take a space of global variables to access"))

(reset)
(new-trace "fork-limit")
(add-code
  '((function f1 [
      { begin
        (loop)
      }
     ])
    (function main [
      (fork f1:fn nil:literal/globals 30:literal/limit)
     ])))
(= scheduling-interval* 5)
(run 'main)
(each routine completed-routines*
  (awhen rep.routine!error (prn "error - " it)))
(when (ran-to-completion 'f1)
  (prn "F - fork can specify a maximum cycle limit"))

(reset)
(new-trace "fork-then-wait")
(add-code
  '((function f1 [
      { begin
        (loop)
      }
     ])
    (function main [
      (1:integer/routine-id <- fork f1:fn nil:literal/globals 30:literal/limit)
      (sleep until-routine-done:literal 1:integer/routine-id)
      (2:integer <- copy 34:literal)
     ])))
(= scheduling-interval* 5)
;? (= dump-trace* (obj whitelist '("schedule")))
(run 'main)
(each routine completed-routines*
  (awhen rep.routine!error (prn "error - " it)))
(check-trace-contents "scheduler orders functions correctly"
  '(("schedule" "pushing main to sleep queue")
    ("schedule" "scheduling f1")
    ("schedule" "ran out of time")
    ("schedule" "waking up main")
  ))
;? (quit)

; todo: Haven't yet written several tests
;   that restarting a routine works
;     when it died
;     when it timed out
;     when it completed
;   running multiple routines in tandem
; first example using these features: read-move-incomplete in chessboard-cursor.arc.t

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
      (1:integer <- copy 2:literal)
      (2:integer <- copy 23:literal)
      (3:integer <- copy 24:literal)
      (4:integer <- index 1:integer-array 2:literal)
     ])))
;? (set dump-trace*)
(run 'main)
;? (prn memory*)
(let routine (car completed-routines*)
  (when (no rep.routine!error)
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
      (1:channel-address <- init-channel 3:literal)
      (2:integer <- get 1:channel-address/deref first-full:offset)
      (3:integer <- get 1:channel-address/deref first-free:offset)
     ])))
;? (set dump-trace*)
(run 'main)
;? (prn memory*)
(when (or (~is 0 memory*.2)
          (~is 0 memory*.3))
  (prn "F - 'init-channel' initializes 'first-full and 'first-free to 0"))

(reset)
(new-trace "channel-write")
(add-code
  '((function main [
      (1:channel-address <- init-channel 3:literal)
      (2:integer <- copy 34:literal)
      (3:tagged-value <- save-type 2:integer)
      (1:channel-address/deref <- write 1:channel-address 3:tagged-value)
      (5:integer <- get 1:channel-address/deref first-full:offset)
      (6:integer <- get 1:channel-address/deref first-free:offset)
     ])))
;? (prn function*!write)
;? (set dump-trace*)
;? (= dump-trace* (obj blacklist '("sz" "mem" "addr" "array-len" "cvt0" "cvt1")))
;? (= dump-trace* (obj whitelist '("jump")))
;? (= dump-trace* (obj whitelist '("run" "reply")))
(run 'main)
(each routine completed-routines*
  (aif rep.routine!error (prn "error - " it)))
;? (prn canon.memory*)
(when (or (~is 0 memory*.5)
          (~is 1 memory*.6))
  (prn "F - 'write' enqueues item to channel"))
;? (quit)

(reset)
(new-trace "channel-read")
(add-code
  '((function main [
      (1:channel-address <- init-channel 3:literal)
      (2:integer <- copy 34:literal)
      (3:tagged-value <- save-type 2:integer)
      (1:channel-address/deref <- write 1:channel-address 3:tagged-value)
      (5:tagged-value 1:channel-address/deref <- read 1:channel-address)
      (7:integer <- maybe-coerce 5:tagged-value integer:literal)
      (8:integer <- get 1:channel-address/deref first-full:offset)
      (9:integer <- get 1:channel-address/deref first-free:offset)
     ])))
;? (set dump-trace*)
;? (= dump-trace* (obj blacklist '("sz" "mem" "addr" "array-len" "cvt0" "cvt1")))
(run 'main)
;? (prn int-canon.memory*)
(when (~is memory*.7 34)
  (prn "F - 'read' returns written value"))
(when (or (~is 1 memory*.8)
          (~is 1 memory*.9))
  (prn "F - 'read' dequeues item from channel"))

(reset)
(new-trace "channel-write-wrap")
(add-code
  '((function main [
      ; channel with 1 slot
      (1:channel-address <- init-channel 1:literal)
      ; write a value
      (2:integer <- copy 34:literal)
      (3:tagged-value <- save-type 2:integer)
      (1:channel-address/deref <- write 1:channel-address 3:tagged-value)
      ; first-free will now be 1
      (5:integer <- get 1:channel-address/deref first-free:offset)
      ; read one value
      (_ 1:channel-address/deref <- read 1:channel-address)
      ; write a second value; verify that first-free wraps around to 0.
      (1:channel-address/deref <- write 1:channel-address 3:tagged-value)
      (6:integer <- get 1:channel-address/deref first-free:offset)
     ])))
;? (set dump-trace*)
;? (= dump-trace* (obj blacklist '("sz" "mem" "addr" "array-len" "cvt0" "cvt1")))
(run 'main)
;? (prn canon.memory*)
(when (or (~is 1 memory*.5)
          (~is 0 memory*.6))
  (prn "F - 'write' can wrap pointer back to start"))

(reset)
(new-trace "channel-read-wrap")
(add-code
  '((function main [
      ; channel with 1 slot
      (1:channel-address <- init-channel 1:literal)
      ; write a value
      (2:integer <- copy 34:literal)
      (3:tagged-value <- save-type 2:integer)
      (1:channel-address/deref <- write 1:channel-address 3:tagged-value)
      ; read one value
      (_ 1:channel-address/deref <- read 1:channel-address)
      ; first-full will now be 1
      (5:integer <- get 1:channel-address/deref first-full:offset)
      ; write a second value
      (1:channel-address/deref <- write 1:channel-address 3:tagged-value)
      ; read second value; verify that first-full wraps around to 0.
      (_ 1:channel-address/deref <- read 1:channel-address)
      (6:integer <- get 1:channel-address/deref first-full:offset)
     ])))
;? (set dump-trace*)
;? (= dump-trace* (obj blacklist '("sz" "mem" "addr" "array-len" "cvt0" "cvt1")))
(run 'main)
;? (prn canon.memory*)
(when (or (~is 1 memory*.5)
          (~is 0 memory*.6))
  (prn "F - 'read' can wrap pointer back to start"))

(reset)
(new-trace "channel-new-empty-not-full")
(add-code
  '((function main [
      (1:channel-address <- init-channel 3:literal)
      (2:boolean <- empty? 1:channel-address/deref)
      (3:boolean <- full? 1:channel-address/deref)
     ])))
;? (set dump-trace*)
(run 'main)
;? (prn memory*)
(when (or (~is t memory*.2)
          (~is nil memory*.3))
  (prn "F - a new channel is always empty, never full"))

(reset)
(new-trace "channel-write-not-empty")
(add-code
  '((function main [
      (1:channel-address <- init-channel 3:literal)
      (2:integer <- copy 34:literal)
      (3:tagged-value <- save-type 2:integer)
      (1:channel-address/deref <- write 1:channel-address 3:tagged-value)
      (5:boolean <- empty? 1:channel-address/deref)
      (6:boolean <- full? 1:channel-address/deref)
     ])))
;? (set dump-trace*)
(run 'main)
;? (prn memory*)
(when (or (~is nil memory*.5)
          (~is nil memory*.6))
  (prn "F - a channel after writing is never empty"))

(reset)
(new-trace "channel-write-full")
(add-code
  '((function main [
      (1:channel-address <- init-channel 1:literal)
      (2:integer <- copy 34:literal)
      (3:tagged-value <- save-type 2:integer)
      (1:channel-address/deref <- write 1:channel-address 3:tagged-value)
      (5:boolean <- empty? 1:channel-address/deref)
      (6:boolean <- full? 1:channel-address/deref)
     ])))
;? (set dump-trace*)
(run 'main)
;? (prn memory*)
(when (or (~is nil memory*.5)
          (~is t memory*.6))
  (prn "F - a channel after writing may be full"))

(reset)
(new-trace "channel-read-not-full")
(add-code
  '((function main [
      (1:channel-address <- init-channel 3:literal)
      (2:integer <- copy 34:literal)
      (3:tagged-value <- save-type 2:integer)
      (1:channel-address/deref <- write 1:channel-address 3:tagged-value)
      (1:channel-address/deref <- write 1:channel-address 3:tagged-value)
      (_ 1:channel-address/deref <- read 1:channel-address)
      (5:boolean <- empty? 1:channel-address/deref)
      (6:boolean <- full? 1:channel-address/deref)
     ])))
;? (set dump-trace*)
(run 'main)
;? (prn memory*)
(when (or (~is nil memory*.5)
          (~is nil memory*.6))
  (prn "F - a channel after reading is never full"))

(reset)
(new-trace "channel-read-empty")
(add-code
  '((function main [
      (1:channel-address <- init-channel 3:literal)
      (2:integer <- copy 34:literal)
      (3:tagged-value <- save-type 2:integer)
      (1:channel-address/deref <- write 1:channel-address 3:tagged-value)
      (_ 1:channel-address/deref <- read 1:channel-address)
      (5:boolean <- empty? 1:channel-address/deref)
      (6:boolean <- full? 1:channel-address/deref)
     ])))
;? (set dump-trace*)
(run 'main)
;? (prn memory*)
(when (or (~is t memory*.5)
          (~is nil memory*.6))
  (prn "F - a channel after reading may be empty"))

; The key property of channels; writing to a full channel blocks the current
; routine until it creates space. Ditto reading from an empty channel.

(reset)
(new-trace "channel-read-block")
(add-code
  '((function main [
      (1:channel-address <- init-channel 3:literal)
      ; channel is empty, but receives a read
      (2:tagged-value 1:channel-address/deref <- read 1:channel-address)
     ])))
;? (set dump-trace*)
;? (= dump-trace* (obj whitelist '("run" "schedule")))
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
      (1:channel-address <- init-channel 1:literal)
      (2:integer <- copy 34:literal)
      (3:tagged-value <- save-type 2:integer)
      (1:channel-address/deref <- write 1:channel-address 3:tagged-value)
      ; channel has capacity 1, but receives a second write
      (1:channel-address/deref <- write 1:channel-address 3:tagged-value)
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
  '((function consumer [
      (default-space:space-address <- new space:literal 30:literal)
      (chan:channel-address <- init-channel 3:literal)  ; create a channel
      (fork producer:fn nil:literal/globals nil:literal/limit chan:channel-address)  ; fork a routine to produce a value in it
      (1:tagged-value/raw <- read chan:channel-address)  ; wait for input on channel
     ])
    (function producer [
      (default-space:space-address <- new space:literal 30:literal)
      (n:integer <- copy 24:literal)
      (ochan:channel-address <- next-input)
      (x:tagged-value <- save-type n:integer)
      (ochan:channel-address/deref <- write ochan:channel-address x:tagged-value)
     ])))
;? (set dump-trace*)
;? (= dump-trace* (obj whitelist '("schedule" "run" "addr")))
;? (= dump-trace* (obj whitelist '("-")))
(run 'consumer)
;? (prn memory*)
(each routine completed-routines*
  (aif rep.routine!error (prn "error - " it)))
(when (~is 24 memory*.2)  ; location 1 contains tagged-value x above
  (prn "F - channels are meant to be shared between routines"))
;? (quit)

(reset)
(new-trace "channel-handoff-routine")
(add-code
  '((function consumer [
      (default-space:space-address <- new space:literal 30:literal)
      (1:channel-address <- init-channel 3:literal)  ; create a channel
      (fork producer:fn default-space:space-address/globals nil:literal/limit)  ; pass it as a global to another routine
      (1:tagged-value/raw <- read 1:channel-address)  ; wait for input on channel
     ])
    (function producer [
      (default-space:space-address <- new space:literal 30:literal)
      (n:integer <- copy 24:literal)
      (x:tagged-value <- save-type n:integer)
      (1:channel-address/space:global/deref <- write 1:channel-address/space:global x:tagged-value)
     ])))
(run 'consumer)
(each routine completed-routines*
  (aif rep.routine!error (prn "error - " it)))
(when (~is 24 memory*.2)  ; location 1 contains tagged-value x above
  (prn "F - channels are meant to be shared between routines"))

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
(when (~iso (convert-quotes
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
(when (~iso (convert-quotes
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
(when (~iso (convert-quotes
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
(when (~iso (convert-quotes
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
(add-code
  '((before label1 [
     (2:integer <- copy 0:literal)
    ])))
(when (~iso (as cons before*!label1)
            '(; fragment
              (
                (2:integer <- copy 0:literal))))
  (prn "F - 'before' records fragments of code to insert before labels"))

(when (~iso (insert-code
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
(add-code
  '((before label1 [
      (2:integer <- copy 0:literal)
     ])
    (before label1 [
      (3:integer <- copy 0:literal)
     ])))
(when (~iso (as cons before*!label1)
            '(; fragment
              (
                (2:integer <- copy 0:literal))
              (
                (3:integer <- copy 0:literal))))
  (prn "F - 'before' records fragments in order"))

(when (~iso (insert-code
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
(add-code
  '((before f/label1 [  ; label1 only inside function f
     (2:integer <- copy 0:literal)
    ])))
(when (~iso (insert-code
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
(add-code
  '((before f/label1 [  ; label1 only inside function f
      (2:integer <- copy 0:literal)
     ])))
(when (~iso (insert-code
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
(add-code
  '((after label1 [
      (2:integer <- copy 0:literal)
     ])))
(when (~iso (as cons after*!label1)
            '(; fragment
              (
                (2:integer <- copy 0:literal))))
  (prn "F - 'after' records fragments of code to insert after labels"))

(when (~iso (insert-code
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
(add-code
  '((after label1 [
      (2:integer <- copy 0:literal)
     ])
    (after label1 [
      (3:integer <- copy 0:literal)
     ])))
(when (~iso (as cons after*!label1)
            '(; fragment
              (
                (3:integer <- copy 0:literal))
              (
                (2:integer <- copy 0:literal))))
  (prn "F - 'after' records fragments in *reverse* order"))

(when (~iso (insert-code
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
(add-code
  '((before label1 [
      (2:integer <- copy 0:literal)
     ])
    (after label1 [
      (3:integer <- copy 0:literal)
     ])))
(when (and (~iso (as cons before*!label1)
                 '(; fragment
                   (
                     (2:integer <- copy 0:literal))))
           (~iso (as cons after*!label1)
                 '(; fragment
                   (
                     (3:integer <- copy 0:literal)))))
  (prn "F - 'before' and 'after' fragments work together"))

(when (~iso (insert-code
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
(add-code
  '((before label1 [
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
(when (or (~iso (as cons before*!label1)
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

(when (~iso (insert-code
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
(when (~iso (do
              (reset)
              (add-code
                '((before label1 [
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
              (add-code
                '((before label1 [
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
(add-code
  '((after label1 [
      (1:integer <- copy 0:literal)
     ])
    (function f1 [
      { begin
        label1
      }
     ])))
;? (= dump-trace* (obj whitelist '("cn0")))
(freeze function*)
(when (~iso function*!f1
            '(label1
              (((1 integer)) <- ((copy)) ((0 literal)))))
  (prn "F - before/after works inside blocks"))

(reset)
(new-trace "before-after-any-order")
(= traces* (queue))
(= function* (table))
(add-code
  '((function f1 [
      { begin
        label1
      }
     ])
    (after label1 [
       (1:integer <- copy 0:literal)
     ])))
(freeze function*)
(when (~iso function*!f1
            '(label1
              (((1 integer)) <- ((copy)) ((0 literal)))))
  (prn "F - before/after can come after the function they need to modify"))
;? (quit)

(reset)
(new-trace "multiple-defs")
(= traces* (queue))
(= function* (table))
(add-code
  '((function f1 [
      (1:integer <- copy 0:literal)
     ])
    (function f1 [
      (2:integer <- copy 0:literal)
     ])))
(freeze function*)
(when (~iso function*!f1
            '((((2 integer)) <- ((copy)) ((0 literal)))
              (((1 integer)) <- ((copy)) ((0 literal)))))
  (prn "F - multiple 'def' of the same function add clauses"))

(reset)
(new-trace "def!")
(= traces* (queue))
(= function* (table))
(add-code
  '((function f1 [
      (1:integer <- copy 0:literal)
     ])
    (function! f1 [
      (2:integer <- copy 0:literal)
     ])))
(freeze function*)
(when (~iso function*!f1
            '((((2 integer)) <- ((copy)) ((0 literal)))))
  (prn "F - 'def!' clears all previous clauses"))

)  ; section 10

;; ---

(section 100

; String utilities

(reset)
(new-trace "string-new")
(add-code
  '((function main [
      (1:string-address <- new string:literal 5:literal)
     ])))
(let routine make-routine!main
  (enq routine running-routines*)
  (let before rep.routine!alloc
    (run)
    (when (~iso rep.routine!alloc (+ before 5 1))
      (prn "F - 'new' allocates arrays of bytes for strings"))))

; Convenience: initialize strings using string literals
(reset)
(new-trace "string-literal")
(add-code
  '((function main [
      (1:string-address <- new "hello")
     ])))
(let routine make-routine!main
  (enq routine running-routines*)
  (let before rep.routine!alloc
;?     (set dump-trace*)
;?     (= dump-trace* (obj whitelist '("schedule" "run" "addr")))
    (run)
    (when (~iso rep.routine!alloc (+ before 5 1))
      (prn "F - 'new' allocates arrays of bytes for string literals"))
    (when (~memory-contains-array before "hello")
      (prn "F - 'new' initializes allocated memory to string literal"))))

(reset)
(new-trace "string-equal")
(add-code
  '((function main [
      (1:string-address <- new "hello")
      (2:string-address <- new "hello")
      (3:boolean <- string-equal 1:string-address 2:string-address)
     ])))
(run 'main)
(when (~iso memory*.3 t)
  (prn "F - 'string-equal'"))

(reset)
(new-trace "string-equal-empty")
(add-code
  '((function main [
      (1:string-address <- new "")
      (2:string-address <- new "")
      (3:boolean <- string-equal 1:string-address 2:string-address)
     ])))
(run 'main)
(when (~iso memory*.3 t)
  (prn "F - 'string-equal' works on empty strings"))

(reset)
(new-trace "string-equal-compare-with-empty")
(add-code
  '((function main [
      (1:string-address <- new "a")
      (2:string-address <- new "")
      (3:boolean <- string-equal 1:string-address 2:string-address)
     ])))
(run 'main)
(when (~iso memory*.3 nil)
  (prn "F - 'string-equal' compares correctly with empty strings"))

(reset)
(new-trace "string-equal-compares-length")
(add-code
  '((function main [
      (1:string-address <- new "a")
      (2:string-address <- new "ab")
      (3:boolean <- string-equal 1:string-address 2:string-address)
     ])))
(run 'main)
(when (~iso memory*.3 nil)
  (prn "F - 'string-equal' handles differing lengths"))

(reset)
(new-trace "string-equal-compares-initial-element")
(add-code
  '((function main [
      (1:string-address <- new "aa")
      (2:string-address <- new "ba")
      (3:boolean <- string-equal 1:string-address 2:string-address)
     ])))
(run 'main)
(when (~iso memory*.3 nil)
  (prn "F - 'string-equal' handles inequal final byte"))

(reset)
(new-trace "string-equal-compares-final-element")
(add-code
  '((function main [
      (1:string-address <- new "ab")
      (2:string-address <- new "aa")
      (3:boolean <- string-equal 1:string-address 2:string-address)
     ])))
(run 'main)
(when (~iso memory*.3 nil)
  (prn "F - 'string-equal' handles inequal final byte"))

(reset)
(new-trace "string-equal-reflexive")
(add-code
  '((function main [
      (1:string-address <- new "ab")
      (3:boolean <- string-equal 1:string-address 1:string-address)
     ])))
(run 'main)
(when (~iso memory*.3 t)
  (prn "F - 'string-equal' handles identical pointer"))

(reset)
(new-trace "strcat")
(add-code
  '((function main [
      (1:string-address <- new "hello,")
      (2:string-address <- new " world!")
      (3:string-address <- strcat 1:string-address 2:string-address)
     ])))
;? (= dump-trace* (obj whitelist '("run"))) ;? 1
(run 'main)
(when (~memory-contains-array memory*.3 "hello, world!")
  (prn "F - 'strcat' concatenates strings"))
;? (quit) ;? 1

(reset)
(new-trace "interpolate")
(add-code
  '((function main [
      (1:string-address <- new "hello, _!")
      (2:string-address <- new "abc")
      (3:string-address <- interpolate 1:string-address 2:string-address)
     ])))
;? (= dump-trace* (obj whitelist '("run")))
(run 'main)
(when (~memory-contains-array memory*.3 "hello, abc!")
  (prn "F - 'interpolate' splices strings"))

(reset)
(new-trace "interpolate-empty")
(add-code
  '((function main [
      (1:string-address <- new "hello!")
      (2:string-address <- new "abc")
      (3:string-address <- interpolate 1:string-address 2:string-address)
     ])))
;? (= dump-trace* (obj whitelist '("run")))
(run 'main)
(when (~memory-contains-array memory*.3 "hello!")
  (prn "F - 'interpolate' without underscore returns template"))

(reset)
(new-trace "interpolate-at-start")
(add-code
  '((function main [
      (1:string-address <- new "_, hello!")
      (2:string-address <- new "abc")
      (3:string-address <- interpolate 1:string-address 2:string-address)
     ])))
;? (= dump-trace* (obj whitelist '("run")))
(run 'main)
(when (~memory-contains-array memory*.3 "abc, hello")
  (prn "F - 'interpolate' splices strings at start"))

(reset)
(new-trace "interpolate-at-end")
(add-code
  '((function main [
      (1:string-address <- new "hello, _")
      (2:string-address <- new "abc")
      (3:string-address <- interpolate 1:string-address 2:string-address)
     ])))
;? (= dump-trace* (obj whitelist '("run")))
(run 'main)
(when (~memory-contains-array memory*.3 "hello, abc")
  (prn "F - 'interpolate' splices strings at start"))

(reset)
(new-trace "interpolate-varargs")
(add-code
  '((function main [
      (1:string-address <- new "hello, _, _, and _!")
      (2:string-address <- new "abc")
      (3:string-address <- new "def")
      (4:string-address <- new "ghi")
      (5:string-address <- interpolate 1:string-address 2:string-address 3:string-address 4:string-address)
     ])))
;? (= dump-trace* (obj whitelist '("run")))
;? (= dump-trace* (obj whitelist '("run" "array-info")))
;? (set dump-trace*)
(run 'main)
;? (quit)
;? (up i 1 (+ 1 (memory* memory*.5))
;?   (prn (memory* (+ memory*.5 i))))
(when (~memory-contains-array memory*.5 "hello, abc, def, and ghi!")
  (prn "F - 'interpolate' splices in any number of strings"))

(reset)
(new-trace "string-find-next")
(add-code
  '((function main [
      (1:string-address <- new "a/b")
      (2:integer <- find-next 1:string-address ((#\/ literal)) 0:literal)
     ])))
(run 'main)
(when (~is memory*.2 1)
  (prn "F - 'find-next' finds first location of a character"))

(reset)
(new-trace "string-find-next-empty")
(add-code
  '((function main [
      (1:string-address <- new "")
      (2:integer <- find-next 1:string-address ((#\/ literal)) 0:literal)
     ])))
(run 'main)
(each routine completed-routines*
  (aif rep.routine!error (prn "error - " it)))
(when (~is memory*.2 0)
  (prn "F - 'find-next' finds first location of a character"))

(reset)
(new-trace "string-find-next-initial")
(add-code
  '((function main [
      (1:string-address <- new "/abc")
      (2:integer <- find-next 1:string-address ((#\/ literal)) 0:literal)
     ])))
(run 'main)
(when (~is memory*.2 0)
  (prn "F - 'find-next' handles prefix match"))

(reset)
(new-trace "string-find-next-final")
(add-code
  '((function main [
      (1:string-address <- new "abc/")
      (2:integer <- find-next 1:string-address ((#\/ literal)) 0:literal)
     ])))
(run 'main)
;? (prn memory*.2)
(when (~is memory*.2 3)
  (prn "F - 'find-next' handles suffix match"))

(reset)
(new-trace "string-find-next-missing")
(add-code
  '((function main [
      (1:string-address <- new "abc")
      (2:integer <- find-next 1:string-address ((#\/ literal)) 0:literal)
     ])))
(run 'main)
;? (prn memory*.2)
(when (~is memory*.2 3)
  (prn "F - 'find-next' handles no match"))

(reset)
(new-trace "string-find-next-invalid-index")
(add-code
  '((function main [
      (1:string-address <- new "abc")
      (2:integer <- find-next 1:string-address ((#\/ literal)) 4:literal)
     ])))
;? (= dump-trace* (obj whitelist '("run")))
(run 'main)
(each routine completed-routines*
  (aif rep.routine!error (prn "error - " it)))
;? (prn memory*.2)
(when (~is memory*.2 4)
  (prn "F - 'find-next' skips invalid index (past end of string)"))

(reset)
(new-trace "string-find-next-first")
(add-code
  '((function main [
      (1:string-address <- new "ab/c/")
      (2:integer <- find-next 1:string-address ((#\/ literal)) 0:literal)
     ])))
(run 'main)
(when (~is memory*.2 2)
  (prn "F - 'find-next' finds first of multiple options"))

(reset)
(new-trace "string-find-next-second")
(add-code
  '((function main [
      (1:string-address <- new "ab/c/")
      (2:integer <- find-next 1:string-address ((#\/ literal)) 3:literal)
     ])))
(run 'main)
(when (~is memory*.2 4)
  (prn "F - 'find-next' finds second of multiple options"))

(reset)
(new-trace "match-at")
(add-code
  '((function main [
      (1:string-address <- new "abc")
      (2:string-address <- new "ab")
      (3:boolean <- match-at 1:string-address 2:string-address 0:literal)
     ])))
(run 'main)
(when (~is memory*.3 t)
  (prn "F - 'match-at' matches substring at given index"))

(reset)
(new-trace "match-at-reflexive")
(add-code
  '((function main [
      (1:string-address <- new "abc")
      (3:boolean <- match-at 1:string-address 1:string-address 0:literal)
     ])))
(run 'main)
(when (~is memory*.3 t)
  (prn "F - 'match-at' always matches a string at itself at index 0"))

(reset)
(new-trace "match-at-outside-bounds")
(add-code
  '((function main [
      (1:string-address <- new "abc")
      (2:string-address <- new "a")
      (3:boolean <- match-at 1:string-address 2:string-address 4:literal)
     ])))
(run 'main)
(when (~is memory*.3 nil)
  (prn "F - 'match-at' always fails to match outside the bounds of the text"))

(reset)
(new-trace "match-at-empty-pattern")
(add-code
  '((function main [
      (1:string-address <- new "abc")
      (2:string-address <- new "")
      (3:boolean <- match-at 1:string-address 2:string-address 0:literal)
     ])))
(run 'main)
(when (~is memory*.3 t)
  (prn "F - 'match-at' always matches empty pattern"))

(reset)
(new-trace "match-at-empty-pattern-outside-bounds")
(add-code
  '((function main [
      (1:string-address <- new "abc")
      (2:string-address <- new "")
      (3:boolean <- match-at 1:string-address 2:string-address 4:literal)
     ])))
(run 'main)
(when (~is memory*.3 nil)
  (prn "F - 'match-at' matches empty pattern -- unless index is out of bounds"))

(reset)
(new-trace "match-at-empty-text")
(add-code
  '((function main [
      (1:string-address <- new "")
      (2:string-address <- new "abc")
      (3:boolean <- match-at 1:string-address 2:string-address 0:literal)
     ])))
(run 'main)
(when (~is memory*.3 nil)
  (prn "F - 'match-at' never matches empty text"))

(reset)
(new-trace "match-at-empty-against-empty")
(add-code
  '((function main [
      (1:string-address <- new "")
      (3:boolean <- match-at 1:string-address 1:string-address 0:literal)
     ])))
(run 'main)
(when (~is memory*.3 t)
  (prn "F - 'match-at' never matches empty text -- unless pattern is also empty"))

(reset)
(new-trace "match-at-inside-bounds")
(add-code
  '((function main [
      (1:string-address <- new "abc")
      (2:string-address <- new "bc")
      (3:boolean <- match-at 1:string-address 2:string-address 1:literal)
     ])))
(run 'main)
(when (~is memory*.3 t)
  (prn "F - 'match-at' matches inner substring"))

(reset)
(new-trace "match-at-inside-bounds-2")
(add-code
  '((function main [
      (1:string-address <- new "abc")
      (2:string-address <- new "bc")
      (3:boolean <- match-at 1:string-address 2:string-address 0:literal)
     ])))
(run 'main)
(when (~is memory*.3 nil)
  (prn "F - 'match-at' matches inner substring - 2"))

(reset)
(new-trace "find-substring")
(add-code
  '((function main [
      (1:string-address <- new "abc")
      (2:string-address <- new "bc")
      (3:integer <- find-substring 1:string-address 2:string-address 0:literal)
     ])))
(run 'main)
;? (prn memory*.3) ;? 1
(when (~is memory*.3 1)
  (prn "F - 'find-substring' returns index of match"))

(reset)
(new-trace "find-substring-2")
(add-code
  '((function main [
      (1:string-address <- new "abcd")
      (2:string-address <- new "bc")
      (3:integer <- find-substring 1:string-address 2:string-address 1:literal)
     ])))
(run 'main)
(when (~is memory*.3 1)
  (prn "F - 'find-substring' returns provided index if it matches"))

(reset)
(new-trace "find-substring-no-match")
(add-code
  '((function main [
      (1:string-address <- new "abc")
      (2:string-address <- new "bd")
      (3:integer <- find-substring 1:string-address 2:string-address 0:literal)
     ])))
(run 'main)
(when (~is memory*.3 3)
  (prn "F - 'find-substring' returns out-of-bounds index on no-match"))

(reset)
(new-trace "find-substring-suffix-match")
(add-code
  '((function main [
      (1:string-address <- new "abcd")
      (2:string-address <- new "cd")
      (3:integer <- find-substring 1:string-address 2:string-address 0:literal)
     ])))
(run 'main)
(when (~is memory*.3 2)
  (prn "F - 'find-substring' returns provided index if it matches"))

(reset)
(new-trace "find-substring-suffix-match-2")
(add-code
  '((function main [
      (1:string-address <- new "abcd")
      (2:string-address <- new "cde")
      (3:integer <- find-substring 1:string-address 2:string-address 0:literal)
     ])))
(run 'main)
(when (~is memory*.3 4)
  (prn "F - 'find-substring' returns provided index if it matches"))

;? (quit) ;? 1

(reset)
(new-trace "string-split")
(add-code
  '((function main [
      (1:string-address <- new "a/b")
      (2:string-address-array-address <- split 1:string-address ((#\/ literal)))
     ])))
;? (set dump-trace*)
(run 'main)
(each routine completed-routines*
  (aif rep.routine!error (prn "error - " it)))
(let base memory*.2
;?   (prn base " " memory*.base)
  (when (or (~is memory*.base 2)
;?             (do1 nil prn.111)
            (~memory-contains-array (memory* (+ base 1)) "a")
;?             (do1 nil prn.111)
            (~memory-contains-array (memory* (+ base 2)) "b"))
    (prn "F - 'split' cuts string at delimiter")))

(reset)
(new-trace "string-split2")
(add-code
  '((function main [
      (1:string-address <- new "a/b/c")
      (2:string-address-array-address <- split 1:string-address ((#\/ literal)))
     ])))
;? (set dump-trace*)
(run 'main)
(each routine completed-routines*
  (aif rep.routine!error (prn "error - " it)))
(let base memory*.2
;?   (prn base " " memory*.base)
  (when (or (~is memory*.base 3)
;?             (do1 nil prn.111)
            (~memory-contains-array (memory* (+ base 1)) "a")
;?             (do1 nil prn.111)
            (~memory-contains-array (memory* (+ base 2)) "b")
;?             (do1 nil prn.111)
            (~memory-contains-array (memory* (+ base 3)) "c"))
    (prn "F - 'split' cuts string at two delimiters")))

(reset)
(new-trace "string-split-missing")
(add-code
  '((function main [
      (1:string-address <- new "abc")
      (2:string-address-array-address <- split 1:string-address ((#\/ literal)))
     ])))
(run 'main)
(each routine completed-routines*
  (aif rep.routine!error (prn "error - " it)))
(let base memory*.2
  (when (or (~is memory*.base 1)
            (~memory-contains-array (memory* (+ base 1)) "abc"))
    (prn "F - 'split' handles missing delimiter")))

(reset)
(new-trace "string-split-empty")
(add-code
  '((function main [
      (1:string-address <- new "")
      (2:string-address-array-address <- split 1:string-address ((#\/ literal)))
     ])))
;? (= dump-trace* (obj whitelist '("run")))
(run 'main)
(each routine completed-routines*
  (aif rep.routine!error (prn "error - " it)))
(let base memory*.2
;?   (prn base " " memory*.base)
  (when (~is memory*.base 0)
    (prn "F - 'split' handles empty string")))

(reset)
(new-trace "string-split-empty-piece")
(add-code
  '((function main [
      (1:string-address <- new "a/b//c")
      (2:string-address-array-address <- split 1:string-address ((#\/ literal)))
     ])))
(run 'main)
(each routine completed-routines*
  (aif rep.routine!error (prn "error - " it)))
(let base memory*.2
  (when (or (~is memory*.base 4)
            (~memory-contains-array (memory* (+ base 1)) "a")
            (~memory-contains-array (memory* (+ base 2)) "b")
            (~memory-contains-array (memory* (+ base 3)) "")
            (~memory-contains-array (memory* (+ base 4)) "c"))
    (prn "F - 'split' cuts string at two delimiters")))
;? (quit) ;? 1

(reset)
(new-trace "string-split-first")
(add-code
  '((function main [
      (1:string-address <- new "a/b")
      (2:string-address 3:string-address <- split-first 1:string-address ((#\/ literal)))
     ])))
(run 'main)
(each routine completed-routines*
  (aif rep.routine!error (prn "error - " it)))
(when (or (~memory-contains-array memory*.2 "a")
          (~memory-contains-array memory*.3 "b"))
  (prn "F - 'split-first' cuts string at first occurrence of delimiter"))

(reset)
(new-trace "string-split-first-at-substring")
(add-code
  '((function main [
      (1:string-address <- new "a//b")
      (2:string-address <- new "//")
      (3:string-address 4:string-address <- split-first-at-substring 1:string-address 2:string-address)
     ])))
(run 'main)
(each routine completed-routines*
  (aif rep.routine!error (prn "error - " it)))
;? (prn int-canon.memory*) ;? 1
(when (or (~memory-contains-array memory*.3 "a")
          (~memory-contains-array memory*.4 "b"))
  (prn "F - 'split-first-at-substring' is like split-first but with a string delimiter"))

(reset)
(new-trace "string-copy")
(add-code
  '((function main [
      (1:string-address <- new "abc")
      (2:string-address <- string-copy 1:string-address 1:literal 3:literal)
     ])))
(run 'main)
(each routine completed-routines*
  (aif rep.routine!error (prn "error - " it)))
(when (~memory-contains-array memory*.2 "bc")
  (prn "F - 'string-copy' returns a copy of a substring"))

(reset)
(new-trace "string-copy-out-of-bounds")
(add-code
  '((function main [
      (1:string-address <- new "abc")
      (2:string-address <- string-copy 1:string-address 2:literal 4:literal)
     ])))
(run 'main)
(each routine completed-routines*
  (aif rep.routine!error (prn "error - " it)))
(when (~memory-contains-array memory*.2 "c")
  (prn "F - 'string-copy' stops at bounds"))

(reset)
(new-trace "string-copy-out-of-bounds-2")
(add-code
  '((function main [
      (1:string-address <- new "abc")
      (2:string-address <- string-copy 1:string-address 3:literal 3:literal)
     ])))
(run 'main)
(each routine completed-routines*
  (aif rep.routine!error (prn "error - " it)))
(when (~memory-contains-array memory*.2 "")
  (prn "F - 'string-copy' returns empty string when range is out of bounds"))

(reset)
(new-trace "min")
(add-code
  '((function main [
      (1:integer <- min 3:literal 4:literal)
     ])))
(run 'main)
(each routine completed-routines*
  (aif rep.routine!error (prn "error - " it)))
;? (prn int-canon.memory*) ;? 1
(when (~is memory*.1 3)
  (prn "F - 'min' returns smaller of two numbers"))

;? (quit) ;? 2

(reset)
(new-trace "integer-to-decimal-string")
(add-code
  '((function main [
      (1:string-address/raw <- integer-to-decimal-string 34:literal)
    ])))
;? (set dump-trace*)
;? (= dump-trace* (obj whitelist '("run")))
(run 'main)
(let base memory*.1
  (when (~memory-contains-array base "34")
    (prn "F - converting integer to decimal string")))

(reset)
(new-trace "integer-to-decimal-string-zero")
(add-code
  '((function main [
      (1:string-address/raw <- integer-to-decimal-string 0:literal)
    ])))
(run 'main)
(let base memory*.1
  (when (~memory-contains-array base "0")
    (prn "F - converting zero to decimal string")))

(reset)
(new-trace "integer-to-decimal-string-negative")
(add-code
  '((function main [
      (1:string-address/raw <- integer-to-decimal-string -237:literal)
    ])))
(run 'main)
(let base memory*.1
  (when (~memory-contains-array base "-237")
    (prn "F - converting negative integer to decimal string")))

; fake screen for tests; prints go to a string
(reset)
(new-trace "fake-screen-empty")
(add-code
  '((function main [
      (default-space:space-address <- new space:literal 30:literal/capacity)
      (screen:terminal-address <- init-fake-terminal 20:literal 10:literal)
      (5:string-address/raw <- get screen:terminal-address/deref data:offset)
     ])))
(run 'main)
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
(when (~memory-contains-array memory*.5
          (+ "                    "
             "                    "
             "                    "
             "                    "
             "                    "
             "                    "
             "                    "
             "                    "
             "                    "
             "                    "))
  (prn "F - fake screen starts out with all spaces"))

; fake keyboard for tests; must initialize keys in advance
(reset)
(new-trace "fake-keyboard")
(add-code
  '((function main [
      (default-space:space-address <- new space:literal 30:literal)
      (s:string-address <- new "foo")
      (x:keyboard-address <- init-keyboard s:string-address)
      (1:character-address/raw <- read-key x:keyboard-address)
     ])))
(run 'main)
(when (~is memory*.1 #\f)
  (prn "F - 'read-key' reads character from provided 'fake keyboard' string"))

; fake keyboard for tests; must initialize keys in advance
(reset)
(new-trace "fake-keyboard2")
(add-code
  '((function main [
      (default-space:space-address <- new space:literal 30:literal)
      (s:string-address <- new "foo")
      (x:keyboard-address <- init-keyboard s:string-address)
      (1:character-address/raw <- read-key x:keyboard-address)
      (1:character-address/raw <- read-key x:keyboard-address)
     ])))
(run 'main)
(when (~is memory*.1 #\o)
  (prn "F - 'read-key' advances cursor in provided string"))

; to receive input line by line, run send-keys-buffered-to-stdin
(reset)
(new-trace "buffer-stdin-until-newline")
(add-code
  '((function main [
      (default-space:space-address <- new space:literal 30:literal)
      (s:string-address <- new "foo")
      (k:keyboard-address <- init-keyboard s:string-address)
      (stdin:channel-address <- init-channel 1:literal)
      (fork send-keys-to-stdin:fn nil:literal/globals nil:literal/limit k:keyboard-address stdin:channel-address)
      (buffered-stdin:channel-address <- init-channel 1:literal)
      (r:integer/routine <- fork buffer-lines:fn nil:literal/globals nil:literal/limit stdin:channel-address buffered-stdin:channel-address)
      (screen:terminal-address <- init-fake-terminal 20:literal 10:literal)
      (5:string-address/raw <- get screen:terminal-address/deref data:offset)
      (fork-helper send-prints-to-stdout:fn nil:literal/globals nil:literal/limit screen:terminal-address buffered-stdin:channel-address)
      (sleep until-routine-done:literal r:integer/routine)
    ])))
;? (set dump-trace*) ;? 3
;? (= dump-trace* (obj whitelist '("schedule" "run"))) ;? 0
(run 'main)
;? (prn int-canon.memory*) ;? 0
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
(when (~memory-contains-array memory*.5
          (+ "                    "
             "                    "
             "                    "
             "                    "
             "                    "
             "                    "
             "                    "
             "                    "
             "                    "
             "                    "))
  (prn "F - 'buffer-lines' prints nothing until newline is encountered"))
;? (quit) ;? 3

(reset)
(new-trace "print-buffered-contents-on-newline")
(add-code
  '((function main [
      (default-space:space-address <- new space:literal 30:literal)
      (s:string-address <- new "foo\nline2")
      (k:keyboard-address <- init-keyboard s:string-address)
      (stdin:channel-address <- init-channel 1:literal)
      (fork send-keys-to-stdin:fn nil:literal/globals nil:literal/limit k:keyboard-address stdin:channel-address)
      (buffered-stdin:channel-address <- init-channel 1:literal)
      (r:integer/routine <- fork buffer-lines:fn nil:literal/globals nil:literal/limit stdin:channel-address buffered-stdin:channel-address)
      (screen:terminal-address <- init-fake-terminal 20:literal 10:literal)
      (5:string-address/raw <- get screen:terminal-address/deref data:offset)
      (fork-helper send-prints-to-stdout:fn nil:literal/globals nil:literal/limit screen:terminal-address buffered-stdin:channel-address)
      (sleep until-routine-done:literal r:integer/routine)
    ])))
;? (= dump-trace* (obj whitelist '("schedule" "run"))) ;? 1
(run 'main)
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
(when (~memory-contains-array memory*.5
          (+ "foo\n                "
             "                    "
             "                    "
             "                    "
             "                    "
             "                    "
             "                    "
             "                    "
             "                    "
             "                    "))
  (prn "F - 'buffer-lines' prints lines to screen"))

(reset)
(new-trace "print-buffered-contents-right-at-newline")
(add-code
  '((function main [
      (default-space:space-address <- new space:literal 30:literal)
      (s:string-address <- new "foo\n")
      (k:keyboard-address <- init-keyboard s:string-address)
      (stdin:channel-address <- init-channel 1:literal)
      (fork send-keys-to-stdin:fn nil:literal/globals nil:literal/limit k:keyboard-address stdin:channel-address)
      (buffered-stdin:channel-address <- init-channel 1:literal)
      (r:integer/routine <- fork buffer-lines:fn nil:literal/globals nil:literal/limit stdin:channel-address buffered-stdin:channel-address)
      (screen:terminal-address <- init-fake-terminal 20:literal 10:literal)
      (5:string-address/raw <- get screen:terminal-address/deref data:offset)
      (fork-helper send-prints-to-stdout:fn nil:literal/globals nil:literal/limit screen:terminal-address buffered-stdin:channel-address)
      (sleep until-routine-done:literal r:integer/routine)
      ; hack: give helper some time to finish printing
      (sleep for-some-cycles:literal 500:literal)
    ])))
;? (= dump-trace* (obj whitelist '("schedule" "run"))) ;? 1
(run 'main)
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
(when (~memory-contains-array memory*.5
          (+ "foo\n                "
             "                    "
             "                    "
             "                    "
             "                    "
             "                    "
             "                    "
             "                    "
             "                    "
             "                    "))
  (prn "F - 'buffer-lines' prints lines to screen immediately on newline"))

(reset)
(new-trace "buffered-contents-skip-backspace")
(add-code
  '((function main [
      (default-space:space-address <- new space:literal 30:literal)
      (s:string-address <- new "fooa\b\nline2")
      (k:keyboard-address <- init-keyboard s:string-address)
      (stdin:channel-address <- init-channel 1:literal)
      (fork send-keys-to-stdin:fn nil:literal/globals nil:literal/limit k:keyboard-address stdin:channel-address)
      (buffered-stdin:channel-address <- init-channel 1:literal)
      (r:integer/routine <- fork buffer-lines:fn nil:literal/globals nil:literal/limit stdin:channel-address buffered-stdin:channel-address)
      (screen:terminal-address <- init-fake-terminal 20:literal 10:literal)
      (5:string-address/raw <- get screen:terminal-address/deref data:offset)
      (fork-helper send-prints-to-stdout:fn nil:literal/globals nil:literal/limit screen:terminal-address buffered-stdin:channel-address)
      (sleep until-routine-done:literal r:integer/routine)
    ])))
;? (= dump-trace* (obj whitelist '("schedule" "run"))) ;? 1
(run 'main)
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
(when (~memory-contains-array memory*.5
          (+ "foo\n                "
             "                    "
             "                    "
             "                    "
             "                    "
             "                    "
             "                    "
             "                    "
             "                    "
             "                    "))
  (prn "F - 'buffer-lines' handles backspace"))

(reset)
(new-trace "buffered-contents-ignore-excess-backspace")
(add-code
  '((function main [
      (default-space:space-address <- new space:literal 30:literal)
      (s:string-address <- new "a\b\bfoo\n")
      (k:keyboard-address <- init-keyboard s:string-address)
      (stdin:channel-address <- init-channel 1:literal)
      (fork send-keys-to-stdin:fn nil:literal/globals nil:literal/limit k:keyboard-address stdin:channel-address)
      (buffered-stdin:channel-address <- init-channel 1:literal)
      (r:integer/routine <- fork buffer-lines:fn nil:literal/globals nil:literal/limit stdin:channel-address buffered-stdin:channel-address)
      (screen:terminal-address <- init-fake-terminal 20:literal 10:literal)
      (5:string-address/raw <- get screen:terminal-address/deref data:offset)
      (fork-helper send-prints-to-stdout:fn nil:literal/globals nil:literal/limit screen:terminal-address buffered-stdin:channel-address)
      (sleep until-routine-done:literal r:integer/routine)
      ; hack: give helper some time to finish printing
      (sleep for-some-cycles:literal 500:literal)
    ])))
;? (= dump-trace* (obj whitelist '("schedule" "run"))) ;? 1
(run 'main)
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
;? (prn memory*.5) ;? 1
(when (~memory-contains-array memory*.5
          (+ "foo\n                "
             "                    "
             "                    "
             "                    "
             "                    "
             "                    "
             "                    "
             "                    "
             "                    "
             "                    "))
  (prn "F - 'buffer-lines' ignores backspace when there's nothing to backspace over"))

)  ; section 100

(reset)
(new-trace "parse-and-record")
(add-code
  '((and-record foo [
      x:string
      y:integer
      z:boolean
     ])))
(when (~iso type*!foo (obj size 3  and-record t  elems '((string) (integer) (boolean))  fields '(x y z)))
  (prn "F - 'add-code' can add new and-records"))

;; unit tests for various helpers

; tokenize-args
(prn "== tokenize-args")
(assert:iso '((a b) (c d))
            (tokenize-arg 'a:b/c:d))
; numbers are not symbols
(assert:iso '((a b) (1 d))
            (tokenize-arg 'a:b/1:d))
; special symbols are skipped
(assert:iso '<-
            (tokenize-arg '<-))
(assert:iso '_
            (tokenize-arg '_))

; idempotent
(assert:iso (tokenize-arg:tokenize-arg 'a:b/c:d)
            (tokenize-arg              'a:b/c:d))

; support labels
(assert:iso '((((default-space space-address)) <- ((new)) ((space literal)) ((30 literal)))
              foo)
            (tokenize-args
              '((default-space:space-address <- new space:literal 30:literal)
                foo)))

; support braces
(assert:iso '((((default-space space-address)) <- ((new)) ((space literal)) ((30 literal)))
              foo
              { begin
                bar
                (((a b)) <- ((op)) ((c d)) ((e f)))
              })
            (tokenize-args
              '((default-space:space-address <- new space:literal 30:literal)
                foo
                { begin
                  bar
                  (a:b <- op c:d e:f)
                })))

; space
(prn "== space")
(reset)
(when (~iso 0 (space '((4 integer))))
  (prn "F - 'space' is 0 by default"))
(when (~iso 1 (space '((4 integer) (space 1))))
  (prn "F - 'space' picks up space when available"))
(when (~iso 'global (space '((4 integer) (space global))))
  (prn "F - 'space' understands routine-global space"))

; absolutize
(prn "== absolutize")
(reset)
(when (~iso '((4 integer)) (absolutize '((4 integer))))
  (prn "F - 'absolutize' works without routine"))
(= routine* make-routine!foo)
(when (~iso '((4 integer)) (absolutize '((4 integer))))
  (prn "F - 'absolutize' works without default-space"))
(= rep.routine*!call-stack.0!default-space 10)
(= memory*.10 5)  ; bounds check for default-space
(when (~iso '((15 integer) (raw))
            (absolutize '((4 integer))))
  (prn "F - 'absolutize' works with default-space"))
(absolutize '((5 integer)))
(when (~posmatch "no room" rep.routine*!error)
  (prn "F - 'absolutize' checks against default-space bounds"))
(when (~iso '((_ integer)) (absolutize '((_ integer))))
  (prn "F - 'absolutize' passes dummy args right through"))
(when (~iso '((default-space integer)) (absolutize '((default-space integer))))
  (prn "F - 'absolutize' passes 'default-space' right through"))

(= memory*.20 5)  ; pretend array
(= rep.routine*!globals 20)  ; provide it to routine global
(when (~iso '((22 integer) (raw))
            (absolutize '((1 integer) (space global))))
  (prn "F - 'absolutize' handles variables in the global space"))

; deref
(prn "== deref")
(reset)
(= memory*.3 4)
(when (~iso '((4 integer))
            (deref '((3 integer-address)
                     (deref))))
  (prn "F - 'deref' handles simple addresses"))
(when (~iso '((4 integer) (deref))
            (deref '((3 integer-address)
                     (deref)
                     (deref))))
  (prn "F - 'deref' deletes just one deref"))
(= memory*.4 5)
(when (~iso '((5 integer))
            (deref:deref '((3 integer-address-address)
                           (deref)
                           (deref))))
  (prn "F - 'deref' can be chained"))
(when (~iso '((5 integer) (foo))
            (deref:deref '((3 integer-address-address)
                           (deref)
                           (foo)
                           (deref))))
  (prn "F - 'deref' skips junk"))

; addr
(prn "== addr")
(reset)
(= routine* nil)
;? (prn 111)
(when (~is 4 (addr '((4 integer))))
  (prn "F - directly addressed operands are their own address"))
;? (quit)
(when (~is 4 (addr '((4 integer-address))))
  (prn "F - directly addressed operands are their own address - 2"))
(when (~is 4 (addr '((4 literal))))
  (prn "F - 'addr' doesn't understand literals"))
;? (prn 201)
(= memory*.4 23)
;? (prn 202)
(when (~is 23 (addr '((4 integer-address) (deref))))
  (prn "F - 'addr' works with indirectly-addressed 'deref'"))
;? (quit)
(= memory*.3 4)
(when (~is 23 (addr '((3 integer-address-address) (deref) (deref))))
  (prn "F - 'addr' works with multiple 'deref'"))

(= routine* make-routine!foo)
(when (~is 4 (addr '((4 integer))))
  (prn "F - directly addressed operands are their own address inside routines"))
(when (~is 4 (addr '((4 integer-address))))
  (prn "F - directly addressed operands are their own address inside routines - 2"))
(when (~is 4 (addr '((4 literal))))
  (prn "F - 'addr' doesn't understand literals inside routines"))
(= memory*.4 23)
(when (~is 23 (addr '((4 integer-address) (deref))))
  (prn "F - 'addr' works with indirectly-addressed 'deref' inside routines"))

;? (prn 301)
(= rep.routine*!call-stack.0!default-space 10)
;? (prn 302)
(= memory*.10 5)  ; bounds check for default-space
;? (prn 303)
(when (~is 15 (addr '((4 integer))))
  (prn "F - directly addressed operands in routines add default-space"))
;? (quit)
(when (~is 15 (addr '((4 integer-address))))
  (prn "F - directly addressed operands in routines add default-space - 2"))
(when (~is 15 (addr '((4 literal))))
  (prn "F - 'addr' doesn't understand literals"))
(= memory*.15 23)
(when (~is 23 (addr '((4 integer-address) (deref))))
  (prn "F - 'addr' adds default-space before 'deref', not after"))
;? (quit)

; array-len
(prn "== array-len")
(reset)
(= memory*.35 4)
(when (~is 4 (array-len '((35 integer-boolean-pair-array))))
  (prn "F - 'array-len'"))
(= memory*.34 35)
(when (~is 4 (array-len '((34 integer-boolean-pair-array-address) (deref))))
  (prn "F - 'array-len'"))
;? (quit)

; sizeof
(prn "== sizeof")
(reset)
;? (set dump-trace*)
;? (prn 401)
(when (~is 1 (sizeof '((_ integer))))
  (prn "F - 'sizeof' works on primitives"))
(when (~is 1 (sizeof '((_ integer-address))))
  (prn "F - 'sizeof' works on addresses"))
(when (~is 2 (sizeof '((_ integer-boolean-pair))))
  (prn "F - 'sizeof' works on and-records"))
(when (~is 3 (sizeof '((_ integer-point-pair))))
  (prn "F - 'sizeof' works on and-records with and-record fields"))

;? (prn 410)
(when (~is 1 (sizeof '((34 integer))))
  (prn "F - 'sizeof' works on primitive operands"))
(when (~is 1 (sizeof '((34 integer-address))))
  (prn "F - 'sizeof' works on address operands"))
(when (~is 2 (sizeof '((34 integer-boolean-pair))))
  (prn "F - 'sizeof' works on and-record operands"))
(when (~is 3 (sizeof '((34 integer-point-pair))))
  (prn "F - 'sizeof' works on and-record operands with and-record fields"))
(when (~is 2 (sizeof '((34 integer-boolean-pair-address) (deref))))
  (prn "F - 'sizeof' works on pointers to and-records"))
(= memory*.35 4)  ; size of array
(= memory*.34 35)
;? (= dump-trace* (obj whitelist '("sizeof" "array-len")))
(when (~is 9 (sizeof '((34 integer-boolean-pair-array-address) (deref))))
  (prn "F - 'sizeof' works on pointers to arrays"))
;? (quit)

;? (prn 420)
(= memory*.4 23)
(when (~is 24 (sizeof '((4 integer-array))))
  (prn "F - 'sizeof' reads array lengths from memory"))
(= memory*.3 4)
(when (~is 24 (sizeof '((3 integer-array-address) (deref))))
  (prn "F - 'sizeof' handles pointers to arrays"))
(= memory*.15 34)
(= routine* make-routine!foo)
(when (~is 24 (sizeof '((4 integer-array))))
  (prn "F - 'sizeof' reads array lengths from memory inside routines"))
(= rep.routine*!call-stack.0!default-space 10)
(= memory*.10 5)  ; bounds check for default-space
(when (~is 35 (sizeof '((4 integer-array))))
  (prn "F - 'sizeof' reads array lengths from memory using default-space"))
(= memory*.35 4)  ; size of array
(= memory*.15 35)
;? (= dump-trace* (obj whitelist '("sizeof")))
(aif rep.routine*!error (prn "error - " it))
(when (~is 9 (sizeof '((4 integer-boolean-pair-array-address) (deref))))
  (prn "F - 'sizeof' works on pointers to arrays using default-space"))
;? (quit)

; m
(prn "== m")
(reset)
(when (~is 4 (m '((4 literal))))
  (prn "F - 'm' avoids reading memory for literals"))
(when (~is 4 (m '((4 offset))))
  (prn "F - 'm' avoids reading memory for offsets"))
(= memory*.4 34)
(when (~is 34 (m '((4 integer))))
  (prn "F - 'm' reads memory for simple types"))
(= memory*.3 4)
(when (~is 34 (m '((3 integer-address) (deref))))
  (prn "F - 'm' redirects addresses"))
(= memory*.2 3)
(when (~is 34 (m '((2 integer-address-address) (deref) (deref))))
  (prn "F - 'm' multiply redirects addresses"))
(when (~iso (annotate 'record '(34 nil)) (m '((4 integer-boolean-pair))))
  (prn "F - 'm' supports compound records"))
(= memory*.5 35)
(= memory*.6 36)
(when (~iso (annotate 'record '(34 35 36)) (m '((4 integer-point-pair))))
  (prn "F - 'm' supports records with compound fields"))
(when (~iso (annotate 'record '(34 35 36)) (m '((3 integer-point-pair-address) (deref))))
  (prn "F - 'm' supports indirect access to records"))
(= memory*.4 2)
(when (~iso (annotate 'record '(2 35 36)) (m '((4 integer-array))))
  (prn "F - 'm' supports access to arrays"))
(when (~iso (annotate 'record '(2 35 36)) (m '((3 integer-array-address) (deref))))
  (prn "F - 'm' supports indirect access to arrays"))

(= routine* make-routine!foo)
(= memory*.10 5)  ; fake array
(= memory*.12 34)
(= rep.routine*!globals 10)
(when (~iso 34 (m '((1 integer) (space global))))
  (prn "F - 'm' supports access to per-routine globals"))

; setm
(prn "== setm")
(reset)
(setm '((4 integer)) 34)
(when (~is 34 memory*.4)
  (prn "F - 'setm' writes primitives to memory"))
(setm '((3 integer-address)) 4)
(when (~is 4 memory*.3)
  (prn "F - 'setm' writes addresses to memory"))
(setm '((3 integer-address) (deref)) 35)
(when (~is 35 memory*.4)
  (prn "F - 'setm' redirects writes"))
(= memory*.2 3)
(setm '((2 integer-address-address) (deref) (deref)) 36)
(when (~is 36 memory*.4)
  (prn "F - 'setm' multiply redirects writes"))
;? (prn 505)
(setm '((4 integer-integer-pair)) (annotate 'record '(23 24)))
(when (~memory-contains 4 '(23 24))
  (prn "F - 'setm' writes compound records"))
(assert (is memory*.7 nil))
;? (prn 506)
(setm '((7 integer-point-pair)) (annotate 'record '(23 24 25)))
(when (~memory-contains 7 '(23 24 25))
  (prn "F - 'setm' writes records with compound fields"))
(= routine* make-routine!foo)
(setm '((4 integer-point-pair)) (annotate 'record '(33 34)))
(when (~posmatch "incorrect size" rep.routine*!error)
  (prn "F - 'setm' checks size of target"))
(wipe routine*)
(setm '((3 integer-point-pair-address) (deref)) (annotate 'record '(43 44 45)))
(when (~memory-contains 4 '(43 44 45))
  (prn "F - 'setm' supports indirect writes to records"))
(setm '((2 integer-point-pair-address-address) (deref) (deref)) (annotate 'record '(53 54 55)))
(when (~memory-contains 4 '(53 54 55))
  (prn "F - 'setm' supports multiply indirect writes to records"))
(setm '((4 integer-array)) (annotate 'record '(2 31 32)))
(when (~memory-contains 4 '(2 31 32))
  (prn "F - 'setm' writes arrays"))
(setm '((3 integer-array-address) (deref)) (annotate 'record '(2 41 42)))
(when (~memory-contains 4 '(2 41 42))
  (prn "F - 'setm' supports indirect writes to arrays"))
(= routine* make-routine!foo)
(setm '((4 integer-array)) (annotate 'record '(2 31 32 33)))
(when (~posmatch "invalid array" rep.routine*!error)
  (prn "F - 'setm' checks that array written is well-formed"))
(= routine* make-routine!foo)
;? (prn 111)
;? (= dump-trace* (obj whitelist '("sizeof" "mem")))
(setm '((4 integer-boolean-pair-array)) (annotate 'record '(2 31 nil 32 nil 33)))
(when (~posmatch "invalid array" rep.routine*!error)
  (prn "F - 'setm' checks that array of records is well-formed"))
(= routine* make-routine!foo)
;? (prn 222)
(setm '((4 integer-boolean-pair-array)) (annotate 'record '(2 31 nil 32 nil)))
(when (posmatch "invalid array" rep.routine*!error)
  (prn "F - 'setm' checks that array of records is well-formed - 2"))
(wipe routine*)

(reset)  ; end file with this to persist the trace for the final test
