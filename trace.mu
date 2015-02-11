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

;; data structure
(function screen-state [
  (default-space:space-address <- new space:literal 30:literal/capacity)
  ; app-specific coordinates depending on where the cursor was when the trace
  ; browser was started
  (cursor-row:integer <- copy 0:literal)
  (max-rows:integer <- copy 0:literal)  ; area of the screen we're responsible for
  (height:integer <- copy 0:literal)  ; part of it that currently has text
  (reply default-space:space-address)
])

(function down [
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:screen-state <- next-input)
  (screen:terminal-address <- next-input)
  { begin
    (at-bottom?:boolean <- greater-or-equal cursor-row:integer/space:1 height:integer/space:1)
    (break-if at-bottom?:boolean)
    (cursor-row:integer/space:1 <- add cursor-row:integer/space:1 1:literal)
    (cursor-down screen:terminal-address)
  }
])

(function up [
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:screen-state <- next-input)
  (screen:terminal-address <- next-input)
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
    (at-bottom?:boolean <- greater-or-equal cursor-row:integer/space:1 height:integer/space:1)
    (break-if at-bottom?:boolean)
    (down 0:space-address screen:terminal-address)
    (loop)
  }
])

(function add-line [  ; move down, adding line if necessary
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:screen-state <- next-input)
  (screen:terminal-address <- next-input)
  { begin
    (at-bottom?:boolean <- greater-or-equal cursor-row:integer/space:1 height:integer/space:1)
    (break-unless at-bottom?:boolean)
    (height:integer/space:1 <- add height:integer/space:1 1:literal)
  }
  (cursor-row:integer/space:1 <- add cursor-row:integer/space:1 1:literal)
  (cursor-to-next-line screen:terminal-address)
])

(function main [
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:screen-state <- screen-state)
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
  (arr:instruction-trace-address-array-address <- parse-traces s:stream-address)
  (len:integer <- length arr:instruction-trace-address-array-address/deref)
;?   ($print (("#traces: " literal))) ;? 1
;?   ($print len:integer) ;? 1
;?   ($print (("\n" literal))) ;? 1
  (cursor-mode)
  ; print trace collapsed
  (i:integer <- copy 0:literal)
  { begin
    (done?:boolean <- greater-or-equal i:integer len:integer)
    (break-if done?:boolean)
    (tr:instruction-trace-address <- index arr:instruction-trace-address-array-address/deref i:integer)
    (print-instruction-trace-collapsed nil:literal/terminal tr:instruction-trace-address 0:space-address/screen-state)
    (i:integer <- add i:integer 1:literal)
    (loop)
  }
  ; handle key presses
  { begin
    next-key
    (c:character <- read-key nil:literal/keyboard silent:literal/terminal)
    (loop-unless c:character)
    (quit?:boolean <- equal c:character ((#\q literal)))
    (break-if quit?:boolean)
    (quit?:boolean <- equal c:character ((#\null literal)))
    (break-if quit?:boolean)
    ; up/down navigation
    { begin
      (up?:boolean <- equal c:character ((up literal)))
      (k?:boolean <- equal c:character ((#\k literal)))
      (up?:boolean <- or up?:boolean k?:boolean)
      (break-unless up?:boolean)
      (up 0:space-address/screen-state nil:literal/terminal)
      (jump next-key:offset)  ; loop
    }
    { begin
      (down?:boolean <- equal c:character ((down literal)))
      (j?:boolean <- equal c:character ((#\j literal)))
      (down?:boolean <- or down?:boolean j?:boolean)
      (break-unless down?:boolean)
      (down 0:space-address/screen-state nil:literal/terminal)
      (jump next-key:offset)  ; loop
    }
    ; enter: expand current row
    { begin
      (toggle?:boolean <- equal c:character ((#\newline literal)))
      (break-unless toggle?:boolean)
      (tr:instruction-trace-address <- index arr:instruction-trace-address-array-address/deref cursor-row:integer/space:1)
      (print-instruction-trace nil:literal/terminal tr:instruction-trace-address 0:space-address/screen-state)
      (jump next-key:offset)  ; loop
    }
    (loop)
  }
  ; move cursor to bottom before exiting
  (to-bottom 0:space-address/screen-state nil:literal/terminal)
])
