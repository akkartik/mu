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
;?   ($print (("parse-traces\n" literal))) ;? 2
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

(function print-instruction-trace-parent [
  (default-space:space-address <- new space:literal 30:literal)
  (screen:terminal-address <- next-input)
  (x:instruction-trace-address <- next-input)
  (0:space-address/names:browser-state <- next-input)
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
  (add-line 0:space-address/browser-state screen:terminal-address)
])

(function print-instruction-trace [
  (default-space:space-address <- new space:literal 30:literal)
  (screen:terminal-address <- next-input)
  (x:instruction-trace-address <- next-input)
  (0:space-address/names:browser-state <- next-input)
  (print-instruction-trace-parent screen:terminal-address x:instruction-trace-address 0:space-address/browser-state)
  ; print children
  (ch:trace-address-array-address <- get x:instruction-trace-address/deref children:offset)
  (i:integer <- copy 0:literal)
  { begin
    ; todo: test
    (break-if ch:trace-address-array-address)
    (reply)
  }
  (len:integer <- length ch:trace-address-array-address/deref)
  (expanded-children:integer/space:1 <- copy len:integer)
  { begin
;?     ($print (("i: " literal))) ;? 1
;?     ($print i:integer) ;? 1
;?     ($print (("\n" literal))) ;? 1
    ; until done with trace
    (done?:boolean <- greater-or-equal i:integer len:integer)
    (break-if done?:boolean)
    ; or screen ends
    (screen-done?:boolean <- greater-or-equal cursor-row:integer/space:1 screen-height:integer/space:1)
    (break-if screen-done?:boolean)
    (t:trace-address <- index ch:trace-address-array-address/deref i:integer)
    (print-character screen:terminal-address ((#\space literal)))
    (print-character screen:terminal-address ((#\space literal)))
    (print-character screen:terminal-address ((#\space literal)))
    (print-trace screen:terminal-address t:trace-address)
    (add-line 0:space-address/browser-state screen:terminal-address)
    (last-subindex-on-page:integer/space:1 <- copy i:integer)
;?     ($print (("subindex: " literal))) ;? 1
;?     ($print last-subindex-on-page:integer/space:1) ;? 1
;?     ($print (("\n" literal))) ;? 1
    (i:integer <- add i:integer 1:literal)
    (loop)
  }
])

(function print-instruction-trace-collapsed [
  (default-space:space-address <- new space:literal 30:literal)
  (screen:terminal <- next-input)
  (x:instruction-trace-address <- next-input)
  (browser-state:space-address <- next-input)
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
  (add-line browser-state:space-address screen:terminal-address)
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
(function browser-state [
  (default-space:space-address <- new space:literal 30:literal/capacity)
  ; trace state
  (traces:instruction-trace-address-array-address <- next-input)  ; the ground truth being rendered
  (expanded-index:integer <- copy -1:literal)  ; currently trace browser only ever shows one item expanded
  (expanded-children:integer <- copy -1:literal)
  (first-index-on-page:integer <- copy 0:literal)  ; 'outer' line with label 'run'
  (first-subindex-on-page:integer <- copy -2:literal)  ; 'inner' line with other labels; -2 or lower => not expanded; -1 => expanded and include parent; 0 => expanded and start at first child
  (last-index-on-page:integer <- copy 0:literal)
  (last-subindex-on-page:integer <- copy -2:literal)
  ; screen state
  (screen-height:integer <- next-input)  ; 'hardware' limitation
  (app-height:integer <- copy 0:literal)  ; area of the screen we're responsible for; can't be larger than screen-height
  (printed-height:integer <- copy 0:literal)  ; part of screen that currently has text; can't be larger than app-height
  (cursor-row:integer <- copy 0:literal)  ; position of cursor on screen; can't be larger than printed-height + 1
  (reply default-space:space-address)
])

(function $dump-browser-state [
  (default-space:space-address/names:browser-state <- next-input)
  ($print expanded-index:integer)
  ($print (("*" literal)))
  ($print expanded-children:integer)
  ($print ((": " literal)))
  ($print first-index-on-page:integer)
  ($print (("/" literal)))
  ($print first-subindex-on-page:integer)
  ($print ((" => " literal)))
  ($print last-index-on-page:integer)
  ($print (("/" literal)))
  ($print last-subindex-on-page:integer)
  ($print (("\n" literal)))
  ($print cursor-row:integer)
  ($print ((" " literal)))
  ($print printed-height:integer)
  ($print ((" " literal)))
  ($print app-height:integer)
  ($print ((" " literal)))
  ($print screen-height:integer)
  ($print (("\n" literal)))
])

(function down [
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:browser-state <- next-input)
  (screen:terminal-address <- next-input)
  ; if at expanded, skip past nested lines
  { begin
    (no-expanded?:boolean <- less-than expanded-index:integer/space:1 0:literal)
    (break-if no-expanded?:boolean)
    (at-expanded?:boolean <- equal cursor-row:integer/space:1 expanded-index:integer/space:1)
    (break-unless at-expanded?:boolean)
;?     ($print (("down: at expanded index\n" literal))) ;? 1
    (n:integer <- instruction-trace-num-children traces:instruction-trace-address-array-address/space:1 expanded-index:integer/space:1)
    (n:integer <- add n:integer 1:literal)
    (i:integer <- copy 0:literal)
    { begin
      (done?:boolean <- greater-or-equal i:integer n:integer)
      (break-if done?:boolean)
;?       ($print (("down: incrementing\n" literal))) ;? 1
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
  (0:space-address/names:browser-state <- next-input)
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
  (0:space-address/names:browser-state <- next-input)
  (screen:terminal-address <- next-input)
  { begin
    (at-bottom?:boolean <- greater-or-equal cursor-row:integer/space:1 printed-height:integer/space:1)
    (break-if at-bottom?:boolean)
    (down 0:space-address screen:terminal-address)
    (loop)
  }
])

(function to-top [
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:browser-state <- next-input)
  (screen:terminal-address <- next-input)
  { begin
    (at-top?:boolean <- lesser-or-equal cursor-row:integer/space:1 0:literal)
    (break-if at-top?:boolean)
    (up 0:space-address screen:terminal-address)
    (loop)
  }
])

(function back-to [
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:browser-state <- next-input)
  (screen:terminal-address <- next-input)
  (target-row:integer <- next-input)
;?   ($print (("before back-to: " literal))) ;? 1
;?   ($print cursor-row:integer/space:1) ;? 1
;?   ($print (("\n" literal))) ;? 1
  { begin
    (below-target?:boolean <- greater-than cursor-row:integer/space:1 target-row:integer)
    (break-unless below-target?:boolean)
;?     ($print (("below target\n" literal))) ;? 1
    (up 0:space-address screen:terminal-address)
    (loop)
  }
  { begin
    (above-target?:boolean <- less-than cursor-row:integer/space:1 target-row:integer)
    (break-unless above-target?:boolean)
;?     ($print (("above target\n" literal))) ;? 1
    (down 0:space-address screen:terminal-address)
    (loop)
  }
;?   ($print (("after back-to: " literal))) ;? 1
;?   ($print cursor-row:integer/space:1) ;? 1
;?   ($print (("\n" literal))) ;? 1
])

(function add-line [  ; move down, adding line if necessary
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:browser-state <- next-input)
  (screen:terminal-address <- next-input)
  { begin
    (at-bottom?:boolean <- greater-or-equal cursor-row:integer/space:1 printed-height:integer/space:1)
    (break-unless at-bottom?:boolean)
    { begin
      (screen-full?:boolean <- greater-or-equal app-height:integer/space:1 screen-height:integer/space:1)
      (break-unless screen-full?:boolean)
      (cursor-to-next-line screen:terminal-address)
      (cursor-up screen:terminal-address)
      (reply)
    }
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
  (0:space-address/names:browser-state <- next-input)
  (screen:terminal-address <- next-input)
;?   ($print (("print traces collapsed\n" literal))) ;? 1
  (print-traces-collapsed-from 0:space-address/browser-state screen:terminal-address 0:literal/from)
  (clear-rest-of-page 0:space-address/browser-state screen:terminal-address)
])

(function print-traces-collapsed-from [
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:browser-state <- next-input)
  (screen:terminal-address <- next-input)
  (trace-index:integer <- next-input)
  (limit-index:integer <- next-input)  ; print until this index (exclusive)
  ; compute bound
  (max:integer <- length traces:instruction-trace-address-array-address/space:1/deref)
  { begin
    (break-unless limit-index:integer)
    (max:integer <- min max:integer limit-index:integer)
  }
  ; print remaining traces collapsed
  { begin
    ; until trace ends
    (trace-done?:boolean <- greater-or-equal trace-index:integer max:integer)
    (break-if trace-done?:boolean)
    ; or screen ends
    (screen-done?:boolean <- greater-or-equal cursor-row:integer/space:1 screen-height:integer/space:1)
    (break-if screen-done?:boolean)
;?     ($print (("screen not done\n" literal))) ;? 1
    ; continue printing trace lines
    (tr:instruction-trace-address <- index traces:instruction-trace-address-array-address/space:1/deref trace-index:integer)
    (last-index-on-page:integer/space:1 <- copy trace-index:integer)
;?     ($print (("setting last index: " literal))) ;? 1
;?     ($print last-index-on-page:integer/space:1) ;? 1
;?     ($print (("\n" literal))) ;? 1
    (last-subindex-on-page:integer/space:1 <- copy -2:literal)
    (print-instruction-trace-collapsed screen:terminal-address tr:instruction-trace-address 0:space-address/browser-state)
    (trace-index:integer <- add trace-index:integer 1:literal)
    (loop)
  }
])

(function clear-rest-of-page [
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:browser-state <- next-input)
  (screen:terminal-address <- next-input)
  { begin
    (done?:boolean <- greater-or-equal cursor-row:integer/space:1 app-height:integer/space:1)
    (break-if done?:boolean)
    (clear-line screen:terminal-address)
    (down 0:space-address/browser-state screen:terminal-address)
    (loop)
  }
])

(function print-page [
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:browser-state <- next-input)
  (screen:terminal-address <- next-input)
;?   ($dump-browser-state 0:space-address/browser-state) ;? 3
  ; if top inside expanded index, complete existing trace
  (first-full-index:integer <- copy first-index-on-page:integer/space:1)
  { begin
    (screen-done?:boolean <- greater-or-equal cursor-row:integer/space:1 screen-height:integer/space:1)
    (break-unless screen-done?:boolean)
    (reply)
  }
;?   ($print (("\nAAA\n" literal))) ;? 4
  { begin
    (partial-trace?:boolean <- equal first-index-on-page:integer/space:1 expanded-index:integer/space:1)
    (break-unless partial-trace?:boolean)
;?   ($print (("AAA: partial\n" literal))) ;? 4
    (first-full-index:integer <- add first-full-index:integer 1:literal)
    (tr:instruction-trace-address <- index traces:instruction-trace-address-array-address/space:1/deref first-index-on-page:integer/space:1)
    { begin
      (print-parent?:boolean <- equal first-subindex-on-page:integer/space:1 -1:literal)
      (break-unless print-parent?:boolean)
      (print-instruction-trace-parent screen:terminal-address tr:instruction-trace-address 0:space-address/browser-state)
    }
    (ch:trace-address-array-address <- get tr:instruction-trace-address/deref children:offset)
    (i:integer <- max first-subindex-on-page:integer/space:1 0:literal)
    ; print any remaining data in the currently expanded trace
    { begin
      ; until done with trace
      (done?:boolean <- greater-or-equal i:integer expanded-children:integer/space:1)
      (break-if done?:boolean)
      ; or screen ends
      (screen-done?:boolean <- greater-or-equal cursor-row:integer/space:1 screen-height:integer/space:1)
      (break-if screen-done?:boolean)
;?       ($print (("AAA printing subtrace\n" literal))) ;? 3
      (t:trace-address <- index ch:trace-address-array-address/deref i:integer)
      (print-character screen:terminal-address ((#\space literal)))
      (print-character screen:terminal-address ((#\space literal)))
      (print-character screen:terminal-address ((#\space literal)))
      (print-trace screen:terminal-address t:trace-address)
      (add-line 0:space-address/browser-state screen:terminal-address)
      (last-subindex-on-page:integer/space:1 <- copy i:integer)
      (i:integer <- add i:integer 1:literal)
      (loop)
    }
  }
;?   ($print (("AAA 3: " literal))) ;? 5
;?   ($print cursor-row:integer/space:1) ;? 4
;?   ($print (("\n" literal))) ;? 4
  { begin
    (screen-done?:boolean <- greater-or-equal cursor-row:integer/space:1 screen-height:integer/space:1)
    (break-unless screen-done?:boolean)
    (reply)
  }
;?   ($print (("AAA 4\n" literal))) ;? 5
  { begin
    (has-expanded?:boolean <- greater-or-equal expanded-index:integer/space:1 0:literal)
    (break-if has-expanded?:boolean)
;?     ($print (("AAA 5a\n" literal))) ;? 4
    (print-traces-collapsed-from 0:space-address/browser-state screen:terminal-address first-full-index:integer)
    (clear-rest-of-page 0:space-address/browser-state screen:terminal-address)
    (reply)
  }
  { begin
    (below-expanded?:boolean <- greater-than first-full-index:integer expanded-index:integer/space:1)
    (break-unless below-expanded?:boolean)
;?     ($print (("AAA 5b\n" literal))) ;? 4
    (print-traces-collapsed-from 0:space-address/browser-state screen:terminal-address first-full-index:integer)
    (clear-rest-of-page 0:space-address/browser-state screen:terminal-address)
    (reply)
  }
  ; trace has an expanded index and it's below first-full-index
  ; print traces collapsed until expanded index
;?   ($print (("AAA 5c\n" literal))) ;? 4
  (print-traces-collapsed-from 0:space-address/browser-state screen:terminal-address first-full-index:integer expanded-index:integer/space:1/until)
  ; if room, start printing expanded index
  { begin
    (done?:boolean <- greater-or-equal cursor-row:integer/space:1 screen-height:integer/space:1)
    (break-if done?:boolean)
    (tr:instruction-trace-address <- index traces:instruction-trace-address-array-address/space:1/deref expanded-index:integer/space:1)
    (print-instruction-trace screen:terminal-address tr:instruction-trace-address 0:space-address/browser-state)
    (clear-rest-of-page 0:space-address/browser-state screen:terminal-address)
  }
])

(function cursor-row-to-trace-index [
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:browser-state <- next-input)
  (n:integer/screen <- next-input)
;?   ($print (("cursor-to-index: n " literal))) ;? 1
;?   ($print n:integer) ;? 1
;?   ($print (("\n" literal))) ;? 1
;?   ($print (("cursor-to-index: first index " literal))) ;? 1
;?   ($print first-index-on-page:integer/space:1) ;? 1
;?   ($print (("\n" literal))) ;? 1
  (simple-result:integer <- add first-index-on-page:integer/space:1 n:integer)
;?   ($print (("cursor-to-index: simple result " literal))) ;? 1
;?   ($print simple-result:integer) ;? 1
;?   ($print (("\n" literal))) ;? 1
  ; no row expanded? no munging needed
  { begin
    (has-expanded?:boolean <- greater-or-equal expanded-index:integer/space:1 0:literal)
    (break-if has-expanded?:boolean)
    (reply simple-result:integer)
  }
  ; expanded row above current page? no munging needed
  { begin
    (below-expanded?:boolean <- less-than expanded-index:integer/space:1 first-index-on-page:integer/space:1)
    (break-unless below-expanded?:boolean)
    (reply simple-result:integer)
  }
  ; expanded row at top of current page and partial?
  { begin
    (expanded-at-top?:boolean <- equal first-index-on-page:integer/space:1 expanded-index:integer/space:1)
;?     ($print (("cursor-to-index: first subindex " literal))) ;? 1
;?     ($print first-subindex-on-page:integer/space:1) ;? 1
;?     ($print (("\n" literal))) ;? 1
    (partial-at-top?:boolean <- greater-or-equal first-subindex-on-page:integer/space:1 0:literal)
    (partial-expanded-at-top?:boolean <- and expanded-at-top?:boolean partial-at-top?:boolean)
    (break-unless partial-expanded-at-top?:boolean)
;?     ($print (("expanded child at top of page\n" literal))) ;? 1
    (expanded-children-on-page:integer <- subtract expanded-children:integer/space:1 first-subindex-on-page:integer/space:1)
    (result:integer <- subtract simple-result:integer expanded-children-on-page:integer)
    (result:integer <- add result:integer 1:literal)
    (result:integer <- max result:integer first-index-on-page:integer/space:1)
    (reply result:integer)
  }
  ; expanded row is below current page? no munging needed
  { begin
    (above-expanded?:boolean <- lesser-or-equal last-index-on-page:integer/space:1 expanded-index:integer/space:1 )
    (break-unless above-expanded?:boolean)
    (reply simple-result:integer)
  }
  (expanded-index-cursor-row:integer <- subtract expanded-index:integer/space:1 first-index-on-page:integer/space:1)
  ; cursor is above expanded index? no munging needed
  { begin
    (above-expanded?:boolean <- lesser-or-equal cursor-row:integer/space:1 expanded-index-cursor-row:integer)
    (break-unless above-expanded?:boolean)
    (reply simple-result:integer)
  }
  (result:integer/index <- subtract simple-result:integer expanded-children:integer/space:1)
  (reply result:integer/index)
])

(function back-to-index [
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:browser-state <- next-input)
  (screen:terminal-address <- next-input)
  (target-index:integer <- next-input)
;?   ($print (("back-to-index: target " literal))) ;? 2
;?   ($print target-index:integer) ;? 2
;?   ($print (("\n" literal))) ;? 2
  ; scan up until top, or *before* target-index (to skip expanded children)
  { begin
    (at-top?:boolean <- equal cursor-row:integer/space:1 0:literal)
    (break-if at-top?:boolean)
    (index:integer <- cursor-row-to-trace-index 0:space-address/browser-state cursor-row:integer/space:1)
;?     ($print cursor-row:integer/space:1) ;? 2
;?     ($print ((" " literal))) ;? 2
;?     ($print index:integer) ;? 2
;?     ($print (("\n" literal))) ;? 2
    (done?:boolean <- less-than index:integer target-index:integer)
    (break-if done?:boolean)
    (up 0:space-address screen:terminal-address)
    (loop)
  }
  ; now if we're before target-index, down 1
  (index:integer <- cursor-row-to-trace-index 0:space-address/browser-state cursor-row:integer/space:1)
;?   ($print (("done scanning; cursor at row " literal))) ;? 1
;?   ($print cursor-row:integer/space:1) ;? 1
;?   ($print ((", which is index " literal))) ;? 1
;?   ($print index:integer) ;? 1
;?   ($print (("\n" literal))) ;? 1
  { begin
    (at-target?:boolean <- greater-or-equal index:integer target-index:integer)
    (break-if at-target?:boolean)
;?     ($print (("down 1\n" literal))) ;? 1
    ; above expanded
    (down 0:space-address screen:terminal-address)
  }
])

;; pagination helpers
(function at-first-page [
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:browser-state <- next-input)  ; read-only
  (result:boolean <- lesser-or-equal first-index-on-page:integer/space:1 0:literal)
  { begin
    (break-if result:boolean)
    (reply nil:literal)
  }
  (expanded?:boolean <- equal expanded-index:integer/space:1 0:literal)
  { begin
    (break-if expanded?:boolean)
    (reply t:literal)
  }
  ; if first subindex is 0, the top-level line is on a previous page
  (result:boolean <- less-than first-subindex-on-page:integer/space:1 0:literal)
  (reply result:boolean)
])

(function at-final-page [
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:browser-state <- next-input)  ; read-only
  (len:integer <- length traces:instruction-trace-address-array-address/space:1/deref)
  (final-index:integer <- subtract len:integer 1:literal)
  (result:boolean <- greater-or-equal last-index-on-page:integer/space:1 final-index:integer)
  { begin
    (break-if result:boolean)
    (reply nil:literal)
  }
  (last-trace-expanded?:boolean <- equal expanded-index:integer/space:1 len:integer)
  { begin
    (break-if last-trace-expanded?:boolean)
    (reply t:literal)
  }
  (result:boolean <- greater-or-equal last-subindex-on-page:integer/space:1 expanded-children:integer/space:1)
  (reply result:boolean)
])

(function next-page [
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:browser-state <- next-input)
  { begin
;?     ($print (("expanded: " literal))) ;? 2
;?     ($print expanded-index:integer/space:1) ;? 2
;?     ($print ((" last index: " literal))) ;? 2
;?     ($print last-index-on-page:integer/space:1) ;? 2
;?     ($print (("\n" literal))) ;? 2
    (last-index-expanded?:boolean <- equal expanded-index:integer/space:1 last-index-on-page:integer/space:1)
    (break-unless last-index-expanded?:boolean)
    ; expanded
;?     ($print (("last expanded\n" literal))) ;? 2
    { begin
      (expanded-index-done?:boolean <- equal expanded-children:integer/space:1 last-subindex-on-page:integer/space:1)
      (break-if expanded-index-done?:boolean 2:blocks)
;?       ($print (("children left\n" literal))) ;? 2
      ; children left to open
      (first-index-on-page:integer/space:1 <- copy last-index-on-page:integer/space:1)
      (first-subindex-on-page:integer/space:1 <- add last-subindex-on-page:integer/space:1 1:literal)
      (reply)
    }
  }
  (first-index-on-page:integer/space:1 <- add last-index-on-page:integer/space:1 1:literal)
  (first-subindex-on-page:integer/space:1 <- copy -2:integer)
])

(function previous-page [
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:browser-state <- next-input)
;?   ($print (("before: " literal))) ;? 2
;?   ($print first-index-on-page:integer/space:1) ;? 2
;?   ($print ((" " literal))) ;? 2
;?   ($print first-subindex-on-page:integer/space:1) ;? 2
;?   ($print (("\n" literal))) ;? 2
  ; easy case: no expanded-index
  (jump-unless expanded-index:integer/space:1)
;?   ($print (("b\n" literal))) ;? 4
  (x:boolean <- less-than expanded-index:integer/space:1 0:literal)
  (jump-if x:boolean easy-case:offset)
  ; easy case: expanded-index lies below top of current page
;?   ($print (("c\n" literal))) ;? 4
  (x:boolean <- greater-than expanded-index:integer/space:1 first-index-on-page:integer/space:1)
  (jump-if x:boolean easy-case:offset)
  ; easy case: expanded-index *starts* at top of current page
;?   ($print (("d\n" literal))) ;? 5
  (top-of-screen-inside-expanded:boolean <- equal expanded-index:integer/space:1 first-index-on-page:integer/space:1)
  (y:boolean <- lesser-or-equal first-subindex-on-page:integer/space:1 -1:literal)
  (y:boolean <- and top-of-screen-inside-expanded:boolean y:boolean)
  (jump-if y:boolean easy-case:offset)
  ; easy case: expanded-index too far up for previous page
;?   ($print (("e\n" literal))) ;? 5
  (delta-to-expanded:integer <- subtract first-index-on-page:integer/space:1 expanded-index:integer/space:1)
;?   ($print delta-to-expanded:integer) ;? 1
;?   ($print (("\n" literal))) ;? 1
  (x:boolean <- greater-than delta-to-expanded:integer screen-height:integer/space:1)
  (jump-if x:boolean easy-case:offset)
;?   ($print (("f\n" literal))) ;? 5
  ; tough case: expanded index overlaps current and/or previous page
  (lines-remaining-to-decrement:integer <- copy screen-height:integer/space:1)
  ; a) scroll to just below expanded-index if necessary
  (below-expanded-index:integer <- add expanded-index:integer/space:1 1:literal)
  { begin
    (done?:boolean <- done-scrolling-up default-space:space-address)
    (break-if done?:boolean)
    (done?:boolean <- lesser-or-equal first-index-on-page:integer/space:1 below-expanded-index:integer)
    (break-if done?:boolean)
;?     ($print (("g\n" literal))) ;? 2
    (first-index-on-page:integer/space:1 <- subtract first-index-on-page:integer/space:1 1:literal)
    (lines-remaining-to-decrement:integer <- subtract lines-remaining-to-decrement:integer 1:literal)
    (loop)
  }
  { begin
;?     ($print (("h\n" literal))) ;? 2
    (x:boolean <- equal first-index-on-page:integer/space:1 below-expanded-index:integer)
    (break-unless x:boolean)
    (first-index-on-page:integer/space:1 <- copy expanded-index:integer/space:1)
    (first-subindex-on-page:integer/space:1 <- subtract expanded-children:integer/space:1 1:literal)
    (lines-remaining-to-decrement:integer <- subtract lines-remaining-to-decrement:integer 1:literal)
  }
  ; b) scroll through expanded-children if necessary
  { begin
    (done?:boolean <- done-scrolling-up default-space:space-address)
    (break-if done?:boolean)
    (done?:boolean <- less-than first-subindex-on-page:integer/space:1 0:literal)
    (break-if done?:boolean)
;?     ($print (("i\n" literal))) ;? 2
    (first-subindex-on-page:integer/space:1 <- subtract first-subindex-on-page:integer/space:1 1:literal)
    (lines-remaining-to-decrement:integer <- subtract lines-remaining-to-decrement:integer 1:literal)
    (loop)
  }
  ; c) jump past expanded-index parent if necessary
;?   ($print (("j\n" literal))) ;? 2
  { begin
    (done?:boolean <- done-scrolling-up default-space:space-address)
    (break-if done?:boolean)
;?     ($print (("k\n" literal))) ;? 2
    (first-index-on-page:integer/space:1 <- subtract first-index-on-page:integer/space:1 1:literal)
    (first-subindex-on-page:integer/space:1 <- copy -2:literal)
    (lines-remaining-to-decrement:integer <- subtract lines-remaining-to-decrement:integer 1:literal)
  }
  ; d) scroll up before expanded-index if necessary
;?   ($print (("l\n" literal))) ;? 2
  { begin
    (done?:boolean <- done-scrolling-up default-space:space-address)
    (break-if done?:boolean)
;?     ($print (("m\n" literal))) ;? 2
    (first-index-on-page:integer/space:1 <- subtract first-index-on-page:integer/space:1 1:literal)
    (lines-remaining-to-decrement:integer <- subtract lines-remaining-to-decrement:integer 1:literal)
    (loop)
  }
  (reply)
  easy-case
  (first-index-on-page:integer/space:1 <- subtract first-index-on-page:integer/space:1 screen-height:integer/space:1)
  (first-index-on-page:integer/space:1 <- max first-index-on-page:integer/space:1 0:literal)
  (first-subindex-on-page:integer/space:1 <- copy -2:literal)
])

(function done-scrolling-up [
  (default-space:space-address/names:previous-page <- next-input)
  (0:space-address/names:browser-state <- copy 0:space-address)  ; just to wire up names for space/1
  (at-top-of-screen?:boolean <- lesser-or-equal lines-remaining-to-decrement:integer 0:literal)
  (jump-if at-top-of-screen?:boolean done:offset)
  (at-first-index:boolean <- lesser-or-equal first-index-on-page:integer/space:1 0:literal)
  (at-first-subindex:boolean <- lesser-or-equal first-subindex-on-page:integer/space:1 -1:literal)
  (trace-done?:boolean <- and at-first-index:boolean at-first-subindex:boolean)
  (jump-if trace-done?:boolean done:offset)
  (reply nil:literal)
  done
  (reply t:literal)
])

;; modify screen state in response to a single key
(function process-key [
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:browser-state <- next-input)
  (k:keyboard-address <- next-input)
  (screen:terminal-address <- next-input)
  (c:character <- read-key k:keyboard-address silent:literal/terminal)
  { begin
    ; no key yet
    (break-if c:character)
    (reply nil:literal)
  }
;?   ($print (("key pressed: " literal))) ;? 1
;?   ($write c:character) ;? 1
;?   ($print (("\n" literal))) ;? 1
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
    (up 0:space-address/browser-state screen:terminal-address)
    (reply nil:literal)
  }
  { begin
    (down?:boolean <- equal c:character ((down literal)))
    (j?:boolean <- equal c:character ((#\j literal)))
    (down?:boolean <- or down?:boolean j?:boolean)
    (break-unless down?:boolean)
    (down 0:space-address/browser-state screen:terminal-address)
    (reply nil:literal)
  }
  ; page up/page down
  { begin
    ; if page-up pressed
    (page-up?:boolean <- equal c:character ((pgup literal)))
    (K?:boolean <- equal c:character ((#\K literal)))
    (page-up?:boolean <- or page-up?:boolean K?:boolean)
    (break-unless page-up?:boolean)
    ; if we're not already at start of trace
    (first-page?:boolean <- at-first-page 0:space-address/browser-state)
    (break-if first-page?:boolean)
    ; move cursor to top of screen
    (to-top 0:space-address/browser-state screen:terminal-address)
    ; switch browser state
    (previous-page 0:space-address/browser-state)
;?     ($dump-browser-state 0:space-address) ;? 3
    ; redraw
    (print-page 0:space-address/browser-state screen:terminal-address)
    (reply nil:literal)
  }
  { begin
    ; if page-down pressed
    (page-down?:boolean <- equal c:character ((pgdn literal)))
    (J?:boolean <- equal c:character ((#\J literal)))
    (page-down?:boolean <- or page-down?:boolean J?:boolean)
    (break-unless page-down?:boolean)
    ; if we're not already at end of trace
    (final-page?:boolean <- at-final-page 0:space-address/browser-state)
    (break-if final-page?:boolean)
    ; move cursor to top of screen
    (to-top 0:space-address/browser-state screen:terminal-address)
;?     ($print (("before: " literal))) ;? 1
;?     ($print first-index-on-page:integer/space:1) ;? 1
;?     ($print (("\n" literal))) ;? 1
    ; switch browser state
    (next-page 0:space-address/browser-state)
;?     ($print (("after: " literal))) ;? 1
;?     ($print first-index-on-page:integer/space:1) ;? 1
;?     ($print (("\n" literal))) ;? 1
    ; redraw
    (print-page 0:space-address/browser-state screen:terminal-address)
    ; move cursor back to top of screen
    (to-top 0:space-address/browser-state screen:terminal-address)
    (reply nil:literal)
  }
  ; enter: expand/collapse current row
  { begin
    (toggle?:boolean <- equal c:character ((#\newline literal)))
    (break-unless toggle?:boolean)
    (original-cursor-row:integer <- copy cursor-row:integer/space:1)
;?     ($print (("cursor starts at row " literal))) ;? 5
;?     ($print original-cursor-row:integer) ;? 6
;?     ($print (("\n" literal))) ;? 6
    (original-trace-index:integer <- cursor-row-to-trace-index 0:space-address/browser-state original-cursor-row:integer)
;?     ($print (("which maps to index " literal))) ;? 6
;?     ($print original-trace-index:integer) ;? 8
;?     ($print (("\n" literal))) ;? 8
    ; is expanded-index already set?
    { begin
      (expanded?:boolean <- greater-or-equal expanded-index:integer/space:1 0:literal)
      (break-unless expanded?:boolean)
      (too-early?:boolean <- less-than expanded-index:integer/space:1 first-index-on-page:integer/space:1)
      (break-if too-early?:boolean)
      (too-late?:boolean <- greater-than expanded-index:integer/space:1 last-index-on-page:integer/space:1)
      (break-if too-late?:boolean)
      ; expanded-index is now on this page
;?       ($print (("expanded index on this page\n" literal))) ;? 5
      { begin
        ; are we at the expanded row?
        (at-expanded?:boolean <- equal original-trace-index:integer expanded-index:integer/space:1)
        (break-unless at-expanded?:boolean)
;?         ($print (("at expanded index\n" literal))) ;? 4
        ; print remaining lines collapsed and return
        (back-to-index 0:space-address/browser-state screen:terminal-address expanded-index:integer/space:1)
        (expanded-index:integer/space:1 <- copy -1:literal)
        (expanded-children:integer/space:1 <- copy -1:literal)
        (print-traces-collapsed-from 0:space-address/browser-state screen:terminal-address original-trace-index:integer)
        (clear-rest-of-page 0:space-address/browser-state screen:terminal-address)
        (back-to 0:space-address/browser-state screen:terminal-address original-cursor-row:integer)
        (reply nil:literal)
      }
      ; are we below the expanded row?
      { begin
        (below-expanded?:boolean <- greater-than original-trace-index:integer expanded-index:integer/space:1)
        (break-unless below-expanded?:boolean)
;?         ($print (("below expanded index\n" literal))) ;? 5
        (back-to-index 0:space-address/browser-state screen:terminal-address expanded-index:integer/space:1)
;?         ($print (("scanning up to row " literal))) ;? 2
;?         ($print cursor-row:integer/space:1) ;? 2
;?         ($print (("\n" literal))) ;? 2
        ; print traces collapsed until just before original row
        (print-traces-collapsed-from 0:space-address/browser-state screen:terminal-address expanded-index:integer/space:1 original-trace-index:integer/until)
        ; fall through
      }
    }
    ; expand original row and print traces below it
;?     ($print (("done collapsing previously expanded index\n" literal))) ;? 5
    (expanded-index:integer/space:1 <- copy original-trace-index:integer)
    (last-index-on-page:integer/space:1 <- copy original-trace-index:integer)
    (tr:instruction-trace-address <- index traces:instruction-trace-address-array-address/space:1/deref original-trace-index:integer)
;?     ($print (("expanded\n" literal))) ;? 5
    (print-instruction-trace screen:terminal-address tr:instruction-trace-address 0:space-address/browser-state)
    (next-index:integer <- add original-trace-index:integer 1:literal)
;?     ($print (("printing collapsed lines from " literal))) ;? 6
;?     ($print next-index:integer) ;? 7
;?     ($print (("\n" literal))) ;? 7
    (print-traces-collapsed-from 0:space-address/browser-state screen:terminal-address next-index:integer)
;?     ($print (("clearing rest of page\n" literal))) ;? 5
    (clear-rest-of-page 0:space-address/browser-state screen:terminal-address)
;?     ($print (("moving cursor back up\n" literal))) ;? 5
    (back-to-index 0:space-address/browser-state screen:terminal-address original-trace-index:integer)
;?     ($print (("returning\n" literal))) ;? 4
    (reply nil:literal)
  }
  (reply nil:literal)
])

(function browse-trace [
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (x:string-address <- next-input)
  (screen-height:integer <- next-input)
  (s:stream-address <- init-stream x:string-address)
  (traces:instruction-trace-address-array-address <- parse-traces s:stream-address)
  (0:space-address/names:browser-state <- browser-state traces:instruction-trace-address-array-address screen-height:integer)
  (cursor-mode)
  (print-traces-collapsed 0:space-address/browser-state nil:literal/terminal)
  { begin
    (quit?:boolean <- process-key 0:space-address/browser-state nil:literal/keyboard nil:literal/terminal)
    (break-if quit?:boolean)
    (loop)
  }
  ; move cursor to bottom before exiting
  (to-bottom 0:space-address/browser-state nil:literal/terminal)
  (retro-mode)
])

(function main [
  (default-space:space-address <- new space:literal 30:literal/capacity)
  ($print (("loading trace.. (takes ~10s)\n" literal)))
  (x:string-address <- new
"run: main 0: a b c
mem: 0
run: main 1: d e f
mem: 1
mem: 1
mem: 1
mem: 1
mem: 1
run: main 2: g hi
run: main 3: j
mem: 3
run: main 4: k
run: main 5: l
run: main 6: m
run: main 7: n
run: main 8: o")
  (browse-trace x:string-address 3:literal/screen-height)
])
