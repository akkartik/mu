(selective-load "mu.arc" section-level)
(ero "running tests in trace.arc.t (takes ~10 mins)")
(test-only-settings)
(add-code:readfile "trace.mu")
(freeze function*)
(load-system-functions)

(reset2)
(new-trace "print-trace")
(run-code main
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
  (screen:terminal-address <- init-fake-terminal 70:literal 15:literal)
  (browser-state:space-address <- browser-state traces:instruction-trace-address-array-address 30:literal/screen-height)
  (print-traces-collapsed browser-state:space-address screen:terminal-address)
  (1:string-address/raw <- get screen:terminal-address/deref data:offset)
)
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

(reset2)
(new-trace "print-trace-from-middle-of-screen")
(run-code main
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
  (1:terminal-address/raw <- init-fake-terminal 70:literal 15:literal)
  ; position the cursor away from top of screen
  (cursor-down 1:terminal-address/raw)
  (cursor-down 1:terminal-address/raw)
  (browser-state:space-address <- browser-state traces:instruction-trace-address-array-address 30:literal/screen-height)
  (print-traces-collapsed browser-state:space-address 1:terminal-address/raw traces:instruction-trace-address-array-address)
  (2:string-address/raw <- get 1:terminal-address/raw/deref data:offset)
)
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
  (prn "F - print-traces-collapsed works anywhere on the screen"))
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

