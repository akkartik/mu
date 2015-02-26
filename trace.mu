(and-record trace [
  label:string-address
  contents:string-address
])
(address trace-address (trace))
(array trace-address-array (trace-address))
(address trace-address-array-address (trace-address-array))
(address trace-address-array-address-address (trace-address-array-address))

(and-record instruction-trace [
  call-stack:string-address-array-address
  pc:string-address  ; should be integer?
  instruction:string-address
  children:trace-address-array-address
])
(address instruction-trace-address (instruction-trace))
(array instruction-trace-address-array (instruction-trace-address))
(address instruction-trace-address-array-address (instruction-trace-address-array))

(function parse-traces [  ; stream-address -> instruction-trace-address-array-address
  (default-space:space-address <- new space:literal 30:literal)
;?   ($print (("parse-traces\n" literal))) ;? 1
  (in:stream-address <- next-input)
  (result:buffer-address <- init-buffer 30:literal)
  (curr-tail:instruction-trace-address <- copy nil:literal)
  (ch:buffer-address <- init-buffer 5:literal)  ; accumulator for traces between instructions
  (run:string-address/const <- new "run")
  ; reading each line from 'in'
  { begin
    next-line
    (done?:boolean <- end-of-stream? in:stream-address)
;?     ($print done?:boolean) ;? 1
;?     ($print (("\n" literal))) ;? 1
    (break-if done?:boolean)
    ; parse next line as a generic trace
    (line:string-address <- read-line in:stream-address)
;?     (print-string nil:literal/terminal line:string-address) ;? 1
    (f:trace-address <- parse-trace line:string-address)
    (l:string-address <- get f:trace-address/deref label:offset)
    { begin
      ; if it's an instruction trace with label 'run'
      (inst?:boolean <- string-equal l:string-address run:string-address/const)
      (break-unless inst?:boolean)
      ; add accumulated traces to curr-tail
      { begin
        (break-unless curr-tail:instruction-trace-address)
        (c:trace-address-array-address-address <- get-address curr-tail:instruction-trace-address/deref children:offset)
        (c:trace-address-array-address-address/deref <- to-array ch:buffer-address)
        ; clear 'ch'
        (ch:buffer-address <- init-buffer 5:literal)
      }
      ; append a new curr-tail to result
      (curr-tail:instruction-trace-address <- parse-instruction-trace f:trace-address)
      (result:buffer-address <- append result:buffer-address curr-tail:instruction-trace-address)
      (jump next-line:offset)  ; loop
    }
    ; otherwise accumulate trace
    (loop-unless curr-tail:instruction-trace-address)
    (ch:buffer-address <- append ch:buffer-address f:trace-address)
    (loop)
  }
  ; add accumulated traces to final curr-tail
  ; todo: test
  { begin
    (break-unless curr-tail:instruction-trace-address)
    (c:trace-address-array-address-address <- get-address curr-tail:instruction-trace-address/deref children:offset)
    (c:trace-address-array-address-address/deref <- to-array ch:buffer-address)
  }
  (s:instruction-trace-address-array-address <- to-array result:buffer-address)
  (reply s:instruction-trace-address-array-address)
])

