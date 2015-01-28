; a simple line editor for reading lisp s-expressions
; colors strings and comments. nested parens get different colors.
;
; needs to do its own raw keyboard/screen management since we need to decide
; how to color each key right as it is printed
; lots of logic devoted to handling backspace correctly

(function read-sexp [
  (default-space:space-address <- new space:literal 30:literal)
  (result:buffer-address <- init-buffer 30:literal)
  (open-parens:integer <- copy 0:literal)  ; for balancing parens and tracking nesting depth
  ; we can change color when backspacing over parens or comments or strings,
  ; but we need to know that they aren't escaped
  (escapes:integer-buffer-address <- init-integer-buffer 5:literal)
  ; test: 34<enter>
  { begin
    next-key
    (c:character <- $wait-for-key-from-host)
    (len:integer-address <- get-address result:buffer-address/deref length:offset)
    ; handle backspace
    ; test: 3<backspace>4<enter>
    ; todo: backspace past newline
    { begin
      (backspace?:boolean <- equal c:character ((#\backspace literal)))
      (break-unless backspace?:boolean)
      ($print-key-to-host c:character)
      ; but only if we need to
      { begin
        (zero?:boolean <- lesser-or-equal len:integer-address/deref 0:literal)
        (break-if zero?:boolean)
        (len:integer-address/deref <- subtract len:integer-address/deref 1:literal)
        ; test: "a"<backspace>bc"
        ; test: "a\"<backspace>bc"
        { begin
          (backspaced-over-close-quote?:boolean <- backspaced-over-unescaped? result:buffer-address ((#\" literal)) escapes:integer-buffer-address)  ; "
          (break-unless backspaced-over-close-quote?:boolean)
          (slurp-string result:buffer-address escapes:integer-buffer-address)
          (jump next-key:offset)
        }
        ; test: (+ 1 (<backspace>2)
        ; test: (+ 1 #\(<backspace><backspace><backspace>2)
        { begin
          (backspaced-over-open-paren?:boolean <- backspaced-over-unescaped? result:buffer-address ((#\( literal)) escapes:integer-buffer-address)
          (break-unless backspaced-over-open-paren?:boolean)
          (open-parens:integer <- subtract open-parens:integer 1:literal)
          (jump next-key:offset)
        }
        ; test: (+ 1 2)<backspace> 3)
        ; test: (+ 1 2#\)<backspace><backspace><backspace> 3)
        { begin
          (backspaced-over-close-paren?:boolean <- backspaced-over-unescaped? result:buffer-address ((#\) literal)) escapes:integer-buffer-address)
          (break-unless backspaced-over-close-paren?:boolean)
          (open-parens:integer <- add open-parens:integer 1:literal)
          (jump next-key:offset)
        }
      }
      (jump next-key:offset)
    }
    (result:buffer-address <- append result:buffer-address c:character)
    ; record backslash and one additional character
    ; test: (prn #\()
    { begin
      (backslash?:boolean <- equal c:character ((#\\ literal)))
      (break-unless backslash?:boolean)
      ($print-key-to-host c:character 7:literal/white)
      (result:buffer-address escapes:integer-buffer-address <- slurp-escaped-character result:buffer-address 7:literal/white escapes:integer-buffer-address)
      (jump next-key:offset)
    }
    ; parse comment
    { begin
      (comment?:boolean <- equal c:character ((#\; literal)))
      (break-unless comment?:boolean)
      ($print-key-to-host c:character 4:literal/fg/blue)
      (comment-read?:boolean <- slurp-comment result:buffer-address escapes:integer-buffer-address)
      ; return if comment was read (i.e. consumed a newline)
      ; test: ;a<backspace><backspace> (shouldn't end command until <enter>)
      (jump-unless comment-read?:boolean next-key:offset)
      ; and we're not within parens
      (end-sexp?:boolean <- lesser-or-equal open-parens:integer 0:literal)
      (jump-unless end-sexp?:boolean next-key:offset)
      (jump end:offset)
    }
    ; parse string
    { begin
      (string-started?:boolean <- equal c:character ((#\" literal)))  ; for vim: "
      (break-unless string-started?:boolean)
      ($print-key-to-host c:character 6:literal/fg/cyan)
      (slurp-string result:buffer-address escapes:integer-buffer-address)
      (jump next-key:offset)
    }
    ; balance parens
    ; test: (+ 1 1)<enter>
    ; test: (def foo () (+ 1 (* 2 3)))<enter>
    { begin
      (open-paren?:boolean <- equal c:character ((#\( literal)))
      (break-unless open-paren?:boolean)
      (_ color-code:integer <- divide-with-remainder open-parens:integer 3:literal)
      (color-code:integer <- add color-code:integer 1:literal)
      ($print-key-to-host c:character color-code:integer)
      (open-parens:integer <- add open-parens:integer 1:literal)
      (jump next-key:offset)
    }
    { begin
      (close-paren?:boolean <- equal c:character ((#\) literal)))
      (break-unless close-paren?:boolean)
      (open-parens:integer <- subtract open-parens:integer 1:literal)
      (_ color-code:integer <- divide-with-remainder open-parens:integer 3:literal)  ; 3 distinct colors for parens
      (color-code:integer <- add color-code:integer 1:literal)
      ($print-key-to-host c:character color-code:integer)
      (jump next-key:offset)
    }
    { begin
      (newline?:boolean <- equal c:character ((#\newline literal)))
      (break-unless newline?:boolean)
      ($print-key-to-host c:character)
      (end-sexp?:boolean <- lesser-or-equal open-parens:integer 0:literal)
      (jump-if end-sexp?:boolean end:offset)
      (jump next-key:offset)
    }
    ($print-key-to-host c:character)
    ; todo: error on space outside parens, like python
    ; []
    ; don't return if there's no non-whitespace in result
    (jump next-key:offset)
  }
  end
  (s:string-address <- get result:buffer-address/deref data:offset)
  (reply s:string-address)
])

; list of characters => whether a comment was consumed (can also return by backspacing past comment leader ';')
(function slurp-comment [
  (default-space:space-address <- new space:literal 30:literal)
  (in:buffer-address <- next-input)
  (escapes:integer-buffer-address <- next-input)
  ; test: ; abc<enter>
  { begin
    next-key-in-comment
    (c:character <- $wait-for-key-from-host)
    ($print-key-to-host c:character 4:literal/fg/blue)
    ; handle backspace
    ; test: ; abc<backspace><backspace>def<enter>
    ; todo: how to exit comment?
    { begin
      (backspace?:boolean <- equal c:character ((#\backspace literal)))
      (break-unless backspace?:boolean)
      (len:integer-address <- get-address in:buffer-address/deref length:offset)
      ; buffer has to have at least the semi-colon so can't be empty
      (len:integer-address/deref <- subtract len:integer-address/deref 1:literal)
      ; if we erase start of comment, return
      (comment-deleted?:boolean <- backspaced-over-unescaped? in:buffer-address ((#\; literal)) escapes:integer-buffer-address)  ; "
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
  (escapes:integer-buffer-address <- next-input)
  ; test: "abc"
  { begin
    next-key-in-string
    (c:character <- $wait-for-key-from-host)
    ($print-key-to-host c:character 6:literal/fg/cyan)
    ; handle backspace
    ; test: "abc<backspace>d"
    ; todo: how to exit string?
    { begin
      (backspace?:boolean <- equal c:character ((#\backspace literal)))
      (break-unless backspace?:boolean)
      (len:integer-address <- get-address in:buffer-address/deref length:offset)
      ; typed a quote before calling slurp-string, so can't be empty
      (len:integer-address/deref <- subtract len:integer-address/deref 1:literal)
      ; if we erase start of string, return
      ; test: "<backspace>34
      (string-deleted?:boolean <- backspaced-over-unescaped? in:buffer-address ((#\" literal)) escapes:integer-buffer-address)  ; "
;?       (print-primitive-to-host string-deleted?:boolean) ;? 1
      (jump-if string-deleted?:boolean end:offset)
      (jump next-key-in-string:offset)
    }
    (in:buffer-address <- append in:buffer-address c:character)
    ; break on quote -- unless escaped by backslash
    ; test: "abc\"ef"
    { begin
      (backslash?:boolean <- equal c:character ((#\\ literal)))
      (break-unless backslash?:boolean)
      (in:buffer-address escapes:integer-buffer-address <- slurp-escaped-character in:buffer-address 6:literal/cyan escapes:integer-buffer-address)
      (jump next-key-in-string:offset)
    }
    ; if not backslash
    (end-quote?:boolean <- equal c:character ((#\" literal)))  ; for vim: "
    (jump-unless end-quote?:boolean next-key-in-string:offset)
  }
  end
])

(function slurp-escaped-character [
  (default-space:space-address <- new space:literal 30:literal)
  (in:buffer-address <- next-input)
  (color-code:integer <- next-input)
  (c2:character <- $wait-for-key-from-host)
  ($print-key-to-host c2:character color-code:integer)
  (escapes:integer-buffer-address <- next-input)
  (len:integer-address <- get-address in:buffer-address/deref length:offset)
  (escapes:integer-buffer-address <- append escapes:integer-buffer-address len:integer-address/deref)  ; todo: type violation
;?   (print-primitive-to-host (("+" literal))) ;? 1
  ; handle backspace
  ; test: "abc\<backspace>def"
  ; test: #\<backspace>
  { begin
    (backspace?:boolean <- equal c2:character ((#\backspace literal)))
    (break-unless backspace?:boolean)
    ; just typed a backslash, so buffer can't be empty
    (len:integer-address/deref <- subtract len:integer-address/deref 1:literal)
    (elen:integer-address <- get-address escapes:integer-buffer-address/deref length:offset)
    (elen:integer-address/deref <- subtract elen:integer-address/deref 1:literal)
;?     (print-primitive-to-host (("-" literal))) ;? 1
    (reply in:buffer-address/same-as-arg:0 escapes:integer-buffer-address/same-as-arg:2)
  }
  ; if not backspace
  (in:buffer-address <- append in:buffer-address c2:character)
  (reply in:buffer-address/same-as-arg:0 escapes:integer-buffer-address/same-as-arg:2)
])

(function backspaced-over-unescaped? [
  (default-space:space-address <- new space:literal 30:literal)
  (in:buffer-address <- next-input)
  (expected:character <- next-input)
  (escapes:integer-buffer-address <- next-input)
  ; char just backspaced over matches
  { begin
    (c:character <- past-last in:buffer-address)
    (char-match?:boolean <- equal c:character expected:character)
    (break-if char-match?:boolean)
    (reply nil:literal)
  }
  ; and char before cursor is not an escape
  { begin
    (most-recent-escape:integer <- last escapes:integer-buffer-address)
    (last-idx:integer <- get in:buffer-address/deref length:offset)
;?     (print-primitive-to-host most-recent-escape:integer) ;? 1
;?     (print-primitive-to-host last-idx:integer) ;? 1
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

(function main [
  (default-space:space-address <- new space:literal 30:literal)
  (cursor-mode)
  { begin
    (print-primitive-to-host (("anarki> " literal)))
    (s:string-address <- read-sexp)
    (retro-mode)  ; print errors cleanly
    (t:string-address <- $eval s:string-address)
    (cursor-mode)
    (print-string nil:literal/terminal t:string-address)
    (print-character nil:literal/terminal ((#\newline literal)))
    (loop)
  }
])
