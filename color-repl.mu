; a simple line editor for reading lisp s-expressions

(function read-sexp [
  (default-space:space-address <- new space:literal 30:literal)
  (result:buffer-address <- init-buffer 30:literal)
  (open-parens:integer <- copy 0:literal)
  { begin
    (c:character <- $wait-for-key-from-host)
    ; handle backspace
    ; todo: backspace into comment or string
    { begin
      (backspace?:boolean <- equal c:character ((#\backspace literal)))
      (break-unless backspace?:boolean)
      ($print-key-to-host c:character)
      (len:integer-address <- get-address result:buffer-address/deref length:offset)
      ; but only if we need to
      { begin
        (zero?:boolean <- lesser-or-equal len:integer-address/deref 0:literal)
        (break-if zero?:boolean)
        (len:integer-address/deref <- subtract len:integer-address/deref 1:literal)
      }
      (loop 2:blocks)
    }
    (result:buffer-address <- append result:buffer-address c:character)
    ; parse comment
    { begin
      (comment?:boolean <- equal c:character ((#\; literal)))
      (break-unless comment?:boolean)
      ($print-key-to-host c:character 4:literal/fg/blue)
      (skip-comment)
      ; comment slurps newline, so check if we should return
      (end-sexp?:boolean <- lesser-or-equal open-parens:integer 0:literal)
      (break-if end-sexp?:boolean 2:blocks)
      (loop 2:blocks)
    }
    ; parse string
    { begin
      (string-started?:boolean <- equal c:character ((#\" literal)))  ; for vim: "
      (break-unless string-started?:boolean)
      ($print-key-to-host c:character 6:literal/fg/cyan)
      (slurp-string result:buffer-address)
      (loop 2:blocks)
    }
    ; balance parens
    { begin
      (open-paren?:boolean <- equal c:character ((#\( literal)))
      (break-unless open-paren?:boolean)
      (_ color-code:integer <- divide-with-remainder open-parens:integer 3:literal)
      (color-code:integer <- add color-code:integer 1:literal)
      ($print-key-to-host c:character color-code:integer)
      (open-parens:integer <- add open-parens:integer 1:literal)
      (loop 2:blocks)
    }
    { begin
      (close-paren?:boolean <- equal c:character ((#\) literal)))
      (break-unless close-paren?:boolean)
      (open-parens:integer <- subtract open-parens:integer 1:literal)
      (_ color-code:integer <- divide-with-remainder open-parens:integer 3:literal)
      (color-code:integer <- add color-code:integer 1:literal)
      ($print-key-to-host c:character color-code:integer)
      (loop 2:blocks)
    }
    { begin
      (newline?:boolean <- equal c:character ((#\newline literal)))
      (break-unless newline?:boolean)
      ($print-key-to-host c:character)
      (end-sexp?:boolean <- lesser-or-equal open-parens:integer 0:literal)
      (break-if end-sexp?:boolean 2:blocks)
      (loop 2:blocks)
    }
    ($print-key-to-host c:character)
    ; todo: error on space outside parens, like python
    ; []
    ; don't return if there's no non-whitespace in result
    (loop)
  }
  (s:string-address <- get result:buffer-address/deref data:offset)
  (reply s:string-address)
])

(function skip-comment [
  (default-space:space-address <- new space:literal 30:literal)
  { begin
    (c:character <- $wait-for-key-from-host)
    ($print-key-to-host c:character 4:literal/fg/blue)
    ; handle backspace
    ; todo: how to exit comment?
    { begin
      (backspace?:boolean <- equal c:character ((#\backspace literal)))
      (break-unless backspace?:boolean)
      (len:integer-address <- get-address result:buffer-address/deref length:offset)
      ; but only if we need to
      { begin
        (zero?:boolean <- lesser-or-equal len:integer-address/deref 0:literal)
        (break-if zero?:boolean)
        (len:integer-address/deref <- subtract len:integer-address/deref 1:literal)
      }
      (loop 2:blocks)
    }
    (newline?:boolean <- equal c:character ((#\newline literal)))
    (break-if newline?:boolean)
    (loop)
  }
])

(function slurp-string [
  (default-space:space-address <- new space:literal 30:literal)
  (result:buffer-address <- next-input)
  { begin
    (c:character <- $wait-for-key-from-host)
    ($print-key-to-host c:character 6:literal/fg/cyan)
    ; handle backspace
    ; todo: how to exit string?
    { begin
      (backspace?:boolean <- equal c:character ((#\backspace literal)))
      (break-unless backspace?:boolean)
      (len:integer-address <- get-address result:buffer-address/deref length:offset)
      ; but only if we need to
      { begin
        (zero?:boolean <- lesser-or-equal len:integer-address/deref 0:literal)
        (break-if zero?:boolean)
        (len:integer-address/deref <- subtract len:integer-address/deref 1:literal)
      }
      (loop 2:blocks)
    }
    (result:buffer-address <- append result:buffer-address c:character)
    (end-quote?:boolean <- equal c:character ((#\" literal)))  ; for vim: "
    (break-if end-quote?:boolean)
    (loop)
  }
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
