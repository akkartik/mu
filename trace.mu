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
;?   ($print (("print-page " literal))) ;? 1
;?   ($print first-index-on-page:integer/space:1) ;? 1
;?   ($print ((" " literal))) ;? 1
;?   ($print first-subindex-on-page:integer/space:1) ;? 1
;?   ($print (("\n" literal))) ;? 1
  (screen:terminal-address <- next-input)
;?   ($dump-browser-state 0:space-address/browser-state) ;? 1
  ; if top inside expanded index, complete existing trace
  (first-full-index:integer <- copy first-index-on-page:integer/space:1)
;?   ($print first-full-index:integer) ;? 1
;?   ($print cursor-row:integer/space:1) ;? 1
  { begin
    (screen-done?:boolean <- greater-or-equal cursor-row:integer/space:1 screen-height:integer/space:1)
    (break-unless screen-done?:boolean)
    (reply)
  }
;?   ($print (("\nAAA\n" literal))) ;? 1
  { begin
    (partial-trace?:boolean <- equal first-index-on-page:integer/space:1 expanded-index:integer/space:1)
    (break-unless partial-trace?:boolean)
;?   ($print (("AAA: partial\n" literal))) ;? 1
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
;?   ($print (("AAA 3: " literal))) ;? 2
;?   ($print cursor-row:integer/space:1) ;? 1
;?   ($print (("\n" literal))) ;? 1
  { begin
    (screen-done?:boolean <- greater-or-equal cursor-row:integer/space:1 screen-height:integer/space:1)
    (break-unless screen-done?:boolean)
    (reply)
  }
;?   ($print (("AAA 4\n" literal))) ;? 2
  { begin
    (has-expanded?:boolean <- greater-or-equal expanded-index:integer/space:1 0:literal)
    (break-if has-expanded?:boolean)
;?     ($print (("AAA 5a\n" literal))) ;? 1
    (print-traces-collapsed-from 0:space-address/browser-state screen:terminal-address first-full-index:integer)
    (clear-rest-of-page 0:space-address/browser-state screen:terminal-address)
    (reply)
  }
  { begin
    (below-expanded?:boolean <- greater-than first-full-index:integer expanded-index:integer/space:1)
    (break-unless below-expanded?:boolean)
;?     ($print (("AAA 5b\n" literal))) ;? 1
    (print-traces-collapsed-from 0:space-address/browser-state screen:terminal-address first-full-index:integer)
    (clear-rest-of-page 0:space-address/browser-state screen:terminal-address)
    (reply)
  }
  ; trace has an expanded index and it's below first-full-index
  ; print traces collapsed until expanded index
;?   ($print (("AAA 5c\n" literal))) ;? 1
  (print-traces-collapsed-from 0:space-address/browser-state screen:terminal-address first-full-index:integer expanded-index:integer/space:1/until)
  ; if room, start printing expanded index
  (tr:instruction-trace-address <- index traces:instruction-trace-address-array-address/space:1/deref expanded-index:integer/space:1)
  (print-instruction-trace screen:terminal-address tr:instruction-trace-address 0:space-address/browser-state)
  (clear-rest-of-page 0:space-address/browser-state screen:terminal-address)
])

