; a simple line editor for reading lisp s-expressions

(function read-sexp [
  (default-space:space-address <- new space:literal 30:literal)
  (in:channel-address <- next-input)
  (result:buffer-address <- init-buffer 30:literal)
  (open-parens:integer <- copy 0:literal)
  { begin
;?     (skip-whitespace k:keyboard-address) ;? 1
    (x:tagged-value in:channel-address/deref <- read in:channel-address)
    (c:character <- maybe-coerce x:tagged-value character:literal)
    (assert c:character "read-sexp: non-character in stdin")
;?     (print-primitive-to-host (("key: " literal))) ;? 1
;?     (print-primitive-to-host c:character) ;? 2
;?     (print-primitive-to-host (("$\n" literal))) ;? 2
    (result:buffer-address <- append result:buffer-address c:character)
    ; parse comment
    { begin
      (comment?:boolean <- equal c:character ((#\; literal)))
      (break-unless comment?:boolean)
      (skip-comment in:channel-address)
      ; comment slurps newline, so check if we should return
      (end-sexp?:boolean <- lesser-or-equal open-parens:integer 0:literal)
      (break-if end-sexp?:boolean 2:blocks)
    }
    ; parse string
    { begin
      (string-started?:boolean <- equal c:character ((#\" literal)))  ; for vim: "
      (break-unless string-started?:boolean)
      (slurp-string in:channel-address result:buffer-address)
    }
    ; balance parens
    { begin
      (open-paren?:boolean <- equal c:character ((#\( literal)))
      (break-unless open-paren?:boolean)
      (open-parens:integer <- add open-parens:integer 1:literal)
    }
    { begin
      (close-paren?:boolean <- equal c:character ((#\) literal)))
      (break-unless close-paren?:boolean)
      (open-parens:integer <- subtract open-parens:integer 1:literal)
    }
    { begin
      (newline?:boolean <- equal c:character ((#\newline literal)))
      (break-unless newline?:boolean)
;?       (print-primitive-to-host (("AAA" literal))) ;? 1
      (end-sexp?:boolean <- lesser-or-equal open-parens:integer 0:literal)
      (break-if end-sexp?:boolean 2:blocks)
    }
    ; todo: error on space outside parens, like python
    ; []
    ; don't return if there's no non-whitespace in result
    (loop)
  }
;?   (print-primitive-to-host (("BAA" literal))) ;? 1
  (s:string-address <- get result:buffer-address/deref data:offset)
  (reply s:string-address)
])

(function skip-comment [
  (default-space:space-address <- new space:literal 30:literal)
  (in:channel-address <- next-input)
  { begin
    (x:tagged-value in:channel-address/deref <- read in:channel-address)
    (c:character <- maybe-coerce x:tagged-value character:literal)
    (assert c:character "read-sexp: non-character in stdin")
    (newline?:boolean <- equal c:character ((#\newline literal)))
    (break-if newline?:boolean)
    (loop)
  }
])

(function slurp-string [
  (default-space:space-address <- new space:literal 30:literal)
  (in:channel-address <- next-input)
  (result:buffer-address <- next-input)
  { begin
    (x:tagged-value in:channel-address/deref <- read in:channel-address)
    (c:character <- maybe-coerce x:tagged-value character:literal)
    (assert c:character "read-sexp: non-character in stdin")
    (result:buffer-address <- append result:buffer-address c:character)
    (end-quote?:boolean <- equal c:character ((#\" literal)))  ; for vim: "
    (break-if end-quote?:boolean)
    (loop)
  }
])

(function main [
  (default-space:space-address <- new space:literal 30:literal)
  (cursor-mode)
  (stdin:channel-address <- init-channel 1:literal)
  (fork-helper send-keys-to-stdin:fn nil:literal/globals nil:literal/limit nil:literal/keyboard stdin:channel-address)
  (buffered-stdin:channel-address <- init-channel 1:literal)
  (fork-helper buffer-stdin:fn nil:literal/globals nil:literal/limit stdin:channel-address buffered-stdin:channel-address)
  { begin
    (print-primitive-to-host (("anarki> " literal)))
    (s:string-address <- read-sexp buffered-stdin:channel-address)
    (retro-mode)  ; print errors cleanly
    (t:string-address <- $eval s:string-address)
    (cursor-mode)
    (print-string nil:literal/terminal t:string-address)
    (print-character nil:literal/terminal ((#\newline literal)))
    (loop)
  }
])
