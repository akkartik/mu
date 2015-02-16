(selective-load "mu.arc" section-level)
(set allow-raw-addresses*)

(reset)
(new-trace "print-trace")
(add-code:readfile "trace.mu")
(add-code
  '((function! main [
      (default-space:space-address <- new space:literal 30:literal/capacity)
      (x:string-address <- new
"schedule: main
run: main 0: (((1 integer)) <- ((copy)) ((1 literal)))
run: main 0: 1 => ((1 integer))
mem: ((1 integer)): 1 <= 1
run: main 1: (((2 integer)) <- ((copy)) ((3 literal)))
run: main 1: 3 => ((2 integer))
mem: ((2 integer)): 2 <= 3
run: main 2: (((3 integer)) <- ((add)) ((1 integer)) ((2 integer)))
mem: ((1 integer)) => 1
mem: ((2 integer)) => 3
run: main 2: 4 => ((3 integer))
mem: ((3 integer)): 3 <= 4
schedule:  done with routine")
      (s:stream-address <- init-stream x:string-address)
      (traces:instruction-trace-address-array-address <- parse-traces s:stream-address)
      (len:integer <- length traces:instruction-trace-address-array-address/deref)
      (screen:terminal-address <- init-fake-terminal 70:literal 15:literal)
      (screen-state:space-address <- screen-state traces:instruction-trace-address-array-address)
      (print-traces-collapsed screen-state:space-address screen:terminal-address)
      (1:string-address/raw <- get screen:terminal-address/deref data:offset)
    ])))