(function cursor-row-to-trace-index [
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:browser-state <- next-input)
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
  (0:space-address/names:browser-state <- next-input)
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
;?     ($dump-browser-state 0:space-address) ;? 1
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
;?     ($print original-cursor-row:integer) ;? 1
;?     ($print (("\n" literal))) ;? 1
    (original-trace-index:integer <- cursor-row-to-trace-index 0:space-address/browser-state original-cursor-row:integer)
;?     ($print original-trace-index:integer) ;? 1
;?     ($print (("\n" literal))) ;? 1
    ; is expanded-index already set?
    { begin
      (expanded?:boolean <- greater-or-equal expanded-index:integer/space:1 0:literal)
      (break-unless expanded?:boolean)
;?       ($print (("already expanded\n" literal))) ;? 1
      { begin
        ; are we at the expanded row?
        (at-expanded?:boolean <- equal cursor-row:integer/space:1 expanded-index:integer/space:1)
        (break-unless at-expanded?:boolean)
        ; print remaining lines collapsed and return
        (expanded-index:integer/space:1 <- copy -1:literal)
        (expanded-children:integer/space:1 <- copy -1:literal)
        (print-traces-collapsed-from 0:space-address/browser-state screen:terminal-address cursor-row:integer/space:1)
        (clear-rest-of-page 0:space-address/browser-state screen:terminal-address)
        (back-to 0:space-address/browser-state screen:terminal-address original-cursor-row:integer)
        (reply nil:literal)
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
          (print-instruction-trace-collapsed screen:terminal-address tr:instruction-trace-address 0:space-address/browser-state)
          (loop)
        }
        ; fall through
      }
    }
    ; expand original row and print traces below it
    (expanded-index:integer/space:1 <- copy original-trace-index:integer)
    (last-index-on-page:integer/space:1 <- copy original-trace-index:integer)
    (tr:instruction-trace-address <- index traces:instruction-trace-address-array-address/space:1/deref original-trace-index:integer)
    (print-instruction-trace screen:terminal-address tr:instruction-trace-address 0:space-address/browser-state)
    (next-index:integer <- add original-trace-index:integer 1:literal)
;?     ($print (("printing collapsed lines from " literal))) ;? 1
;?     ($print next-index:integer) ;? 2
;?     ($print (("\n" literal))) ;? 2
    (print-traces-collapsed-from 0:space-address/browser-state screen:terminal-address next-index:integer)
    (clear-rest-of-page 0:space-address/browser-state screen:terminal-address)
    (back-to 0:space-address/browser-state screen:terminal-address original-trace-index:integer)
    (reply nil:literal)
  }
  (reply nil:literal)
])

; pagination helpers
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
;?   ($print (("b\n" literal))) ;? 2
  (x:boolean <- less-than expanded-index:integer/space:1 0:literal)
  (jump-if x:boolean easy-case:offset)
  ; easy case: expanded-index lies below top of current page
;?   ($print (("c\n" literal))) ;? 2
  (x:boolean <- greater-than expanded-index:integer/space:1 first-index-on-page:integer/space:1)
  (jump-if x:boolean easy-case:offset)
  ; easy case: expanded-index *starts* at top of current page
;?   ($print (("d\n" literal))) ;? 3
  (top-of-screen-inside-expanded:boolean <- equal expanded-index:integer/space:1 first-index-on-page:integer/space:1)
  (y:boolean <- lesser-or-equal first-subindex-on-page:integer/space:1 -1:literal)
  (y:boolean <- and top-of-screen-inside-expanded:boolean y:boolean)
  (jump-if y:boolean easy-case:offset)
  ; easy case: expanded-index too far up for previous page
;?   ($print (("e\n" literal))) ;? 3
  (delta-to-expanded:integer <- subtract first-index-on-page:integer/space:1 expanded-index:integer/space:1)
;?   ($print (("e2\n" literal))) ;? 2
  (x:boolean <- greater-than delta-to-expanded:integer expanded-index:integer/space:1)
;?   ($print (("e3\n" literal))) ;? 2
  (jump-if x:boolean easy-case:offset)
;?   ($print (("f\n" literal))) ;? 2
  ; tough case
  { begin
    (break-unless top-of-screen-inside-expanded:boolean)
    (previous-page-when-expanded-index-overlaps-top-of-page 0:space-address/browser-state)
    (reply)
  }
  ; tough case
  (previous-page-when-expanded-index-overlaps-previous-page 0:space-address/browser-state delta-to-expanded:integer)
  (reply)
  easy-case
  (first-index-on-page:integer/space:1 <- subtract first-index-on-page:integer/space:1 screen-height:integer/space:1)
  (first-index-on-page:integer/space:1 <- max first-index-on-page:integer/space:1 0:literal)
  (first-subindex-on-page:integer/space:1 <- copy -2:literal)
])

