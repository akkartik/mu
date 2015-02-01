; a simple line editor for reading lisp expressions.
; colors strings and comments. nested parens get different colors.
;
; needs to do its own raw keyboard/screen management since we need to decide
; how to color each key right as it is printed.
; lots of logic devoted to handling backspace correctly.

; abort continuation -> string
(function read-expression [
  (default-space:space-address <- new space:literal 60:literal)
  (abort:continuation <- next-input)
  (history:buffer-address <- next-input)  ; buffer of strings
  (history-length:integer <- get history:buffer-address/deref length:offset)
  (current-history-index:integer <- copy history-length:integer)
  (result:buffer-address <- init-buffer 10:literal)  ; string to maybe add to
  (open-parens:integer <- copy 0:literal)  ; for balancing parens and tracking nesting depth
  ; we can change color when backspacing over parens or comments or strings,
  ; but we need to know that they aren't escaped
  (escapes:buffer-address <- init-buffer 5:literal)
  ; to not return after just a comment
  (not-empty?:boolean <- copy nil:literal)
  { begin
    ; repeatedly read keys from the keyboard
    ;   test: 34<enter>
    (c:character <- $wait-for-key-from-host)
    (done?:boolean <- process-key default-space:space-address c:character)
    (break-if done?:boolean)
    (loop)
  }
  ; trim trailing newline in result (easier history management below)
  { begin
    (l:character <- last result:buffer-address)
    (trailing-newline?:boolean <- equal l:character ((#\newline literal)))
    (break-unless trailing-newline?:boolean)
    (len:integer-address <- get-address result:buffer-address/deref length:offset)
    (len:integer-address/deref <- subtract len:integer-address/deref 1:literal)
  }
  ; test: 3<enter> => size of s is 2
  (s:string-address <- to-array result:buffer-address)
  (reply s:string-address)
])

(function process-key [  ; return t to signal end of expression
  ; must always be called from within 'read-expression'
  (default-space:space-address/names:read-expression <- next-input)
  (c:character <- next-input)
  (len:integer-address <- get-address result:buffer-address/deref length:offset)
;?   ($print 1:literal) ;? 2
  (maybe-cancel-this-expression c:character abort:continuation)
;?   ($print 2:literal) ;? 2
  ; check for ctrl-d and exit
  { begin
    (eof?:boolean <- equal c:character ((ctrl-d literal)))
    (break-unless eof?:boolean)
    ; return empty expression
    (s:string-address-address <- get-address result:buffer-address/deref data:offset)
    (s:string-address-address/deref <- copy nil:literal)
    (reply t:literal)
  }
;?   ($print 3:literal) ;? 2
  ; check for backspace
  ;   test: 3<backspace>4<enter>
  ;   todo: backspace past newline
  { begin
    (backspace?:boolean <- equal c:character ((#\backspace literal)))
    (break-unless backspace?:boolean)
    (print-character-to-host c:character)
    { begin
      ; delete last character if any
      (zero?:boolean <- lesser-or-equal len:integer-address/deref 0:literal)
      (break-if zero?:boolean)
      (len:integer-address/deref <- subtract len:integer-address/deref 1:literal)
      ; switch colors
      ;   test: "a"<backspace>bc"
      ;   test: "a\"<backspace>bc"
      { begin
        (backspaced-over-close-quote?:boolean <- backspaced-over-unescaped? result:buffer-address ((#\" literal)) escapes:buffer-address)  ; "
        (break-unless backspaced-over-close-quote?:boolean)
        (slurp-string result:buffer-address escapes:buffer-address abort:continuation)
        (reply nil:literal)
      }
      ;   test: (+ 1 (<backspace>2)
      ;   test: (+ 1 #\(<backspace><backspace><backspace>2)
      { begin
        (backspaced-over-open-paren?:boolean <- backspaced-over-unescaped? result:buffer-address ((#\( literal)) escapes:buffer-address)
        (break-unless backspaced-over-open-paren?:boolean)
        (open-parens:integer <- subtract open-parens:integer 1:literal)
        (reply nil:literal)
      }
      ;   test: (+ 1 2)<backspace> 3)
      ;   test: (+ 1 2#\)<backspace><backspace><backspace> 3)
      { begin
        (backspaced-over-close-paren?:boolean <- backspaced-over-unescaped? result:buffer-address ((#\) literal)) escapes:buffer-address)
        (break-unless backspaced-over-close-paren?:boolean)
        (open-parens:integer <- add open-parens:integer 1:literal)
        (reply nil:literal)
      }
    }
    (reply nil:literal)
  }
  ; up arrow; switch to previous item in history
  { begin
    (up-arrow?:boolean <- equal c:character ((up literal)))
    (break-unless up-arrow?:boolean)
    ; if history exists
    ;   test: <up><enter>  up without history has no effect
    { begin
      (empty-history?:boolean <- lesser-or-equal history-length:integer 0:literal)
      (break-unless empty-history?:boolean)
      (reply nil:literal)
    }
    ; if pointer not already at start of history
    ;   test: 34<enter><up><up><enter>  up past history has no effect
    { begin
      (at-history-start?:boolean <- lesser-or-equal current-history-index:integer 0:literal)
      (break-unless at-history-start?:boolean)
      (reply nil:literal)
    }
    ; then update history index, copy into current buffer
    ;   test: 34<enter><up><enter>  up restores previous command
    ;   test todo: 34<enter>23<up>34<down><enter>  up doesn't mess up typing on current line
    ;   test todo: 34<enter><up>5<enter><up><up>  commands don't modify history
    ;   test todo: multi-line expressions
    ; then clear line
    { begin
      (done?:boolean <- lesser-or-equal len:integer-address/deref 0:literal)
      (break-if done?:boolean)
      (print-character-to-host ((#\backspace literal)))
      (len:integer-address/deref <- subtract len:integer-address/deref 1:literal)
      (loop)
    }
    ; then clear result and all other state accumulated for the existing expression
    (len:integer-address/deref <- copy 0:literal)
    (open-parens:integer <- copy 0:literal)
    (escapes:buffer-address <- init-buffer 5:literal)
    (not-empty?:boolean <- copy nil:literal)
    ; identify the history item
    (current-history-index:integer <- subtract current-history-index:integer 1:literal)
    (curr-history:string-address <- buffer-index history:buffer-address current-history-index:integer)
    (curr-history-len:integer <- length curr-history:string-address/deref)
;?     ($print curr-history-len:integer) ;? 2
;?     (cursor-to-next-line) ;? 1
;?     ($quit) ;? 1
;?     ($dump-trace "before-retype") ;? 1
    ; and retype it into the current expression
    (i:integer <- copy 0:literal)
    { begin
;?       ($print i:integer) ;? 1
;?       (cursor-to-next-line) ;? 1
      (done?:boolean <- greater-or-equal i:integer curr-history-len:integer)
      (break-if done?:boolean)
;?       ($print i:integer) ;? 1
;?       (cursor-to-next-line) ;? 1
;?       ($dump-trace "retype-iter") ;? 1
;?       ($print (("aaa: " literal))) ;? 1
;?       ($print curr-history:string-address) ;? 1
;?       ($print (("\n" literal))) ;? 1
;?       ($dump-memory) ;? 1
;?       ($start-tracing) ;? 1
      ; no more access to current character
      (c:character <- index curr-history:string-address/deref i:integer)
;?       ($quit) ;? 1
;?       ($dump-trace "retype-iter2") ;? 1
;?       ($print c:character) ;? 1
;?       ($print (("\n" literal))) ;? 1
      ; recursive calls to process-key can clobber any local state except i,
      ; which we won't touch because history strings are guaranteed to only
      ; have printable characters, never <up> or <down>
;?       ($dump-trace "retype-iter8") ;? 1
      (process-key default-space:space-address c:character)
;?       ($dump-trace "retype-iter9") ;? 1
      (i:integer <- add i:integer 1:literal)
      (loop)
    }
;?     ($dump-trace "after-retype") ;? 1
    ; <enter> is trimmed in the history expression, so wait for the human to
    ; hit <enter> again or backspace to make edits
    (reply nil:literal)
  }
  ; if it's a newline, decide whether to return
  ;   test: <enter>34<enter>
  { begin
    (newline?:boolean <- equal c:character ((#\newline literal)))
    (break-unless newline?:boolean)
    (print-character-to-host c:character)
    (at-top-level?:boolean <- lesser-or-equal open-parens:integer 0:literal)
    (end-expression?:boolean <- and at-top-level?:boolean not-empty?:boolean)
    (reply end-expression?:boolean)
  }
;?   ($print 4:literal) ;? 2
  ; printable character; save
;?   ($print (("append\n" literal))) ;? 2
  (result:buffer-address <- append result:buffer-address c:character)
;?   ($print (("done\n" literal))) ;? 2
  ; if it's backslash, read, save and print one additional character
  ;   test: (prn #\()
;?   ($print 5:literal) ;? 2
  { begin
    (backslash?:boolean <- equal c:character ((#\\ literal)))
    (break-unless backslash?:boolean)
    (print-character-to-host c:character 7:literal/white)
    (result:buffer-address escapes:buffer-address <- slurp-escaped-character result:buffer-address 7:literal/white escapes:buffer-address abort:continuation)
    (reply nil:literal)
  }
;?   ($print 6:literal) ;? 2
  ; if it's a semi-colon, parse a comment
  { begin
    (comment?:boolean <- equal c:character ((#\; literal)))
    (break-unless comment?:boolean)
    (print-character-to-host c:character 4:literal/fg/blue)
    (comment-read?:boolean <- slurp-comment result:buffer-address escapes:buffer-address abort:continuation)
    ; return if comment was read (i.e. consumed a newline)
    ; test: ;a<backspace><backspace> (shouldn't end command until <enter>)
    { begin
      (break-if comment-read?:boolean)
      (reply nil:literal)
    }
    ; and we're not within parens
    ;   test: (+ 1 2)  ; comment<enter>
    ;   test: (+ 1<enter>; abc<enter>2)<enter>
    ;   test: ; comment<enter>(+ 1 2)<enter>
    ;   too expensive to build: 3<backspace>; comment<enter>(+ 1 2)<enter>
    (at-top-level?:boolean <- lesser-or-equal open-parens:integer 0:literal)
    (end-expression?:boolean <- and at-top-level?:boolean not-empty?:boolean)
    (reply end-expression?:boolean)
  }
;?   ($print 7:literal) ;? 2
  ; if it's not whitespace, set not-empty? and continue
  { begin
    (space?:boolean <- equal c:character ((#\space literal)))
    (break-if space?:boolean)
    (newline?:boolean <- equal c:character ((#\newline literal)))
    (break-if newline?:boolean)
    (tab?:boolean <- equal c:character ((tab literal)))
    (break-if tab?:boolean)
    (not-empty?:boolean <- copy t:literal)
    ; fall through
  }
;?   ($print 8:literal) ;? 2
  ; if it's a quote, parse a string
  { begin
    (string-started?:boolean <- equal c:character ((#\" literal)))  ; for vim: "
    (break-unless string-started?:boolean)
    (print-character-to-host c:character 6:literal/fg/cyan)
    (slurp-string result:buffer-address escapes:buffer-address abort:continuation)
    (reply nil:literal)
  }
;?   ($print 9:literal) ;? 2
  ; color parens by depth, so they're easy to balance
  ;   test: (+ 1 1)<enter>
  ;   test: (def foo () (+ 1 (* 2 3)))<enter>
  { begin
    (open-paren?:boolean <- equal c:character ((#\( literal)))
    (break-unless open-paren?:boolean)
    (_ color-code:integer <- divide-with-remainder open-parens:integer 3:literal)  ; 3 distinct colors for parens
    (color-code:integer <- add color-code:integer 1:literal)
    (print-character-to-host c:character color-code:integer)
    (open-parens:integer <- add open-parens:integer 1:literal)
;?     ($print open-parens:integer) ;? 2
    (reply nil:literal)
  }
;?   ($print 10:literal) ;? 2
  { begin
    (close-paren?:boolean <- equal c:character ((#\) literal)))
    (break-unless close-paren?:boolean)
    (open-parens:integer <- subtract open-parens:integer 1:literal)
    (_ color-code:integer <- divide-with-remainder open-parens:integer 3:literal)  ; 3 distinct colors for parens
    (color-code:integer <- add color-code:integer 1:literal)
    (print-character-to-host c:character color-code:integer)
;?     ($print open-parens:integer) ;? 2
    (reply nil:literal)
  }
;?   ($print 11:literal) ;? 2
  ; if all else fails, print the character without color
  (print-character-to-host c:character)
  ;   todo: error on space outside parens, like python
  ;   todo: []
  ;   todo: history on up/down
  (reply nil:literal)
])

; list of characters, list of indices of escaped characters, abort continuation
; -> whether a comment was consumed (can also return by backspacing past comment leader ';')
(function slurp-comment [
  (default-space:space-address <- new space:literal 30:literal)
  (in:buffer-address <- next-input)
  (escapes:buffer-address <- next-input)
  (abort:continuation <- next-input)
  ; test: ; abc<enter>
  { begin
    next-key-in-comment
    (c:character <- $wait-for-key-from-host)
    (maybe-cancel-this-expression c:character abort:continuation)  ; test: check needs to come before print
    (print-character-to-host c:character 4:literal/fg/blue)
    ; handle backspace
    ;   test: ; abc<backspace><backspace>def<enter>
    ;   todo: how to exit comment?
    { begin
      (backspace?:boolean <- equal c:character ((#\backspace literal)))
      (break-unless backspace?:boolean)
      (len:integer-address <- get-address in:buffer-address/deref length:offset)
      ; buffer has to have at least the semi-colon so can't be empty
      (len:integer-address/deref <- subtract len:integer-address/deref 1:literal)
      ; if we erase start of comment, return
      (comment-deleted?:boolean <- backspaced-over-unescaped? in:buffer-address ((#\; literal)) escapes:buffer-address)  ; "
      (jump-unless comment-deleted?:boolean next-key-in-comment:offset)
      (reply nil:literal/read-comment?)
    }
    (in:buffer-address <- append in:buffer-address c:character)
    (newline?:boolean <- equal c:character ((#\newline literal)))
    (jump-unless newline?:boolean next-key-in-comment:offset)
  }
  (reply t:literal/read-comment?)
])

(function slurp-string [
  (default-space:space-address <- new space:literal 30:literal)
  (in:buffer-address <- next-input)
  (escapes:buffer-address <- next-input)
  (abort:continuation <- next-input)
  ; test: "abc"
  { begin
    next-key-in-string
    (c:character <- $wait-for-key-from-host)
    (maybe-cancel-this-expression c:character abort:continuation)  ; test: check needs to come before print
    (print-character-to-host c:character 6:literal/fg/cyan)
    ; handle backspace
    ;   test: "abc<backspace>d"
    ;   todo: how to exit string?
    { begin
      (backspace?:boolean <- equal c:character ((#\backspace literal)))
      (break-unless backspace?:boolean)
      (len:integer-address <- get-address in:buffer-address/deref length:offset)
      ; typed a quote before calling slurp-string, so can't be empty
      (len:integer-address/deref <- subtract len:integer-address/deref 1:literal)
      ; if we erase start of string, return
      ;   test: "<backspace>34
      (string-deleted?:boolean <- backspaced-over-unescaped? in:buffer-address ((#\" literal)) escapes:buffer-address)  ; "
;?       ($print string-deleted?:boolean) ;? 1
      (jump-if string-deleted?:boolean end:offset)
      (jump next-key-in-string:offset)
    }
    (in:buffer-address <- append in:buffer-address c:character)
    ; break on quote -- unless escaped by backslash
    ;   test: "abc\"ef"
    { begin
      (backslash?:boolean <- equal c:character ((#\\ literal)))
      (break-unless backslash?:boolean)
      (in:buffer-address escapes:buffer-address <- slurp-escaped-character in:buffer-address 6:literal/cyan escapes:buffer-address abort:continuation)
      (jump next-key-in-string:offset)
    }
    ; if not backslash
    (end-quote?:boolean <- equal c:character ((#\" literal)))  ; for vim: "
    (jump-unless end-quote?:boolean next-key-in-string:offset)
  }
  end
])

; buffer to add character to, color to print it in to the screen, abort continuation
(function slurp-escaped-character [
  (default-space:space-address <- new space:literal 30:literal)
  (in:buffer-address <- next-input)
  (color-code:integer <- next-input)
  (escapes:buffer-address <- next-input)
  (abort:continuation <- next-input)
  (c:character <- $wait-for-key-from-host)
  (maybe-cancel-this-expression c:character abort:continuation)  ; test: check needs to come before print
  (print-character-to-host c:character color-code:integer)
  (len:integer-address <- get-address in:buffer-address/deref length:offset)
  (escapes:buffer-address <- append escapes:buffer-address len:integer-address/deref)
;?   ($print (("+" literal))) ;? 1
  ; handle backspace
  ;   test: "abc\<backspace>def"
  ;   test: #\<backspace>
  { begin
    (backspace?:boolean <- equal c:character ((#\backspace literal)))
    (break-unless backspace?:boolean)
    ; just typed a backslash, so buffer can't be empty
    (len:integer-address/deref <- subtract len:integer-address/deref 1:literal)
    (elen:integer-address <- get-address escapes:buffer-address/deref length:offset)
    (elen:integer-address/deref <- subtract elen:integer-address/deref 1:literal)
;?     ($print (("-" literal))) ;? 1
    (reply in:buffer-address/same-as-arg:0 escapes:buffer-address/same-as-arg:2)
  }
  ; if not backspace, save and return
  (in:buffer-address <- append in:buffer-address c:character)
  (reply in:buffer-address/same-as-arg:0 escapes:buffer-address/same-as-arg:2)
])

(function backspaced-over-unescaped? [
  (default-space:space-address <- new space:literal 30:literal)
  (in:buffer-address <- next-input)
  (expected:character <- next-input)
  (escapes:buffer-address <- next-input)
  ; char just backspaced over matches
  { begin
    (c:character <- past-last in:buffer-address)
    (char-match?:boolean <- equal c:character expected:character)
    (break-if char-match?:boolean)
    (reply nil:literal)
  }
  ; and char before cursor is not an escape
  { begin
    (most-recent-escape:integer <- last escapes:buffer-address)
    (last-idx:integer <- get in:buffer-address/deref length:offset)
;?     ($print most-recent-escape:integer) ;? 1
;?     ($print last-idx:integer) ;? 1
    (was-unescaped?:boolean <- not-equal last-idx:integer most-recent-escape:integer)
    (break-if was-unescaped?:boolean)
    (reply nil:literal)
  }
  (reply t:literal)
])

; return the character past the end of the buffer, if there's room
(function past-last [
  (default-space:space-address <- new space:literal 30:literal)
  (in:buffer-address <- next-input)
  (n:integer <- get in:buffer-address/deref length:offset)
  (s:string-address <- get in:buffer-address/deref data:offset)
  (capacity:integer <- length s:string-address/deref)
  { begin
    (no-space?:boolean <- greater-or-equal n:integer capacity:integer)
    (break-unless no-space?:boolean)
    (reply ((#\null literal)))
  }
  (result:character <- index s:string-address/deref n:integer)
  (reply result:character)
])

(function maybe-cancel-this-expression [
  ; check for ctrl-g and abort
  (default-space:space-address <- new space:literal 30:literal)
  (c:character <- next-input)
  (abort:continuation <- next-input)
  { begin
    (interrupt?:boolean <- equal c:character ((ctrl-g literal)))
    (break-unless interrupt?:boolean)
    (print-character-to-host ((#\^ literal)))
    (print-character-to-host ((#\G literal)))
    (print-character-to-host ((#\newline literal)))
    (continue-from abort:continuation)
  }
])

(function main [
  (default-space:space-address <- new space:literal 30:literal)
  (cursor-mode)
  ($print (("connected to anarki! type in an expression, then hit enter. ctrl-d exits. ctrl-g clears the current expression." literal)))
  (print-character nil:literal/terminal ((#\newline literal)))
  (abort:continuation <- current-continuation)
  (history:buffer-address <- init-buffer 5:literal)  ; buffer of buffers of strings, one per expression typed in
  { begin
    (s:string-address <- read-expression abort:continuation history:buffer-address)
    (break-unless s:string-address)
;?     (x:integer <- length s:string-address/deref) ;? 1
;?     ($print x:integer) ;? 1
;?     ($print ((#\newline literal))) ;? 1
    (history:buffer-address <- append history:buffer-address s:string-address)
;?     (len:integer <- get history:buffer-address/deref length:offset) ;? 1
;?     ($print len:integer) ;? 1
;?     ($print ((#\newline literal))) ;? 1
    (retro-mode)  ; print errors cleanly
;?       (print-string nil:literal/terminal s:string-address) ;? 1
      (t:string-address <- $eval s:string-address)
    (cursor-mode)
    ($print (("=> " literal)))
    (print-string nil:literal/terminal t:string-address)
    (print-character nil:literal/terminal ((#\newline literal)))
    (print-character nil:literal/terminal ((#\newline literal)))  ; empty line separates each expression and result
    (loop)
  }
])