;? (set dump-trace*)
;? (= dump-trace* (obj whitelist '("run")))
(run 'main)
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
;? (prn memory*.1)
(when (~screen-contains memory*.1 70
         (+ "+ main/ 0 : (((1 integer)) <- ((copy)) ((1 literal)))                 "
            "+ main/ 0 : 1 => ((1 integer))                                        "
            "+ main/ 1 : (((2 integer)) <- ((copy)) ((3 literal)))                 "
            "+ main/ 1 : 3 => ((2 integer))                                        "
            "+ main/ 2 : (((3 integer)) <- ((add)) ((1 integer)) ((2 integer)))    "
            "+ main/ 2 : 4 => ((3 integer))                                        "))
  (prn "F - print-traces-collapsed works"))
;? (quit) ;? 1

(reset)
(new-trace "print-trace-from-middle-of-screen")
(add-code:readfile "trace.mu")
(add-code
  '((function! main [
      (default-space:space-address <- new space:literal 30:literal/capacity)
      (x:string-address <- new
"schedule: main
run: main 0: (((1 integer)) <- ((copy)) ((1 literal)))
run: main 0: 1 => ((1 integer))
mem: ((1 integer)): 1 <= 1
run: main 1: (((2 integer)) <- ((copy)) ((3 literal)))
run: main 1: 3 => ((2 integer))
mem: ((2 integer)): 2 <= 3
run: main 2: (((3 integer)) <- ((add)) ((1 integer)) ((2 integer)))
mem: ((1 integer)) => 1
mem: ((2 integer)) => 3
run: main 2: 4 => ((3 integer))
mem: ((3 integer)): 3 <= 4
schedule:  done with routine")
      (s:stream-address <- init-stream x:string-address)
      (traces:instruction-trace-address-array-address <- parse-traces s:stream-address)
      (len:integer <- length traces:instruction-trace-address-array-address/deref)
      (1:terminal-address/raw <- init-fake-terminal 70:literal 15:literal)
      ; position the cursor away from top of screen
      (cursor-down 1:terminal-address/raw)
      (cursor-down 1:terminal-address/raw)
      (screen-state:space-address <- screen-state traces:instruction-trace-address-array-address)
      (print-traces-collapsed screen-state:space-address 1:terminal-address/raw traces:instruction-trace-address-array-address)
      (2:string-address/raw <- get 1:terminal-address/raw/deref data:offset)
    ])))
(run 'main)
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
(when (~screen-contains memory*.2 70
         (+ "                                                                      "
            "                                                                      "
            "+ main/ 0 : (((1 integer)) <- ((copy)) ((1 literal)))                 "
            "+ main/ 0 : 1 => ((1 integer))                                        "
            "+ main/ 1 : (((2 integer)) <- ((copy)) ((3 literal)))                 "
            "+ main/ 1 : 3 => ((2 integer))                                        "
            "+ main/ 2 : (((3 integer)) <- ((add)) ((1 integer)) ((2 integer)))    "
            "+ main/ 2 : 4 => ((3 integer))                                        "))
  (prn "F - print-traces-collapsed works"))
(run-code main2
  (print-character 1:terminal-address/raw ((#\* literal))))
(when (~screen-contains memory*.2 70
         (+ "                                                                      "
            "                                                                      "
            "+ main/ 0 : (((1 integer)) <- ((copy)) ((1 literal)))                 "
            "+ main/ 0 : 1 => ((1 integer))                                        "
            "+ main/ 1 : (((2 integer)) <- ((copy)) ((3 literal)))                 "
            "+ main/ 1 : 3 => ((2 integer))                                        "
            "+ main/ 2 : (((3 integer)) <- ((add)) ((1 integer)) ((2 integer)))    "
            "+ main/ 2 : 4 => ((3 integer))                                        "
            "*                                                                     "))
  (prn "F - print-traces-collapsed leaves cursor at next line"))

(reset)
(new-trace "process-key-move-up-down")
(add-code:readfile "trace.mu")
(add-code
  '((function! main [
      (default-space:space-address <- new space:literal 30:literal/capacity)
      (x:string-address <- new
"schedule: main
run: main 0: (((1 integer)) <- ((copy)) ((1 literal)))
run: main 0: 1 => ((1 integer))
mem: ((1 integer)): 1 <= 1
run: main 1: (((2 integer)) <- ((copy)) ((3 literal)))
run: main 1: 3 => ((2 integer))
mem: ((2 integer)): 2 <= 3
run: main 2: (((3 integer)) <- ((add)) ((1 integer)) ((2 integer)))
mem: ((1 integer)) => 1
mem: ((2 integer)) => 3
run: main 2: 4 => ((3 integer))
mem: ((3 integer)): 3 <= 4
schedule:  done with routine")
      (s:stream-address <- init-stream x:string-address)
      (1:instruction-trace-address-array-address/raw <- parse-traces s:stream-address)
      (len:integer <- length 1:instruction-trace-address-array-address/raw/deref)
      (2:terminal-address/raw <- init-fake-terminal 70:literal 15:literal)
      ; position the cursor away from top of screen
      (cursor-down 2:terminal-address/raw)
      (cursor-down 2:terminal-address/raw)
      (3:space-address/raw <- screen-state 1:instruction-trace-address-array-address/raw)
      ; draw trace
      (print-traces-collapsed 3:space-address/raw/screen-state 2:terminal-address/raw 1:instruction-trace-address-array-address/raw)
      ; move cursor up
      ; we have no way yet to test special keys like up-arrow
      (s:string-address <- new "k")
      (k:keyboard-address <- init-keyboard s:string-address)
      (process-key 3:space-address/raw/screen-state k:keyboard-address 2:terminal-address/raw 1:instruction-trace-address-array-address/raw)
      ; draw cursor
      (replace-character 2:terminal-address/raw ((#\* literal)))
      (4:string-address/raw <- get 2:terminal-address/raw/deref data:offset)
    ])))
(run 'main)
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
(when (~screen-contains memory*.4 70
         (+ "                                                                      "
            "                                                                      "
            "+ main/ 0 : (((1 integer)) <- ((copy)) ((1 literal)))                 "
            "+ main/ 0 : 1 => ((1 integer))                                        "
            "+ main/ 1 : (((2 integer)) <- ((copy)) ((3 literal)))                 "
            "+ main/ 1 : 3 => ((2 integer))                                        "
            "+ main/ 2 : (((3 integer)) <- ((add)) ((1 integer)) ((2 integer)))    "
            "* main/ 2 : 4 => ((3 integer))                                        "))
            ;^cursor
  (prn "F - process-key can move up"))
(run-code main2
  (default-space:space-address <- new space:literal 30:literal/capacity)
  ; reset previous cursor
  (replace-character 2:terminal-address/raw ((#\+ literal)))
  ; move cursor up 3 more lines
  (s:string-address <- new "kkk")
  (k:keyboard-address <- init-keyboard s:string-address)
  (process-key 3:space-address/raw/screen-state k:keyboard-address 2:terminal-address/raw 1:instruction-trace-address-array-address/raw)
  (process-key 3:space-address/raw/screen-state k:keyboard-address 2:terminal-address/raw 1:instruction-trace-address-array-address/raw)
  (process-key 3:space-address/raw/screen-state k:keyboard-address 2:terminal-address/raw 1:instruction-trace-address-array-address/raw)
  (replace-character 2:terminal-address/raw ((#\* literal)))
  )
; cursor is now at line 3
(when (~screen-contains memory*.4 70
         (+ "                                                                      "
            "                                                                      "
            "+ main/ 0 : (((1 integer)) <- ((copy)) ((1 literal)))                 "
            "+ main/ 0 : 1 => ((1 integer))                                        "
            "* main/ 1 : (((2 integer)) <- ((copy)) ((3 literal)))                 "
            ;^cursor
            "+ main/ 1 : 3 => ((2 integer))                                        "
            "+ main/ 2 : (((3 integer)) <- ((add)) ((1 integer)) ((2 integer)))    "
            "+ main/ 2 : 4 => ((3 integer))                                        "))
  (prn "F - process-key can move up multiple times"))
; try to move cursor up thrice more
(run-code main3
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (replace-character 2:terminal-address/raw ((#\+ literal)))
  (s:string-address <- new "kkk")
  (k:keyboard-address <- init-keyboard s:string-address)
  (process-key 3:space-address/raw/screen-state k:keyboard-address 2:terminal-address/raw 1:instruction-trace-address-array-address/raw)
  (process-key 3:space-address/raw/screen-state k:keyboard-address 2:terminal-address/raw 1:instruction-trace-address-array-address/raw)
  (process-key 3:space-address/raw/screen-state k:keyboard-address 2:terminal-address/raw 1:instruction-trace-address-array-address/raw)
  (replace-character 2:terminal-address/raw ((#\* literal)))
  )
; cursor doesn't go beyond the first line printed
; stuff on screen before screen-state was initialized is inviolate
(when (~screen-contains memory*.4 70
         (+ "                                                                      "
            "                                                                      "
            "* main/ 0 : (((1 integer)) <- ((copy)) ((1 literal)))                 "
            ;^cursor
            "+ main/ 0 : 1 => ((1 integer))                                        "
            "+ main/ 1 : (((2 integer)) <- ((copy)) ((3 literal)))                 "
            "+ main/ 1 : 3 => ((2 integer))                                        "
            "+ main/ 2 : (((3 integer)) <- ((add)) ((1 integer)) ((2 integer)))    "
            "+ main/ 2 : 4 => ((3 integer))                                        "))
  (prn "F - process-key doesn't move above bounds"))
; now move cursor down 4 times
(run-code main4
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (replace-character 2:terminal-address/raw ((#\+ literal)))
  (s:string-address <- new "jjjj")
  (k:keyboard-address <- init-keyboard s:string-address)
  (process-key 3:space-address/raw/screen-state k:keyboard-address 2:terminal-address/raw 1:instruction-trace-address-array-address/raw)
  (process-key 3:space-address/raw/screen-state k:keyboard-address 2:terminal-address/raw 1:instruction-trace-address-array-address/raw)
  (process-key 3:space-address/raw/screen-state k:keyboard-address 2:terminal-address/raw 1:instruction-trace-address-array-address/raw)
  (process-key 3:space-address/raw/screen-state k:keyboard-address 2:terminal-address/raw 1:instruction-trace-address-array-address/raw)
  (replace-character 2:terminal-address/raw ((#\* literal)))
  )
(when (~screen-contains memory*.4 70
         (+ "                                                                      "
            "                                                                      "
            "+ main/ 0 : (((1 integer)) <- ((copy)) ((1 literal)))                 "
            "+ main/ 0 : 1 => ((1 integer))                                        "
            "+ main/ 1 : (((2 integer)) <- ((copy)) ((3 literal)))                 "
            "+ main/ 1 : 3 => ((2 integer))                                        "
            "* main/ 2 : (((3 integer)) <- ((add)) ((1 integer)) ((2 integer)))    "
            ;^cursor
            "+ main/ 2 : 4 => ((3 integer))                                        "))
  (prn "F - process-key can move down multiple times"))
; try to move cursor down 4 more times
(run-code main5
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (replace-character 2:terminal-address/raw ((#\+ literal)))
  (s:string-address <- new "jjjj")
  (k:keyboard-address <- init-keyboard s:string-address)
  (process-key 3:space-address/raw/screen-state k:keyboard-address 2:terminal-address/raw 1:instruction-trace-address-array-address/raw)
  (process-key 3:space-address/raw/screen-state k:keyboard-address 2:terminal-address/raw 1:instruction-trace-address-array-address/raw)
  (process-key 3:space-address/raw/screen-state k:keyboard-address 2:terminal-address/raw 1:instruction-trace-address-array-address/raw)
  (process-key 3:space-address/raw/screen-state k:keyboard-address 2:terminal-address/raw 1:instruction-trace-address-array-address/raw)
  (replace-character 2:terminal-address/raw ((#\* literal)))
  )
(when (~screen-contains memory*.4 70
         (+ "                                                                      "
            "                                                                      "
            "+ main/ 0 : (((1 integer)) <- ((copy)) ((1 literal)))                 "
            "+ main/ 0 : 1 => ((1 integer))                                        "
            "+ main/ 1 : (((2 integer)) <- ((copy)) ((3 literal)))                 "
            "+ main/ 1 : 3 => ((2 integer))                                        "
            "+ main/ 2 : (((3 integer)) <- ((add)) ((1 integer)) ((2 integer)))    "
            "+ main/ 2 : 4 => ((3 integer))                                        "
            "*                                                                     "))
  (prn "F - process-key doesn't move below bounds"))

(reset)
(new-trace "process-key-expand")
(add-code:readfile "trace.mu")
(add-code
  '((function! main [
      (default-space:space-address <- new space:literal 30:literal/capacity)
      (x:string-address <- new
"schedule: main
run: main 0: (((1 integer)) <- ((copy)) ((1 literal)))
run: main 0: 1 => ((1 integer))
mem: ((1 integer)): 1 <= 1
run: main 1: (((2 integer)) <- ((copy)) ((3 literal)))
run: main 1: 3 => ((2 integer))
mem: ((2 integer)): 2 <= 3
run: main 2: (((3 integer)) <- ((add)) ((1 integer)) ((2 integer)))
mem: ((1 integer)) => 1
mem: ((2 integer)) => 3
run: main 2: 4 => ((3 integer))
mem: ((3 integer)): 3 <= 4
schedule:  done with routine")
      (s:stream-address <- init-stream x:string-address)
      (1:instruction-trace-address-array-address/raw <- parse-traces s:stream-address)
      (len:integer <- length 1:instruction-trace-address-array-address/raw/deref)
      (2:terminal-address/raw <- init-fake-terminal 70:literal 15:literal)
      ; position the cursor away from top of screen
      (cursor-down 2:terminal-address/raw)
      (cursor-down 2:terminal-address/raw)
      (3:space-address/raw <- screen-state 1:instruction-trace-address-array-address/raw)
      ; draw trace
      (print-traces-collapsed 3:space-address/raw/screen-state 2:terminal-address/raw 1:instruction-trace-address-array-address/raw)
      (4:string-address/raw <- get 2:terminal-address/raw/deref data:offset)
    ])))
(run 'main)
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
(when (~screen-contains memory*.4 70
         (+ "                                                                      "
            "                                                                      "
            "+ main/ 0 : (((1 integer)) <- ((copy)) ((1 literal)))                 "
            "+ main/ 0 : 1 => ((1 integer))                                        "
            "+ main/ 1 : (((2 integer)) <- ((copy)) ((3 literal)))                 "
            "+ main/ 1 : 3 => ((2 integer))                                        "
            "+ main/ 2 : (((3 integer)) <- ((add)) ((1 integer)) ((2 integer)))    "
            "+ main/ 2 : 4 => ((3 integer))                                        "))
  (prn "F - process-key: before expand"))
(run-code main2
  (default-space:space-address <- new space:literal 30:literal/capacity)
  ; move cursor to final line and expand
  (s:string-address <- new "k\n")
  (k:keyboard-address <- init-keyboard s:string-address)
  (process-key 3:space-address/raw/screen-state k:keyboard-address 2:terminal-address/raw 1:instruction-trace-address-array-address/raw)
  (process-key 3:space-address/raw/screen-state k:keyboard-address 2:terminal-address/raw 1:instruction-trace-address-array-address/raw)
  )
; final line is expanded
(when (~screen-contains memory*.4 70
         (+ "                                                                      "
            "                                                                      "
            "+ main/ 0 : (((1 integer)) <- ((copy)) ((1 literal)))                 "
            "+ main/ 0 : 1 => ((1 integer))                                        "
            "+ main/ 1 : (((2 integer)) <- ((copy)) ((3 literal)))                 "
            "+ main/ 1 : 3 => ((2 integer))                                        "
            "+ main/ 2 : (((3 integer)) <- ((add)) ((1 integer)) ((2 integer)))    "
            "- main/ 2 : 4 => ((3 integer))                                        "
            "   mem : ((3 integer)): 3 <= 4                                        "
            "   schedule :  done with routine                                      "))
  (prn "F - process-key expands current trace segment on <enter>"))
; and cursor should remain on the top-level line
(run-code main3
  (replace-character 2:terminal-address/raw ((#\* literal)))
  )
(when (~screen-contains memory*.4 70
         (+ "                                                                      "
            "                                                                      "
            "+ main/ 0 : (((1 integer)) <- ((copy)) ((1 literal)))                 "
            "+ main/ 0 : 1 => ((1 integer))                                        "
            "+ main/ 1 : (((2 integer)) <- ((copy)) ((3 literal)))                 "
            "+ main/ 1 : 3 => ((2 integer))                                        "
            "+ main/ 2 : (((3 integer)) <- ((add)) ((1 integer)) ((2 integer)))    "
            "* main/ 2 : 4 => ((3 integer))                                        "
            ;^cursor
            "   mem : ((3 integer)): 3 <= 4                                        "
            "   schedule :  done with routine                                      "))
  (prn "F - process-key positions cursor on top of trace after expanding"))

(reset)
(new-trace "process-key-expand-nonlast")
(add-code:readfile "trace.mu")
(add-code
  '((function! main [
      (default-space:space-address <- new space:literal 30:literal/capacity)
      (x:string-address <- new
"schedule: main
run: main 0: (((1 integer)) <- ((copy)) ((1 literal)))
run: main 0: 1 => ((1 integer))
mem: ((1 integer)): 1 <= 1
run: main 1: (((2 integer)) <- ((copy)) ((3 literal)))
run: main 1: 3 => ((2 integer))
mem: ((2 integer)): 2 <= 3
run: main 2: (((3 integer)) <- ((add)) ((1 integer)) ((2 integer)))
mem: ((1 integer)) => 1
mem: ((2 integer)) => 3
run: main 2: 4 => ((3 integer))
mem: ((3 integer)): 3 <= 4
schedule:  done with routine")
      (s:stream-address <- init-stream x:string-address)
      (1:instruction-trace-address-array-address/raw <- parse-traces s:stream-address)
      (len:integer <- length 1:instruction-trace-address-array-address/raw/deref)
      (2:terminal-address/raw <- init-fake-terminal 70:literal 15:literal)
      ; position the cursor away from top of screen
      (cursor-down 2:terminal-address/raw)
      (cursor-down 2:terminal-address/raw)
      (3:space-address/raw <- screen-state 1:instruction-trace-address-array-address/raw)
      ; draw trace
      (print-traces-collapsed 3:space-address/raw/screen-state 2:terminal-address/raw 1:instruction-trace-address-array-address/raw)
      ; expand penultimate line
      (s:string-address <- new "kk\n")
      (k:keyboard-address <- init-keyboard s:string-address)
      (process-key 3:space-address/raw/screen-state k:keyboard-address 2:terminal-address/raw 1:instruction-trace-address-array-address/raw)
      (process-key 3:space-address/raw/screen-state k:keyboard-address 2:terminal-address/raw 1:instruction-trace-address-array-address/raw)
      (process-key 3:space-address/raw/screen-state k:keyboard-address 2:terminal-address/raw 1:instruction-trace-address-array-address/raw)
      (4:string-address/raw <- get 2:terminal-address/raw/deref data:offset)
    ])))
(run 'main)
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
(when (~screen-contains memory*.4 70
         (+ "                                                                      "
            "                                                                      "
            "+ main/ 0 : (((1 integer)) <- ((copy)) ((1 literal)))                 "
            "+ main/ 0 : 1 => ((1 integer))                                        "
            "+ main/ 1 : (((2 integer)) <- ((copy)) ((3 literal)))                 "
            "+ main/ 1 : 3 => ((2 integer))                                        "
            "- main/ 2 : (((3 integer)) <- ((add)) ((1 integer)) ((2 integer)))    "
            "   mem : ((1 integer)) => 1                                           "
            "   mem : ((2 integer)) => 3                                           "
            "+ main/ 2 : 4 => ((3 integer))                                        "))
  (prn "F - process-key: expanding a line continues to print lines after it"))

(reset)
(new-trace "process-key-skip-expanded")
(add-code:readfile "trace.mu")
(add-code
  '((function! main [
      (default-space:space-address <- new space:literal 30:literal/capacity)
      (x:string-address <- new
"schedule: main
run: main 0: (((1 integer)) <- ((copy)) ((1 literal)))
run: main 0: 1 => ((1 integer))
mem: ((1 integer)): 1 <= 1
run: main 1: (((2 integer)) <- ((copy)) ((3 literal)))
run: main 1: 3 => ((2 integer))
mem: ((2 integer)): 2 <= 3
run: main 2: (((3 integer)) <- ((add)) ((1 integer)) ((2 integer)))
mem: ((1 integer)) => 1
mem: ((2 integer)) => 3
run: main 2: 4 => ((3 integer))
mem: ((3 integer)): 3 <= 4
schedule:  done with routine")
      (s:stream-address <- init-stream x:string-address)
      (1:instruction-trace-address-array-address/raw <- parse-traces s:stream-address)
      (len:integer <- length 1:instruction-trace-address-array-address/raw/deref)
      (2:terminal-address/raw <- init-fake-terminal 70:literal 15:literal)
      ; position the cursor away from top of screen
      (cursor-down 2:terminal-address/raw)
      (cursor-down 2:terminal-address/raw)
      (3:space-address/raw <- screen-state 1:instruction-trace-address-array-address/raw)
      ; draw trace
      (print-traces-collapsed 3:space-address/raw/screen-state 2:terminal-address/raw 1:instruction-trace-address-array-address/raw)
      ; expand penultimate line, then move one line down and draw cursor
      (s:string-address <- new "kk\nj")
      (k:keyboard-address <- init-keyboard s:string-address)
      (process-key 3:space-address/raw/screen-state k:keyboard-address 2:terminal-address/raw 1:instruction-trace-address-array-address/raw)
      (process-key 3:space-address/raw/screen-state k:keyboard-address 2:terminal-address/raw 1:instruction-trace-address-array-address/raw)
      (process-key 3:space-address/raw/screen-state k:keyboard-address 2:terminal-address/raw 1:instruction-trace-address-array-address/raw)
      (process-key 3:space-address/raw/screen-state k:keyboard-address 2:terminal-address/raw 1:instruction-trace-address-array-address/raw)
      (replace-character 2:terminal-address/raw ((#\* literal)))
      (4:string-address/raw <- get 2:terminal-address/raw/deref data:offset)
    ])))
;? (set dump-trace*) ;? 1
(run 'main)
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
; cursor should be at next top-level 'run' line
(when (~screen-contains memory*.4 70
         (+ "                                                                      "
            "                                                                      "
            "+ main/ 0 : (((1 integer)) <- ((copy)) ((1 literal)))                 "
            "+ main/ 0 : 1 => ((1 integer))                                        "
            "+ main/ 1 : (((2 integer)) <- ((copy)) ((3 literal)))                 "
            "+ main/ 1 : 3 => ((2 integer))                                        "
            "- main/ 2 : (((3 integer)) <- ((add)) ((1 integer)) ((2 integer)))    "
            "   mem : ((1 integer)) => 1                                           "
            "   mem : ((2 integer)) => 3                                           "
            "* main/ 2 : 4 => ((3 integer))                                        "))
  (prn "F - process-key: navigation moves between top-level lines only"))
(run-code main2
  (default-space:space-address <- new space:literal 30:literal/capacity)
  ; reset previous cursor
  (replace-character 2:terminal-address/raw ((#\+ literal)))
  ; move cursor back up one line
  (s:string-address <- new "k")
  (k:keyboard-address <- init-keyboard s:string-address)
  (process-key 3:space-address/raw/screen-state k:keyboard-address 2:terminal-address/raw 1:instruction-trace-address-array-address/raw)
  ; show cursor
  (replace-character 2:terminal-address/raw ((#\* literal)))
  )
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
; cursor should be back at the top of the expanded line
(when (~screen-contains memory*.4 70
         (+ "                                                                      "
            "                                                                      "
            "+ main/ 0 : (((1 integer)) <- ((copy)) ((1 literal)))                 "
            "+ main/ 0 : 1 => ((1 integer))                                        "
            "+ main/ 1 : (((2 integer)) <- ((copy)) ((3 literal)))                 "
            "+ main/ 1 : 3 => ((2 integer))                                        "
            "* main/ 2 : (((3 integer)) <- ((add)) ((1 integer)) ((2 integer)))    "
            "   mem : ((1 integer)) => 1                                           "
            "   mem : ((2 integer)) => 3                                           "
            "+ main/ 2 : 4 => ((3 integer))                                        "))
  (prn "F - process-key: navigation moves between top-level lines only"))

(reset)