(function previous-page-when-expanded-index-overlaps-top-of-page [
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:browser-state <- next-input)
  (lines-remaining-to-decrement:integer <- copy screen-height:integer/space:1)
  ; if expanded-index will occupy remainder of page, deal with that and return
  { begin
    ; todo: not quite right. not all children are available to scroll past
    (stop-at-expanded?:boolean <- greater-than first-subindex-on-page:integer/space:1 lines-remaining-to-decrement:integer)
    (break-unless stop-at-expanded?:boolean)
    (first-subindex-on-page:integer/space:1 <- subtract first-subindex-on-page:integer/space:1 lines-remaining-to-decrement:integer)
;?     ($print (("after4: " literal))) ;? 2
;?     ($print first-index-on-page:integer/space:1) ;? 2
;?     ($print ((" " literal))) ;? 2
;?     ($print first-subindex-on-page:integer/space:1) ;? 2
;?     ($print (("\n" literal))) ;? 2
    (reply)
  }
  ; if not,
  ; a) scroll past expanded-index
  (first-subindex-on-page:integer/space:1 <- copy -2:literal)
  (lines-remaining-to-decrement:integer <- subtract lines-remaining-to-decrement:integer expanded-children:integer/space:1)
  ; b) scroll past remainder of page
  (first-index-on-page:integer <- subtract first-index-on-page:integer/space:1 lines-remaining-to-decrement:integer)
  (first-index-on-page:integer/space:1 <- max first-index-on-page:integer/space:1 0:literal)
;?   ($print (("after5: " literal))) ;? 2
;?   ($print first-index-on-page:integer/space:1) ;? 2
;?   ($print ((" " literal))) ;? 2
;?   ($print first-subindex-on-page:integer/space:1) ;? 2
;?   ($print (("\n" literal))) ;? 2
])

(function previous-page-when-expanded-index-overlaps-previous-page [
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (0:space-address/names:browser-state <- next-input)
  (delta-to-expanded:integer <- next-input)
  ; a) scroll up until expanded index
  (lines-remaining-to-decrement:integer <- copy screen-height:integer/space:1)
  (first-index-on-page:integer/space:1 <- subtract first-index-on-page:integer/space:1 delta-to-expanded:integer)
  (first-index-on-page:integer/space:1 <- max first-index-on-page:integer/space:1 0:literal)
  (lines-remaining-to-decrement:integer <- subtract lines-remaining-to-decrement:integer delta-to-expanded:integer)
  ; interlude for some sanity checks
  { begin
    (done?:boolean <- lesser-or-equal lines-remaining-to-decrement:integer 0:literal)
    (break-unless done?:boolean)
;?     ($print (("after: " literal))) ;? 2
;?     ($print first-index-on-page:integer/space:1) ;? 2
;?     ($print ((" " literal))) ;? 2
;?     ($print first-subindex-on-page:integer/space:1) ;? 2
;?     ($print (("\n" literal))) ;? 2
    (reply)
  }
  (x:boolean <- equal expanded-index:integer/space:1 first-index-on-page:integer/space:1)
  (assert x:boolean (("delta-to-expanded was incorrect" literal)))
  ; if expanded-index will occupy remainder of page, deal with that and return
  { begin
    ; todo: not quite right. not all children are available to scroll past
    (stop-at-expanded?:boolean <- greater-than expanded-children:integer/space:1 lines-remaining-to-decrement:integer)
    (break-unless stop-at-expanded?:boolean)
    (first-subindex-on-page:integer/space:1 <- subtract expanded-children:integer/space:1 lines-remaining-to-decrement:integer)
;?     ($print (("after2: " literal))) ;? 2
;?     ($print first-index-on-page:integer/space:1) ;? 2
;?     ($print ((" " literal))) ;? 2
;?     ($print first-subindex-on-page:integer/space:1) ;? 2
;?     ($print (("\n" literal))) ;? 2
    (reply)
  }
  ; if not,
  ; b) scroll past expanded-index
  (first-subindex-on-page:integer/space:1 <- copy -2:literal)
  (lines-remaining-to-decrement:integer <- subtract lines-remaining-to-decrement:integer expanded-children:integer/space:1)
  ; c) scroll past remainder of page
  (first-index-on-page:integer <- subtract first-index-on-page:integer/space:1 lines-remaining-to-decrement:integer)
  (first-index-on-page:integer/space:1 <- max first-index-on-page:integer/space:1 0:literal)
;?   ($print (("after3: " literal))) ;? 2
;?   ($print first-index-on-page:integer/space:1) ;? 2
;?   ($print ((" " literal))) ;? 2
;?   ($print first-subindex-on-page:integer/space:1) ;? 2
;?   ($print (("\n" literal))) ;? 2
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
