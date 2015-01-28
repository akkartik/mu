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
  ; test: 34<enter>
  { begin
    next-key
    (c:character <- $wait-for-key-from-host)
    (len:integer-address <- get-address result:buffer-address/deref length:offset)
    ; handle backspace
    ; test: 3<backspace>4<enter>
    ; todo: backspace into comment or string; backspace past newline
    { begin
      (backspace?:boolean <- equal c:character ((#\backspace literal)))
      (break-unless backspace?:boolean)
      ($print-key-to-host c:character)
      ; but only if we need to
      { begin
        (zero?:boolean <- lesser-or-equal len:integer-address/deref 0:literal)
        (break-if zero?:boolean)
        (len:integer-address/deref <- subtract len:integer-address/deref 1:literal)
      }
      (jump next-key:offset)
    }
    (result:buffer-address <- append result:buffer-address c:character)
    ; parse comment
    { begin
      (comment?:boolean <- equal c:character ((#\; literal)))
      (break-unless comment?:boolean)
      ($print-key-to-host c:character 4:literal/fg/blue)
      (skip-comment result:buffer-address)
      ; comment slurps newline, so check if we should return
      (end-sexp?:boolean <- lesser-or-equal open-parens:integer 0:literal)
      (break-if end-sexp?:boolean 2:blocks)
      (jump next-key:offset)
    }
    ; parse string
    { begin
      (string-started?:boolean <- equal c:character ((#\" literal)))  ; for vim: "
      (break-unless string-started?:boolean)
      ($print-key-to-host c:character 6:literal/fg/cyan)
      (slurp-string result:buffer-address)
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

(function skip-comment [
  (default-space:space-address <- new space:literal 30:literal)
  (result:buffer-address <- next-input)
  (orig-len:integer <- get result:buffer-address/deref length:offset)
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
      (len:integer-address <- get-address result:buffer-address/deref length:offset)
      ; buffer has to have at least the semi-colon so can't be empty
      (len:integer-address/deref <- subtract len:integer-address/deref 1:literal)
      ; if we erase start of comment, return
      (comment-deleted?:boolean <- lesser-or-equal len:integer-address/deref orig-len:integer)
      (jump-unless comment-deleted?:boolean end:offset)
      (jump next-key-in-comment:offset)
    }
    (result:buffer-address <- append result:buffer-address c:character)
    (newline?:boolean <- equal c:character ((#\newline literal)))
    (jump-unless newline?:boolean next-key-in-comment:offset)
  }
  end
])

(function slurp-string [
  (default-space:space-address <- new space:literal 30:literal)
  (result:buffer-address <- next-input)
  (orig-len:integer <- get result:buffer-address/deref length:offset)
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
      (len:integer-address <- get-address result:buffer-address/deref length:offset)
      ; typed a quote before calling slurp-string, so can't be empty
      (len:integer-address/deref <- subtract len:integer-address/deref 1:literal)
      ; if we erase start of string, return
      ; test: "<backspace>34
      (string-deleted?:boolean <- lesser-or-equal len:integer-address/deref orig-len:integer)
      (jump-unless string-deleted?:boolean end:offset)
      (jump next-key-in-string:offset)
    }
    (result:buffer-address <- append result:buffer-address c:character)
    ; break on quote -- unless escaped by backslash
    ; test: "abc\"ef"
    { begin
      (backslash?:boolean <- equal c:character ((#\\ literal)))
      (break-unless backslash?:boolean)
      ; slurp an extra key
      { begin
        (c2:character <- $wait-for-key-from-host)
        ($print-key-to-host c2:character 6:literal/fg/cyan)
        ; handle backspace
        ; test: "abc\<backspace>def"
        { begin
          (backspace?:boolean <- equal c2:character ((#\backspace literal)))
          (break-unless backspace?:boolean)
          (len:integer-address <- get-address result:buffer-address/deref length:offset)
          ; just typed a backslash, so buffer can't be empty
          (len:integer-address/deref <- subtract len:integer-address/deref 1:literal)
          (jump next-key-in-string:offset)
        }
        ; if not backspace
        (result:buffer-address <- append result:buffer-address c2:character)
      }
      (jump next-key-in-string:offset)
    }
    ; if not backslash
    (end-quote?:boolean <- equal c:character ((#\" literal)))  ; for vim: "
    (jump-unless end-quote?:boolean next-key-in-string:offset)
  }
  end
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