(reset2)
(new-trace "process-key-move-up-down")
(run-code main
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
  (2:terminal-address/raw <- init-fake-terminal 70:literal 15:literal)
  ; position the cursor away from top of screen
  (cursor-down 2:terminal-address/raw)
  (cursor-down 2:terminal-address/raw)
  (3:space-address/raw <- browser-state 1:instruction-trace-address-array-address/raw 30:literal/screen-height)
  ; draw trace
  (print-traces-collapsed 3:space-address/raw/browser-state 2:terminal-address/raw 1:instruction-trace-address-array-address/raw)
  ; move cursor up
  ; we have no way yet to test special keys like up-arrow
  (s:string-address <- new "k")
  (k:keyboard-address <- init-keyboard s:string-address)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  ; draw cursor
  (replace-character 2:terminal-address/raw ((#\* literal)))
  (4:string-address/raw <- get 2:terminal-address/raw/deref data:offset)
)
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
  (prn "F - process-key can move up the cursor"))
(run-code main2
  (default-space:space-address <- new space:literal 30:literal/capacity)
  ; reset previous cursor
  (replace-character 2:terminal-address/raw ((#\+ literal)))
  ; move cursor up 3 more lines
  (s:string-address <- new "kkk")
  (k:keyboard-address <- init-keyboard s:string-address)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
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
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  (replace-character 2:terminal-address/raw ((#\* literal)))
  )
; cursor doesn't go beyond the first line printed
; stuff on screen before browser-state was initialized is inviolate
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
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
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
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
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

(reset2)
(new-trace "process-key-expand")
(run-code main
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
  (2:terminal-address/raw <- init-fake-terminal 70:literal 15:literal)
  ; position the cursor away from top of screen
  (cursor-down 2:terminal-address/raw)
  (cursor-down 2:terminal-address/raw)
  (3:space-address/raw <- browser-state 1:instruction-trace-address-array-address/raw 30:literal/screen-height)
  ; draw trace
  (print-traces-collapsed 3:space-address/raw/browser-state 2:terminal-address/raw 1:instruction-trace-address-array-address/raw)
  (4:string-address/raw <- get 2:terminal-address/raw/deref data:offset)
)
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
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
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
  (prn "F - process-key expands the trace index at cursor on <enter>"))
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
  (prn "F - process-key positions cursor at start of trace index after expanding"))

(reset2)
(new-trace "process-key-expand-nonlast")
(run-code main
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
  (2:terminal-address/raw <- init-fake-terminal 70:literal 15:literal)
  ; position the cursor away from top of screen
  (cursor-down 2:terminal-address/raw)
  (cursor-down 2:terminal-address/raw)
  (3:space-address/raw <- browser-state 1:instruction-trace-address-array-address/raw 30:literal/screen-height)
  ; draw trace
  (print-traces-collapsed 3:space-address/raw/browser-state 2:terminal-address/raw 1:instruction-trace-address-array-address/raw)
  ; expand penultimate line
  (s:string-address <- new "kk\n")
  (k:keyboard-address <- init-keyboard s:string-address)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  (4:string-address/raw <- get 2:terminal-address/raw/deref data:offset)
)
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

(reset2)
(new-trace "process-key-expanded")
(run-code main
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (x:string-address <- new
"schedule: main
run: main 0: (((1 integer)) <- ((copy)) ((1 literal)))
run: main 0: 1 => ((1 integer))
mem: ((1 integer)): 1 <= 1
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
  (2:terminal-address/raw <- init-fake-terminal 70:literal 15:literal)
  ; position the cursor away from top of screen
  (cursor-down 2:terminal-address/raw)
  (cursor-down 2:terminal-address/raw)
  (3:space-address/raw <- browser-state 1:instruction-trace-address-array-address/raw 30:literal/screen-height)
  ; draw trace
  (print-traces-collapsed 3:space-address/raw/browser-state 2:terminal-address/raw 1:instruction-trace-address-array-address/raw)
  ; expand penultimate line, then move one line down and draw cursor
  (s:string-address <- new "kk\nj")
  (k:keyboard-address <- init-keyboard s:string-address)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  (replace-character 2:terminal-address/raw ((#\* literal)))
  (4:string-address/raw <- get 2:terminal-address/raw/deref data:offset)
)
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
  (prn "F - process-key: navigation moves between top-level trace indices only"))
(run-code main2
  (default-space:space-address <- new space:literal 30:literal/capacity)
  ; reset previous cursor
  (replace-character 2:terminal-address/raw ((#\+ literal)))
  ; move cursor back up one line
  (s:string-address <- new "k")
  (k:keyboard-address <- init-keyboard s:string-address)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
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
  (prn "F - process-key: navigation moves between top-level indices only - 2"))
(run-code main3
  (default-space:space-address <- new space:literal 30:literal/capacity)
  ; reset previous cursor
  (replace-character 2:terminal-address/raw ((#\+ literal)))
  ; press enter
  (s:string-address <- new "\n")
  (k:keyboard-address <- init-keyboard s:string-address)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  )
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
; expanded trace should now be collapsed
(when (~screen-contains memory*.4 70
         (+ "                                                                      "
            "                                                                      "
            "+ main/ 0 : (((1 integer)) <- ((copy)) ((1 literal)))                 "
            "+ main/ 0 : 1 => ((1 integer))                                        "
            "+ main/ 1 : (((2 integer)) <- ((copy)) ((3 literal)))                 "
            "+ main/ 1 : 3 => ((2 integer))                                        "
            "+ main/ 2 : (((3 integer)) <- ((add)) ((1 integer)) ((2 integer)))    "
            "+ main/ 2 : 4 => ((3 integer))                                        "
            "                                                                      "
            "                                                                      "))
  (prn "F - process-key: process-key collapses trace indices correctly after moving around"))
(run-code main4
  (default-space:space-address <- new space:literal 30:literal/capacity)
  ; move up a few lines, expand, then move down and expand again
  (s:string-address <- new "kkk\njjj\n")
  (k:keyboard-address <- init-keyboard s:string-address)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
;?   (replace-character 2:terminal-address/raw ((#\* literal))) ;? 1
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  )
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
; first expand should have no effect
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
  (prn "F - process-key: process-key collapses the previously expanded trace index when expanding elsewhere"))

;; manage screen height

(reset2)
(new-trace "trace-paginate")
(run-code main
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (x:string-address <- new
"run: main 0: a b c
mem: 0 a
run: main 1: d e f
mem: 1 a
mem: 1 b
mem: 1 c
mem: 1 d
mem: 1 e
run: main 2: g hi
run: main 3: j
mem: 3 a
run: main 4: k
run: main 5: l
run: main 6: m
run: main 7: n")
  (s:stream-address <- init-stream x:string-address)
  (traces:instruction-trace-address-array-address <- parse-traces s:stream-address)
  (2:terminal-address/raw <- init-fake-terminal 17:literal 15:literal)
  (3:space-address/raw/browser-state <- browser-state traces:instruction-trace-address-array-address 3:literal/screen-height)
  (print-traces-collapsed 3:space-address/raw/browser-state 2:terminal-address/raw)
  (4:string-address/raw <- get 2:terminal-address/raw/deref data:offset)
)
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
; screen shows a subset of collapsed trace lines
(when (~screen-contains memory*.4 17
         (+ "+ main/ 0 : a b c"
            "+ main/ 1 : d e f"
            "+ main/ 2 : g hi "))
  (prn "F - print-traces-collapsed can show just one 'page' of a larger trace"))

; expand top line
(run-code main2
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (s:string-address <- new "kkk\n")
  (k:keyboard-address <- init-keyboard s:string-address)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  )
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
; screen shows just first trace line fully expanded
(when (~screen-contains memory*.4 17
         (+ "- main/ 0 : a b c"
            "   mem : 0 a     "
            "+ main/ 1 : d e f"
            "                 "))
  (prn "F - expanding doesn't print past end of page"))
(run-code main2-2
  (replace-character 2:terminal-address/raw ((#\* literal)))
  )
; screen shows part of the second trace line expanded
(when (~screen-contains memory*.4 17
         (+ "* main/ 0 : a b c"
            "   mem : 0 a     "
            "+ main/ 1 : d e f"
            "                 "))
  (prn "F - cursor at right place after expand"))

; expand line below without first collapsing previously expanded line
(run-code main3
  (default-space:space-address <- new space:literal 30:literal/capacity)
  ; reset previous cursor
  (replace-character 2:terminal-address/raw ((#\- literal)))
  (s:string-address <- new "j\n")
  (k:keyboard-address <- init-keyboard s:string-address)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  )
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
; screen shows part of the second trace line expanded
(when (~screen-contains memory*.4 17
         (+ "+ main/ 0 : a b c"
            "- main/ 1 : d e f"
            "   mem : 1 a     "
            "                 "
            "                 "))
  (prn "F - expanding below expanded line respects screen/page height"))
(run-code main3-2
  (replace-character 2:terminal-address/raw ((#\* literal)))
  )
; screen shows part of the second trace line expanded
(when (~screen-contains memory*.4 17
         (+ "+ main/ 0 : a b c"
            "* main/ 1 : d e f"
            "   mem : 1 a     "
            "                 "
            "                 "))
  (prn "F - cursor at right place after expand below"))

; expand line *above* without first collapsing previously expanded line
(run-code main4
  (default-space:space-address <- new space:literal 30:literal/capacity)
  ; reset previous cursor
  (replace-character 2:terminal-address/raw ((#\- literal)))
  (s:string-address <- new "k\n")
  (k:keyboard-address <- init-keyboard s:string-address)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  )
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
; screen again shows first trace line expanded
(when (~screen-contains memory*.4 17
         (+ "- main/ 0 : a b c"
            "   mem : 0 a     "
            "+ main/ 1 : d e f"
            "                 "))
  (prn "F - expanding above expanded line respects screen/page height"))
;? (quit) ;? 1

; collapse everything and hit page-down
; again, we can't yet check for special keys like 'page-down so we'll use
; upper-case J and K for moving a page down or up, respectively.
(run-code main5
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (s:string-address <- new "\nJ")
  (k:keyboard-address <- init-keyboard s:string-address)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  )
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
; screen shows second page of traces
(when (~screen-contains memory*.4 17
         (+ "+ main/ 3 : j    "
            "+ main/ 4 : k    "
            "+ main/ 5 : l    "
            "                 "))
  (prn "F - 'page-down' skips to next page after this one"))
;? (quit) ;? 1

; move cursor down, then page-down
(run-code main6
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (s:string-address <- new "jJ")
  (k:keyboard-address <- init-keyboard s:string-address)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  )
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
; page-down behaves the same regardless of where the cursor was
(when (~screen-contains memory*.4 17
         (+ "+ main/ 6 : m    "
            "+ main/ 7 : n    "
            "                 "))
  (prn "F - 'page-down' skips to same place regardless of cursor position"))

; try to page-down past end of trace
(run-code main7
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (s:string-address <- new "J")
  (k:keyboard-address <- init-keyboard s:string-address)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  )
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
; no change
(when (~screen-contains memory*.4 17
         (+ "+ main/ 6 : m    "
            "+ main/ 7 : n    "
            "                 "))
  (prn "F - 'page-down' skips to same place regardless of cursor position"))

; now page-up
(run-code main8
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (s:string-address <- new "K")
  (k:keyboard-address <- init-keyboard s:string-address)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  )
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
; precisely undoes previous page-down
(when (~screen-contains memory*.4 17
         (+ "+ main/ 3 : j    "
            "+ main/ 4 : k    "
            "+ main/ 5 : l    "
            "                 "))
  (prn "F - 'page-up' on partial page behaves as if page was full"))

;; back to page 1, expand a line
(run-code main9
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (s:string-address <- new "Kkk\n")
  (k:keyboard-address <- init-keyboard s:string-address)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
;?   (print-character 2:terminal-address/raw ((#\* literal))) ;? 1
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  )
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
; now we have an expanded line
(when (~screen-contains memory*.4 17
         (+ "+ main/ 0 : a b c"
            "- main/ 1 : d e f"
            "   mem : 1 a     "
            "                 "
            "                 "))
  (prn "F - intermediate state after expanding a line"))

; next page
(run-code main10
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (s:string-address <- new "J")
  (k:keyboard-address <- init-keyboard s:string-address)
;?   ($start-tracing) ;? 1
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  )
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
; no lines skipped, page with just inner traces
(when (~screen-contains memory*.4 17
         (+ "   mem : 1 b     "
            "   mem : 1 c     "
            "   mem : 1 d     "
            "                 "
            "                 "))
  (prn "F - page down continues existing expanded line"))

; next page
(run-code main11
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (s:string-address <- new "J")
  (k:keyboard-address <- init-keyboard s:string-address)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  )
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
; page with partial inner trace and more collapsed
(when (~screen-contains memory*.4 17
         (+ "   mem : 1 e     "
            "+ main/ 2 : g hi "
            "+ main/ 3 : j    "
            "                 "
            "                 "))
  (prn "F - page down shows collapsed lines after continued expanded line at top of page"))
;? (quit) ;? 1

; page-up through an expanded line
(run-code main12
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (s:string-address <- new "K")
  (k:keyboard-address <- init-keyboard s:string-address)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  )
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
(when (~screen-contains memory*.4 17
         (+ "   mem : 1 b     "
            "   mem : 1 c     "
            "   mem : 1 d     "
            "                 "
            "                 "))
  (prn "F - page up understands expanded lines"))

;; page up scenarios
; skip ones starting at top of trace for now
; page-up scenario 2
; + run: main 0: a b c
;   mem: 0 a
; + run: main 1: d e f  <- top of page
;   mem: 1 a
;   mem: 1 b
;   mem: 1 c
;   mem: 1 d
;   mem: 1 e
; + run: main 2: g hi
; + run: main 3: j      <- bottom of page
;   mem: 3 a
; + run: main 4: k
; + run: main 5: l
; + run: main 6: m
; + run: main 7: n
(run-code main13
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:browser-state <- copy 3:space-address/raw/browser-state)
;?   ($print first-index-on-page:integer/space:1) ;? 1
;?   ($print (("\n" literal))) ;? 1
  (first-index-on-page:integer/space:1 <- copy 1:literal)
;?   ($print first-index-on-page:integer/space:1) ;? 1
;?   ($print (("\n" literal))) ;? 1
  (first-subindex-on-page:integer/space:1 <- copy -2:literal)
  (last-index-on-page:integer/space:1 <- copy 3:literal)
  (last-subindex-on-page:integer/space:1 <- copy -2:literal)
  (expanded-index:integer/space:1 <- copy -1:literal)
  (expanded-children:integer/space:1 <- copy -1:literal)
  (s:string-address <- new "K")
  (k:keyboard-address <- init-keyboard s:string-address)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  )
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
(when (~screen-contains memory*.4 17
         (+ "+ main/ 0 : a b c"
            "+ main/ 1 : d e f"
            "+ main/ 2 : g hi "))
  (prn "F - page-up 2"))

; page-up scenario 3
; + run: main 0: a b c
;   mem: 0 a
; - run: main 1: d e f  <- top of page
;   mem: 1 a
;   mem: 1 b            <- bottom of page
;   mem: 1 c
;   mem: 1 d
;   mem: 1 e
; + run: main 2: g hi
; + run: main 3: j
;   mem: 3 a
; + run: main 4: k
; + run: main 5: l
; + run: main 6: m
; + run: main 7: n
(run-code main14pre
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:browser-state <- copy 3:space-address/raw/browser-state)
  (first-index-on-page:integer/space:1 <- copy 1:literal)
  (first-subindex-on-page:integer/space:1 <- copy -1:literal)
  (last-index-on-page:integer/space:1 <- copy 1:literal)
  (last-subindex-on-page:integer/space:1 <- copy 1:literal)
  (expanded-index:integer/space:1 <- copy 1:literal)
  (expanded-children:integer/space:1 <- copy 5:literal)
  (to-top 0:space-address/browser-state 2:terminal-address/raw)
  (print-page 0:space-address/browser-state 2:terminal-address/raw)
  )
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
(when (~screen-contains memory*.4 17
         (+ "- main/ 1 : d e f"
            "   mem : 1 a     "
            "   mem : 1 b     "
            "                 "
            "                 "))
  (prn "F - page-up 3: initial print-page state"))
(run-code main14post
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:browser-state <- copy 3:space-address/raw/browser-state)
  (first-index-on-page:integer/space:1 <- copy 0:literal)
  (first-subindex-on-page:integer/space:1 <- copy -2:literal)
  (last-index-on-page:integer/space:1 <- copy 1:literal)
  (last-subindex-on-page:integer/space:1 <- copy 0:literal)
  (expanded-index:integer/space:1 <- copy 1:literal)
  (expanded-children:integer/space:1 <- copy 5:literal)
  (to-top 0:space-address/browser-state 2:terminal-address/raw)
  (print-page 0:space-address/browser-state 2:terminal-address/raw)
  )
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
(when (~screen-contains memory*.4 17
         (+ "+ main/ 0 : a b c"
            "- main/ 1 : d e f"
            "   mem : 1 a     "
            "                 "
            "                 "))
  (prn "F - page-up 3: expected post page-up state"))
;? (quit) ;? 1
(run-code main14
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:browser-state <- copy 3:space-address/raw/browser-state)
  (first-index-on-page:integer/space:1 <- copy 1:literal)
  (first-subindex-on-page:integer/space:1 <- copy -1:literal)
  (last-index-on-page:integer/space:1 <- copy 1:literal)
  (last-subindex-on-page:integer/space:1 <- copy 1:literal)
  (expanded-index:integer/space:1 <- copy 1:literal)
  (expanded-children:integer/space:1 <- copy 5:literal)
  (s:string-address <- new "K")
  (k:keyboard-address <- init-keyboard s:string-address)
;?   ($start-tracing) ;? 1
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  )
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
(when (~screen-contains memory*.4 17
         (+ "+ main/ 0 : a b c"
            "- main/ 1 : d e f"
            "   mem : 1 a     "
            "                 "
            "                 "))
  (prn "F - page-up 3"))
;? (quit) ;? 1

; page-up scenario 4
; + run: main 0: a b c
;   mem: 0 a
; - run: main 1: d e f
;   mem: 1 a
;   mem: 1 b
;   mem: 1 c            <- top of page
;   mem: 1 d
;   mem: 1 e            <- bottom of page
; + run: main 2: g hi
; + run: main 3: j
;   mem: 3 a
; + run: main 4: k
; + run: main 5: l
; + run: main 6: m
; + run: main 7: n
(run-code main15
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:browser-state <- copy 3:space-address/raw/browser-state)
  (first-index-on-page:integer/space:1 <- copy 1:literal)
  (first-subindex-on-page:integer/space:1 <- copy 2:literal)
  (last-index-on-page:integer/space:1 <- copy 1:literal)
  (last-subindex-on-page:integer/space:1 <- copy 4:literal)
  (expanded-index:integer/space:1 <- copy 1:literal)
  (expanded-children:integer/space:1 <- copy 5:literal)
  (s:string-address <- new "K")
  (k:keyboard-address <- init-keyboard s:string-address)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  )
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
(when (~screen-contains memory*.4 17
         (+ "- main/ 1 : d e f"
            "   mem : 1 a     "
            "   mem : 1 b     "
            "                 "
            "                 "))
  (prn "F - page-up 4"))

; page-up scenario 5
; + run: main 0: a b c
;   mem: 0 a
; - run: main 1: d e f
;   mem: 1 a            <- top of page
;   mem: 1 b
;   mem: 1 c            <- bottom of page
;   mem: 1 d
;   mem: 1 e
; + run: main 2: g hi
; + run: main 3: j
;   mem: 3 a
; + run: main 4: k
; + run: main 5: l
; + run: main 6: m
; + run: main 7: n
(run-code main16pre
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:browser-state <- copy 3:space-address/raw/browser-state)
  (first-index-on-page:integer/space:1 <- copy 1:literal)
  (first-subindex-on-page:integer/space:1 <- copy 0:literal)
  (last-index-on-page:integer/space:1 <- copy 1:literal)
  (last-subindex-on-page:integer/space:1 <- copy 2:literal)
  (expanded-index:integer/space:1 <- copy 1:literal)
  (expanded-children:integer/space:1 <- copy 5:literal)
;?   ($print cursor-row:integer/space:1) ;? 1
  (to-top 0:space-address/browser-state 2:terminal-address/raw)
;?   ($print cursor-row:integer/space:1) ;? 1
  (print-page 0:space-address/browser-state 2:terminal-address/raw)
  )
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
(when (~screen-contains memory*.4 17
         (+ "   mem : 1 a     "
            "   mem : 1 b     "
            "   mem : 1 c     "
            "                 "
            "                 "))
  (prn "F - page-up 5: initial print-page state"))
(run-code main16
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:browser-state <- copy 3:space-address/raw/browser-state)
  (first-index-on-page:integer/space:1 <- copy 1:literal)
  (first-subindex-on-page:integer/space:1 <- copy 0:literal)
  (last-index-on-page:integer/space:1 <- copy 1:literal)
  (last-subindex-on-page:integer/space:1 <- copy 2:literal)
  (expanded-index:integer/space:1 <- copy 1:literal)
  (expanded-children:integer/space:1 <- copy 5:literal)
  (s:string-address <- new "K")
  (k:keyboard-address <- init-keyboard s:string-address)
;?   ($dump-browser-state 3:space-address/raw/browser-state) ;? 1
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  )
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
(when (~screen-contains memory*.4 17
         (+ "+ main/ 0 : a b c"
            "- main/ 1 : d e f"
            "   mem : 1 a     "
            "                 "
            "                 "))
  (prn "F - page-up 5"))

; page-up scenario 6
; + run: main 0: a b c
;   mem: 0 a
; - run: main 1: d e f
;   mem: 1 a
;   mem: 1 b            <- top of page
;   mem: 1 c
;   mem: 1 d            <- bottom of page
;   mem: 1 e
; + run: main 2: g hi
; + run: main 3: j
;   mem: 3 a
; + run: main 4: k
; + run: main 5: l
; + run: main 6: m
; + run: main 7: n
(run-code main17
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:browser-state <- copy 3:space-address/raw/browser-state)
  (first-index-on-page:integer/space:1 <- copy 1:literal)
  (first-subindex-on-page:integer/space:1 <- copy 1:literal)
  (last-index-on-page:integer/space:1 <- copy 1:literal)
  (last-subindex-on-page:integer/space:1 <- copy 3:literal)
  (expanded-index:integer/space:1 <- copy 1:literal)
  (expanded-children:integer/space:1 <- copy 5:literal)
  (s:string-address <- new "K")
  (k:keyboard-address <- init-keyboard s:string-address)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  )
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
(when (~screen-contains memory*.4 17
         (+ "+ main/ 0 : a b c"
            "- main/ 1 : d e f"
            "   mem : 1 a     "
            "                 "
            "                 "))
  (prn "F - page-up 6"))

; page-up scenario 7
; + run: main 0: a b c
;   mem: 0 a
; + run: main 1: d e f  <- top of page
;   mem: 1 a
;   mem: 1 b
;   mem: 1 c
;   mem: 1 d
;   mem: 1 e
; + run: main 2: g hi
; - run: main 3: j      <- bottom of page
;   mem: 3 a
; + run: main 4: k
; + run: main 5: l
; + run: main 6: m
; + run: main 7: n
(run-code main18
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:browser-state <- copy 3:space-address/raw/browser-state)
  (first-index-on-page:integer/space:1 <- copy 1:literal)
  (first-subindex-on-page:integer/space:1 <- copy -2:literal)
  (last-index-on-page:integer/space:1 <- copy 3:literal)
  (last-subindex-on-page:integer/space:1 <- copy -1:literal)
  (expanded-index:integer/space:1 <- copy 3:literal)
  (expanded-children:integer/space:1 <- copy 1:literal)
  (s:string-address <- new "K")
  (k:keyboard-address <- init-keyboard s:string-address)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  )
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
(when (~screen-contains memory*.4 17
         (+ "+ main/ 0 : a b c"
            "+ main/ 1 : d e f"
            "+ main/ 2 : g hi "
            "                 "))
  (prn "F - page-up 7 - expanded index starts below bottom"))
;? (quit) ;? 1

; page-up scenario 8
; + run: main 0: a b c
;   mem: 0 a
; + run: main 1: d e f  <- top of page
;   mem: 1 a
;   mem: 1 b
;   mem: 1 c
;   mem: 1 d
;   mem: 1 e
; + run: main 2: g hi
; + run: main 3: j      <- bottom of page
;   mem: 3 a
; - run: main 4: k
; + run: main 5: l
; + run: main 6: m
; + run: main 7: n
(run-code main19
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:browser-state <- copy 3:space-address/raw/browser-state)
  (first-index-on-page:integer/space:1 <- copy 1:literal)
  (first-subindex-on-page:integer/space:1 <- copy -2:literal)
  (last-index-on-page:integer/space:1 <- copy 3:literal)
  (last-subindex-on-page:integer/space:1 <- copy -1:literal)
  (expanded-index:integer/space:1 <- copy 4:literal)
  (expanded-children:integer/space:1 <- copy 0:literal)
  (s:string-address <- new "K")
  (k:keyboard-address <- init-keyboard s:string-address)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  )
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
(when (~screen-contains memory*.4 17
         (+ "+ main/ 0 : a b c"
            "+ main/ 1 : d e f"
            "+ main/ 2 : g hi "
            "                 "))
  (prn "F - page-up 8 - expanded index starts below top - 2"))

; page-up scenario 9
; - run: main 0: a b c
;   mem: 0 a
; + run: main 1: d e f
;   mem: 1 a
;   mem: 1 b
;   mem: 1 c
;   mem: 1 d
;   mem: 1 e
; + run: main 2: g hi
; + run: main 3: j      <- top of page
;   mem: 3 a
; + run: main 4: k
; + run: main 5: l      <- bottom of page
; + run: main 6: m
; + run: main 7: n
(run-code main20
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:browser-state <- copy 3:space-address/raw/browser-state)
  (first-index-on-page:integer/space:1 <- copy 3:literal)
  (first-subindex-on-page:integer/space:1 <- copy -2:literal)
  (last-index-on-page:integer/space:1 <- copy 5:literal)
  (last-subindex-on-page:integer/space:1 <- copy -2:literal)
  (expanded-index:integer/space:1 <- copy 0:literal)
  (expanded-children:integer/space:1 <- copy 1:literal)
  (s:string-address <- new "K")
  (k:keyboard-address <- init-keyboard s:string-address)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  )
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
(when (~screen-contains memory*.4 17
         (+ "   mem : 0 a     "
            "+ main/ 1 : d e f"
            "+ main/ 2 : g hi "
            "                 "))
  (prn "F - page-up 9 - expanded index overlaps target page"))

; page-up scenario 10
; - run: main 0: a b c
;   mem: 0 a
; + run: main 1: d e f
;   mem: 1 a
;   mem: 1 b
;   mem: 1 c
;   mem: 1 d
;   mem: 1 e
; + run: main 2: g hi   <- top of page
; + run: main 3: j
;   mem: 3 a
; + run: main 4: k      <- bottom of page
; + run: main 5: l
; + run: main 6: m
; + run: main 7: n
(run-code main21pre
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:browser-state <- copy 3:space-address/raw/browser-state)
  (first-index-on-page:integer/space:1 <- copy 2:literal)
  (first-subindex-on-page:integer/space:1 <- copy -2:literal)
  (last-index-on-page:integer/space:1 <- copy 4:literal)
  (last-subindex-on-page:integer/space:1 <- copy -2:literal)
  (expanded-index:integer/space:1 <- copy 0:literal)
  (expanded-children:integer/space:1 <- copy 1:literal)
  (to-top 0:space-address/browser-state 2:terminal-address/raw)
;?   ($start-tracing) ;? 2
  (print-page 0:space-address/browser-state 2:terminal-address/raw)
  )
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
(when (~screen-contains memory*.4 17
         (+ "+ main/ 2 : g hi "
            "+ main/ 3 : j    "
            "+ main/ 4 : k    "
            "                 "
            "                 "))
  (prn "F - page-up 10: initial print-page state"))
;? (quit) ;? 1
(run-code main21
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:browser-state <- copy 3:space-address/raw/browser-state)
  (first-index-on-page:integer/space:1 <- copy 2:literal)
  (first-subindex-on-page:integer/space:1 <- copy -2:literal)
  (last-index-on-page:integer/space:1 <- copy 4:literal)
  (last-subindex-on-page:integer/space:1 <- copy -2:literal)
  (expanded-index:integer/space:1 <- copy 0:literal)
  (expanded-children:integer/space:1 <- copy 1:literal)
  (s:string-address <- new "K")
  (k:keyboard-address <- init-keyboard s:string-address)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  )
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
(when (~screen-contains memory*.4 17
         (+ "- main/ 0 : a b c"
            "   mem : 0 a     "
            "+ main/ 1 : d e f"
            "                 "
            "                 "))
  (prn "F - page-up 10 - expanded index overlaps target page - 2"))
;? (quit) ;? 2

(reset2)
(new-trace "trace-paginate2")
; page-up scenario 11
; + run: main 0: a b c
;   mem: 0 a
; + run: main 1: d e f
; - run: main 2: g hi
;   mem: 2 a
; + run: main 3: j      <- top of page
;   mem: 3 a
; + run: main 4: k
; + run: main 5: l      <- bottom of page
; + run: main 6: m
; + run: main 7: n
(run-code main22
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (x:string-address <- new
"run: main 0: a b c
mem: 0 a
run: main 1: d e f
run: main 2: g hi
mem: 2 a
run: main 3: j
mem: 3 a
run: main 4: k
run: main 5: l
run: main 6: m
run: main 7: n")
  (s:stream-address <- init-stream x:string-address)
  (traces:instruction-trace-address-array-address <- parse-traces s:stream-address)
  (2:terminal-address/raw <- init-fake-terminal 17:literal 15:literal)
  (3:space-address/raw/browser-state <- browser-state traces:instruction-trace-address-array-address 3:literal/screen-height)
  (0:space-address/names:browser-state <- copy 3:space-address/raw/browser-state)
  (4:string-address/raw <- get 2:terminal-address/raw/deref data:offset)
  (first-index-on-page:integer/space:1 <- copy 3:literal)
  (first-subindex-on-page:integer/space:1 <- copy -2:literal)
  (last-index-on-page:integer/space:1 <- copy 5:literal)
  (last-subindex-on-page:integer/space:1 <- copy -2:literal)
  (expanded-index:integer/space:1 <- copy 2:literal)
  (expanded-children:integer/space:1 <- copy 1:literal)
  (s:string-address <- new "K")
  (k:keyboard-address <- init-keyboard s:string-address)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  )
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
(when (~screen-contains memory*.4 17
         (+ "+ main/ 1 : d e f"
            "- main/ 2 : g hi "
            "   mem : 2 a     "
            "                 "
            "                 "))
  (prn "F - page-up 11 - expanded index overlaps target page - 3"))

; page-up scenario 12
; + run: main 0: a b c
;   mem: 0 a
; + run: main 1: d e f
; - run: main 2: g hi
;   mem: 2 a
; + run: main 3: j
;   mem: 3 a
; + run: main 4: k      <- top of page
; + run: main 5: l
; + run: main 6: m      <- bottom of page
; + run: main 7: n
(run-code main23
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:browser-state <- copy 3:space-address/raw/browser-state)
  (first-index-on-page:integer/space:1 <- copy 4:literal)
  (first-subindex-on-page:integer/space:1 <- copy -2:literal)
  (last-index-on-page:integer/space:1 <- copy 6:literal)
  (last-subindex-on-page:integer/space:1 <- copy -2:literal)
  (expanded-index:integer/space:1 <- copy 2:literal)
  (expanded-children:integer/space:1 <- copy 1:literal)
  (s:string-address <- new "K")
  (k:keyboard-address <- init-keyboard s:string-address)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  )
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
(when (~screen-contains memory*.4 17
         (+ "- main/ 2 : g hi "
            "   mem : 2 a     "
            "+ main/ 3 : j    "
            "                 "))
  (prn "F - page-up 12 - expanded index overlaps target page - 4"))

; page-up scenario 13
; + run: main 0: a b c
;   mem: 0 a
; + run: main 1: d e f
; - run: main 2: g hi
;   mem: 2 a
; + run: main 3: j
;   mem: 3 a
; + run: main 4: k
; + run: main 5: l
; + run: main 6: m      <- top of page
; + run: main 7: n      <- bottom of page
(run-code main24
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:browser-state <- copy 3:space-address/raw/browser-state)
  (first-index-on-page:integer/space:1 <- copy 6:literal)
  (first-subindex-on-page:integer/space:1 <- copy -2:literal)
  (last-index-on-page:integer/space:1 <- copy 7:literal)
  (last-subindex-on-page:integer/space:1 <- copy -2:literal)
  (expanded-index:integer/space:1 <- copy 2:literal)
  (expanded-children:integer/space:1 <- copy 1:literal)
  (s:string-address <- new "K")
  (k:keyboard-address <- init-keyboard s:string-address)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  )
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
(when (~screen-contains memory*.4 17
         (+ "+ main/ 3 : j    "
            "+ main/ 4 : k    "
            "+ main/ 5 : l    "
            "                 "))
  (prn "F - page-up 13 - expanded index far above target page"))

(run-code main25
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:browser-state <- copy 3:space-address/raw/browser-state)
  (s:string-address <- new "kk\n")
  (k:keyboard-address <- init-keyboard s:string-address)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  (process-key 3:space-address/raw/browser-state k:keyboard-address 2:terminal-address/raw)
  )
(each routine completed-routines*
  (awhen rep.routine!error
    (prn "error - " it)))
(when (~screen-contains memory*.4 17
         (+ "+ main/ 3 : j    "
            "- main/ 4 : k    "
            "+ main/ 5 : l    "
            "                 "))
  (prn "F - process-key expands trace segment on any page"))

(reset2)
;? (print-times) ;? 3