(function parse-instruction-trace [  ; trace-address -> instruction-trace-address
  (default-space:space-address <- new space:literal 30:literal)
;?   ($print (("parse-instruction-trace\n" literal))) ;? 1
  (in:trace-address <- next-input)
  (buf:string-address <- get in:trace-address/deref contents:offset)
;?   (print-string nil:literal buf:string-address) ;? 1
;?   ($print (("\n" literal))) ;? 1
  (result:instruction-trace-address <- new instruction-trace:literal)
  (f1:string-address rest:string-address <- split-first buf:string-address ((#\space literal)))
;?   ($print (("call-stack: " literal))) ;? 1
;?   (print-string nil:literal f1:string-address) ;? 1
;?   ($print (("\n" literal))) ;? 1
  (cs:string-address-array-address-address <- get-address result:instruction-trace-address/deref call-stack:offset)
  (cs:string-address-array-address-address/deref <- split f1:string-address ((#\/ literal)))
  (p:string-address-address <- get-address result:instruction-trace-address/deref pc:offset)
  (delim:string-address <- new ": ")
  (p:string-address-address/deref rest:string-address <- split-first-at-substring rest:string-address delim:string-address)
  (inst:string-address-address <- get-address result:instruction-trace-address/deref instruction:offset)
  (inst:string-address-address/deref <- copy rest:string-address)
  (reply result:instruction-trace-address)
])

(function parse-trace [  ; string-address -> trace-address
  (default-space:space-address <- new space:literal 30:literal)
;?   ($print (("parse-trace\n" literal))) ;? 1
  (in:string-address <- next-input)
  (result:trace-address <- new trace:literal)
  (delim:string-address <- new ": ")
  (first:string-address rest:string-address <- split-first-at-substring in:string-address delim:string-address)
  (l:string-address-address <- get-address result:trace-address/deref label:offset)
  (l:string-address-address/deref <- copy first:string-address)
  (c:string-address-address <- get-address result:trace-address/deref contents:offset)
  (c:string-address-address/deref <- copy rest:string-address)
  (reply result:trace-address)
])

(function print-trace [
  (default-space:space-address <- new space:literal 30:literal)
  (screen:terminal-address <- next-input)
  (x:trace-address <- next-input)
  (l:string-address <- get x:trace-address/deref label:offset)
  (clear-line screen:terminal-address)
  (print-string screen:terminal-address l:string-address)
  (print-character screen:terminal-address ((#\space literal)))
  (print-character screen:terminal-address ((#\: literal)))
  (print-character screen:terminal-address ((#\space literal)))
  (c:string-address <- get x:trace-address/deref contents:offset)
  (print-string screen:terminal-address c:string-address)
])

(function print-instruction-trace [
  (default-space:space-address <- new space:literal 30:literal)
  (screen:terminal-address <- next-input)
  (x:instruction-trace-address <- next-input)
  (screen-state:space-address <- next-input)
  (clear-line screen:terminal-address)
  (print-character screen:terminal-address ((#\- literal)))
  (print-character screen:terminal-address ((#\space literal)))
  ; print call stack
  (c:string-address-array-address <- get x:instruction-trace-address/deref call-stack:offset)
  (i:integer <- copy 0:literal)
  (len:integer <- length c:string-address-array-address/deref)
  { begin
    (done?:boolean <- greater-or-equal i:integer len:integer)
    (break-if done?:boolean)
    (s:string-address <- index c:string-address-array-address/deref i:integer)
    (print-string screen:terminal-address s:string-address)
    (print-character screen:terminal-address ((#\/ literal)))
    (i:integer <- add i:integer 1:literal)
    (loop)
  }
  ; print pc
  (print-character screen:terminal-address ((#\space literal)))
  (p:string-address <- get x:instruction-trace-address/deref pc:offset)
  (print-string screen:terminal-address p:string-address)
  ; print instruction
  (print-character screen:terminal-address ((#\space literal)))
  (print-character screen:terminal-address ((#\: literal)))
  (print-character screen:terminal-address ((#\space literal)))
  (i:string-address <- get x:instruction-trace-address/deref instruction:offset)
  (print-string screen:terminal-address i:string-address)
  (add-line screen-state:space-address screen:terminal-address)
  ; print children
  (ch:trace-address-array-address <- get x:instruction-trace-address/deref children:offset)
  (i:integer <- copy 0:literal)
  { begin
    ; todo: test
    (break-if ch:trace-address-array-address)
    (reply)
  }
  (len:integer <- length ch:trace-address-array-address/deref)
  { begin
    (done?:boolean <- greater-or-equal i:integer len:integer)
    (break-if done?:boolean)
    (t:trace-address <- index ch:trace-address-array-address/deref i:integer)
    (print-character screen:terminal-address ((#\space literal)))
    (print-character screen:terminal-address ((#\space literal)))
    (print-character screen:terminal-address ((#\space literal)))
    (print-trace screen:terminal-address t:trace-address)
    (add-line screen-state:space-address screen:terminal-address)
    (i:integer <- add i:integer 1:literal)
    (loop)
  }
])

(function print-instruction-trace-collapsed [
  (default-space:space-address <- new space:literal 30:literal)
  (screen:terminal <- next-input)
  (x:instruction-trace-address <- next-input)
  (screen-state:space-address <- next-input)
  (clear-line screen:terminal-address)
  (print-character screen:terminal-address ((#\+ literal)))
  (print-character screen:terminal-address ((#\space literal)))
  ; print call stack
  (c:string-address-array-address <- get x:instruction-trace-address/deref call-stack:offset)
  (i:integer <- copy 0:literal)
  (len:integer <- length c:string-address-array-address/deref)
  { begin
    (done?:boolean <- greater-or-equal i:integer len:integer)
    (break-if done?:boolean)
    (s:string-address <- index c:string-address-array-address/deref i:integer)
    (print-string screen:terminal-address s:string-address)
;?     (print-character screen:terminal-address ((#\space literal)))
    (print-character screen:terminal-address ((#\/ literal)))
;?     (print-character screen:terminal-address ((#\space literal)))
    (i:integer <- add i:integer 1:literal)
    (loop)
  }
  ; print pc
  (print-character screen:terminal-address ((#\space literal)))
  (p:string-address <- get x:instruction-trace-address/deref pc:offset)
  (print-string screen:terminal-address p:string-address)
  ; print instruction
  (print-character screen:terminal-address ((#\space literal)))
  (print-character screen:terminal-address ((#\: literal)))
  (print-character screen:terminal-address ((#\space literal)))
  (i:string-address <- get x:instruction-trace-address/deref instruction:offset)
  (print-string screen:terminal-address i:string-address)
  (add-line screen-state:space-address screen:terminal-address)
])

(function instruction-trace-num-children [
  (default-space:space-address <- new space:literal 30:literal)
  (traces:instruction-trace-address-array-address <- next-input)
  (index:integer <- next-input)
  (tr:instruction-trace-address <- index traces:instruction-trace-address-array-address/deref index:integer)
  (tr-children:trace-address-array-address <- get tr:instruction-trace-address/deref children:offset)
  (n:integer <- length tr-children:instruction-trace-address-array-address/deref)
  (reply n:integer)
])

;; data structure
(function screen-state [
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (traces:instruction-trace-address-array-address <- next-input)
  (screen-height:integer <- next-input)  ; 'hardware' limitation
  (app-height:integer <- copy 0:literal)  ; area of the screen we're responsible for; can't be larger than screen-height
  (printed-height:integer <- copy 0:literal)  ; part of screen that currently has text; can't be larger than app-height
  (cursor-row:integer <- copy 0:literal)  ; position of cursor on screen; can't be larger than printed-height + 1
  (expanded-index:integer <- copy -1:literal)
  (reply default-space:space-address)
])

(function down [
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:screen-state <- next-input)
  (screen:terminal-address <- next-input)
  ; if at expanded, skip past nested lines
  { begin
    (no-expanded?:boolean <- less-than expanded-index:integer/space:1 0:literal)
    (break-if no-expanded?:boolean)
    (at-expanded?:boolean <- equal cursor-row:integer/space:1 expanded-index:integer/space:1)
    (break-unless at-expanded?:boolean)
    (n:integer <- instruction-trace-num-children traces:instruction-trace-address-array-address/space:1 expanded-index:integer/space:1)
    (n:integer <- add n:integer 1:literal)
    (i:integer <- copy 0:literal)
    { begin
      (done?:boolean <- greater-or-equal i:integer n:integer)
      (break-if done?:boolean)
      (cursor-row:integer/space:1 <- add cursor-row:integer/space:1 1:literal)
      (cursor-down screen:terminal-address)
      (i:integer <- add i:integer 1:literal)
      (loop)
    }
    (reply)
  }
  ; if not at bottom, move cursor down
  { begin
    (at-bottom?:boolean <- greater-or-equal cursor-row:integer/space:1 printed-height:integer/space:1)
    (break-if at-bottom?:boolean)
    (cursor-row:integer/space:1 <- add cursor-row:integer/space:1 1:literal)
    (cursor-down screen:terminal-address)
  }
])

(function up [
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:screen-state <- next-input)
  (screen:terminal-address <- next-input)
  ; if at expanded, skip past nested lines
  { begin
    (no-expanded?:boolean <- less-than expanded-index:integer/space:1 0:literal)
    (break-if no-expanded?:boolean)
    (n:integer <- instruction-trace-num-children traces:instruction-trace-address-array-address/space:1 expanded-index:integer/space:1)
    (n:integer <- add n:integer 1:literal)
    (cursor-row-below-expanded:integer <- add expanded-index:integer/space:1 n:integer)
    (just-below-expanded?:boolean <- equal cursor-row:integer/space:1 cursor-row-below-expanded:integer)
    (break-unless just-below-expanded?:boolean)
    (i:integer <- copy 0:literal)
    { begin
      (done?:boolean <- greater-or-equal i:integer n:integer)
      (break-if done?:boolean)
      (cursor-row:integer/space:1 <- subtract cursor-row:integer/space:1 1:literal)
      (cursor-up screen:terminal-address)
      (i:integer <- add i:integer 1:literal)
      (loop)
    }
    (reply)
  }
  ; if not at top, move cursor up
  { begin
    (at-top?:boolean <- lesser-or-equal cursor-row:integer/space:1 0:literal)
    (break-if at-top?:boolean)
    (cursor-row:integer/space:1 <- subtract cursor-row:integer/space:1 1:literal)
    (cursor-up screen:terminal-address)
  }
])

(function to-bottom [
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:screen-state <- next-input)
  (screen:terminal-address <- next-input)
  { begin
    (at-bottom?:boolean <- greater-or-equal cursor-row:integer/space:1 printed-height:integer/space:1)
    (break-if at-bottom?:boolean)
    (down 0:space-address screen:terminal-address)
    (loop)
  }
])

(function back-to [
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:screen-state <- next-input)
  (screen:terminal-address <- next-input)
  (target-row:integer <- next-input)
  { begin
    (below-target?:boolean <- greater-than cursor-row:integer/space:1 target-row:integer)
    (break-unless below-target?:boolean)
    (up 0:space-address screen:terminal-address)
    (loop)
  }
  { begin
    (above-target?:boolean <- less-than cursor-row:integer/space:1 target-row:integer)
    (break-unless above-target?:boolean)
    (down 0:space-address screen:terminal-address)
    (loop)
  }
])

(function add-line [  ; move down, adding line if necessary
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:screen-state <- next-input)
  (screen:terminal-address <- next-input)
  { begin
    (at-bottom?:boolean <- greater-or-equal cursor-row:integer/space:1 printed-height:integer/space:1)
    (break-unless at-bottom?:boolean)
    (printed-height:integer/space:1 <- add printed-height:integer/space:1 1:literal)
    ; update app-height if necessary
    { begin
      (grow-max?:boolean <- greater-than printed-height:integer/space:1 app-height:integer/space:1)
      (break-unless grow-max?:boolean)
      (app-height:integer/space:1 <- copy printed-height:integer/space:1)
    }
  }
  (cursor-row:integer/space:1 <- add cursor-row:integer/space:1 1:literal)
  (cursor-to-next-line screen:terminal-address)
])

;; initial screen state
(function print-traces-collapsed [
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:screen-state <- next-input)
  (screen:terminal-address <- next-input)
  (print-traces-collapsed-from 0:space-address/screen-state screen:terminal-address 0:literal/from)
])

(function print-traces-collapsed-from [
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:screen-state <- next-input)
  (screen:terminal-address <- next-input)
  (i:integer <- next-input)
  (len:integer <- length traces:instruction-trace-address-array-address/space:1/deref)
  ; print remaining traces collapsed
  { begin
    (done?:boolean <- greater-or-equal i:integer len:integer)
    (break-if done?:boolean)
    (tr:instruction-trace-address <- index traces:instruction-trace-address-array-address/space:1/deref i:integer)
    (print-instruction-trace-collapsed screen:terminal-address tr:instruction-trace-address 0:space-address/screen-state)
    (i:integer <- add i:integer 1:literal)
    (loop)
  }
  ; empty any remaining lines
;?   ($print i:integer) ;? 1
;?   ($print ((#\space literal))) ;? 1
;?   ($print app-height:integer/space:1) ;? 1
  { begin
    (done?:boolean <- greater-or-equal i:integer app-height:integer/space:1)
    (break-if done?:boolean)
    (clear-line screen:terminal-address)
    (down 0:space-address/screen-state screen:terminal-address)
    (i:integer <- add i:integer 1:literal)
    (loop)
  }
])

(function cursor-row-to-trace-index [
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:screen-state <- next-input)
  (n:integer/screen <- next-input)
  ; no row expanded? no munging needed
  { begin
    (has-expanded?:boolean <- greater-or-equal expanded-index:integer/space:1 0:literal)
    (break-if has-expanded?:boolean)
    (reply n:integer/index)
  }
  ; expanded row is below cursor-row? no munging needed
  { begin
    (above-expanded?:boolean <- lesser-or-equal cursor-row:integer/space:1/screen expanded-index:integer/space:1 )
    (break-unless above-expanded?:boolean)
    (reply n:integer/index)
  }
  (k:integer/index <- instruction-trace-num-children traces:instruction-trace-address-array-address/space:1 expanded-index:integer/space:1)
  (result:integer/index <- subtract n:integer/screen k:integer/index)
  (reply result:integer/index)
])

;; modify screen state in response to a single key
(function process-key [
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:screen-state <- next-input)
  (k:keyboard-address <- next-input)
  (screen:terminal-address <- next-input)
  (c:character <- read-key k:keyboard-address silent:literal/terminal)
  { begin
    ; no key yet
    (break-if c:character)
    (reply nil:literal)
  }
  { begin
    ; user quit
    (q-pressed?:boolean <- equal c:character ((#\q literal)))
    (end-of-fake-keyboard-input?:boolean <- equal c:character ((#\null literal)))
    (quit?:boolean <- or q-pressed?:boolean end-of-fake-keyboard-input?:boolean)
    (break-unless quit?:boolean)
    (reply t:literal)
  }
  ; up/down navigation
  { begin
    (up?:boolean <- equal c:character ((up literal)))
    (k?:boolean <- equal c:character ((#\k literal)))
    (up?:boolean <- or up?:boolean k?:boolean)
    (break-unless up?:boolean)
    (up 0:space-address/screen-state screen:terminal-address)
    (reply nil:literal)
  }
  { begin
    (down?:boolean <- equal c:character ((down literal)))
    (j?:boolean <- equal c:character ((#\j literal)))
    (down?:boolean <- or down?:boolean j?:boolean)
    (break-unless down?:boolean)
    (down 0:space-address/screen-state screen:terminal-address)
    (reply nil:literal)
  }
  ; enter: expand/collapse current row
  { begin
    (toggle?:boolean <- equal c:character ((#\newline literal)))
    (break-unless toggle?:boolean)
    (original-cursor-row:integer <- copy cursor-row:integer/space:1)
;?     ($print original-cursor-row:integer) ;? 1
;?     ($print (("\n" literal))) ;? 1
    (original-trace-index:integer <- cursor-row-to-trace-index 0:space-address/screen-state original-cursor-row:integer)
;?     ($print original-trace-index:integer) ;? 1
;?     ($print (("\n" literal))) ;? 1
    ; is expanded-index already set?
    { begin
      (expanded?:boolean <- greater-or-equal expanded-index:integer/space:1 0:literal)
      (break-unless expanded?:boolean)
      { begin
        ; are we at the expanded row?
        (at-expanded?:boolean <- equal cursor-row:integer/space:1 expanded-index:integer/space:1)
        (break-unless at-expanded?:boolean)
        ; print remaining lines collapsed and return
        (expanded-index:integer/space:1 <- copy -1:literal)
        (print-traces-collapsed-from 0:space-address/screen-state screen:terminal-address cursor-row:integer/space:1)
        (back-to 0:space-address/screen-state screen:terminal-address original-cursor-row:integer)
        (reply)
      }
      ; are we below the expanded row?
      { begin
        (below-expanded?:boolean <- greater-than cursor-row:integer/space:1 expanded-index:integer/space:1)
        (break-unless below-expanded?:boolean)
        ; scan up to expanded row
        { begin
          (at-expanded?:boolean <- equal cursor-row:integer/space:1 expanded-index:integer/space:1)
          (break-if at-expanded?:boolean)
          (up 0:space-address screen:terminal-address)
          (loop)
        }
        ; print traces collapsed until just before original row
        { begin
          (done?:boolean <- greater-or-equal cursor-row:integer/space:1 original-trace-index:integer)
          (break-if done?:boolean)
          (tr:instruction-trace-address <- index traces:instruction-trace-address-array-address/space:1/deref cursor-row:integer/space:1)
          (print-instruction-trace-collapsed screen:terminal-address tr:instruction-trace-address 0:space-address/screen-state)
          (loop)
        }
        ; fall through
      }
    }
    ; expand original row and print traces below it
    (expanded-index:integer/space:1 <- copy original-trace-index:integer)
    (tr:instruction-trace-address <- index traces:instruction-trace-address-array-address/space:1/deref original-trace-index:integer)
    (print-instruction-trace screen:terminal-address tr:instruction-trace-address 0:space-address/screen-state)
    (next-index:integer <- add original-trace-index:integer 1:literal)
;?     ($print next-index:integer) ;? 1
;?     ($print (("\n" literal))) ;? 1
    (print-traces-collapsed-from 0:space-address/screen-state screen:terminal-address next-index:integer)
    (back-to 0:space-address/screen-state screen:terminal-address original-trace-index:integer)
    (reply nil:literal)
  }
  (reply nil:literal)
])

(function browse-trace [
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (x:string-address <- next-input)
  (screen-height:integer <- next-input)
;?   ($start-tracing) ;? 1
;?   (x:string-address <- new
;? "schedule: main
;? run: main 0: (((1 integer)) <- ((copy)) ((1 literal)))
;? run: main 0: 1 => ((1 integer))
;? mem: ((1 integer)): 1 <= 1
;? run: main 1: (((2 integer)) <- ((copy)) ((3 literal)))
;? run: main 1: 3 => ((2 integer))
;? mem: ((2 integer)): 2 <= 3
;? run: main 2: (((3 integer)) <- ((add)) ((1 integer)) ((2 integer)))
;? mem: ((1 integer)) => 1
;? mem: ((2 integer)) => 3
;? run: main 2: 4 => ((3 integer))
;? mem: ((3 integer)): 3 <= 4
;? schedule:  done with routine")
  (s:stream-address <- init-stream x:string-address)
  (traces:instruction-trace-address-array-address <- parse-traces s:stream-address)
  (0:space-address/names:screen-state <- screen-state traces:instruction-trace-address-array-address screen-height:integer)
  (cursor-mode)
  (print-traces-collapsed 0:space-address/screen-state nil:literal/terminal)
  { begin
    (quit?:boolean <- process-key 0:space-address/screen-state nil:literal/keyboard nil:literal/terminal)
    (break-if quit?:boolean)
    (loop)
  }
  ; move cursor to bottom before exiting
  (to-bottom 0:space-address/screen-state nil:literal/terminal)
  (retro-mode)
])

(function main [
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
  (browse-trace x:string-address)
])
