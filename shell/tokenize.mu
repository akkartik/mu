# The language is indent-sensitive.
# Each line consists of an initial indent token followed by other tokens.
type token {
  type: int
  # type 0: default
  # type 1: stream
  text-data: (handle stream byte)
  # type 2: skip (end of line or end of file)
  # type 3: indent
  number-data: int
}

fn tokenize in: (addr gap-buffer), out: (addr stream token), trace: (addr trace) {
  trace-text trace, "tokenize", "tokenize"
  trace-lower trace
  rewind-gap-buffer in
  var at-start-of-line?/edi: boolean <- copy 1/true
  {
    var done?/eax: boolean <- gap-buffer-scan-done? in
    compare done?, 0/false
    break-if-!=
    #
    var token-storage: token
    var token/edx: (addr token) <- address token-storage
    at-start-of-line? <- next-token in, token, at-start-of-line?, trace
    var error?/eax: boolean <- has-errors? trace
    compare error?, 0/false
    {
      break-if-=
      return
    }
    var skip?/eax: boolean <- skip-token? token
    compare skip?, 0/false
    loop-if-!=
    write-to-stream out, token  # shallow-copy text-data
    loop
  }
  trace-higher trace
}

fn test-tokenize-number {
  var in-storage: gap-buffer
  var in/esi: (addr gap-buffer) <- address in-storage
  initialize-gap-buffer-with in, "123 a"
  #
  var stream-storage: (stream token 0x10)
  var stream/edi: (addr stream token) <- address stream-storage
  #
  var trace-storage: trace
  var trace/edx: (addr trace) <- address trace-storage
  initialize-trace trace, 1/only-errors, 0x10/capacity, 0/visible
  tokenize in, stream, trace
  #
  var curr-token-storage: token
  var curr-token/ebx: (addr token) <- address curr-token-storage
  read-from-stream stream, curr-token
  var curr-token-type/eax: (addr int) <- get curr-token, type
  check-ints-equal *curr-token-type, 3/indent, "F - test-tokenize-number/before-indent-type"
  var curr-token-data/eax: (addr int) <- get curr-token, number-data
  check-ints-equal *curr-token-data, 0/spaces, "F - test-tokenize-number/before-indent"
  read-from-stream stream, curr-token
  var number?/eax: boolean <- number-token? curr-token
  check number?, "F - test-tokenize-number"
  var curr-token-data-ah/eax: (addr handle stream byte) <- get curr-token, text-data
  var curr-token-data/eax: (addr stream byte) <- lookup *curr-token-data-ah
  check-stream-equal curr-token-data, "123", "F - test-tokenize-number: value"
}

fn test-tokenize-negative-number {
  var in-storage: gap-buffer
  var in/esi: (addr gap-buffer) <- address in-storage
  initialize-gap-buffer-with in, "-123 a"
  #
  var stream-storage: (stream token 0x10)
  var stream/edi: (addr stream token) <- address stream-storage
  #
  var trace-storage: trace
  var trace/edx: (addr trace) <- address trace-storage
  initialize-trace trace, 1/only-errors, 0x10/capacity, 0/visible
  tokenize in, stream, trace
  #
  var curr-token-storage: token
  var curr-token/ebx: (addr token) <- address curr-token-storage
  read-from-stream stream, curr-token
  var curr-token-type/eax: (addr int) <- get curr-token, type
  check-ints-equal *curr-token-type, 3/indent, "F - test-tokenize-negative-number/before-indent-type"
  var curr-token-data/eax: (addr int) <- get curr-token, number-data
  check-ints-equal *curr-token-data, 0/spaces, "F - test-tokenize-negative-number/before-indent"
  read-from-stream stream, curr-token
  var number?/eax: boolean <- number-token? curr-token
  check number?, "F - test-tokenize-negative-number"
  var curr-token-data-ah/eax: (addr handle stream byte) <- get curr-token, text-data
  var curr-token-data/eax: (addr stream byte) <- lookup *curr-token-data-ah
  check-stream-equal curr-token-data, "-123", "F - test-tokenize-negative-number: value"
}

fn test-tokenize-quote {
  var in-storage: gap-buffer
  var in/esi: (addr gap-buffer) <- address in-storage
  initialize-gap-buffer-with in, "'(a)"
  #
  var stream-storage: (stream token 0x10)
  var stream/edi: (addr stream token) <- address stream-storage
  #
  var trace-storage: trace
  var trace/edx: (addr trace) <- address trace-storage
  initialize-trace trace, 1/only-errors, 0x10/capacity, 0/visible
  tokenize in, stream, trace
  #
  var curr-token-storage: token
  var curr-token/ebx: (addr token) <- address curr-token-storage
  read-from-stream stream, curr-token
  var curr-token-type/eax: (addr int) <- get curr-token, type
  check-ints-equal *curr-token-type, 3/indent, "F - test-tokenize-quote/before-indent-type"
  var curr-token-data/eax: (addr int) <- get curr-token, number-data
  check-ints-equal *curr-token-data, 0/spaces, "F - test-tokenize-quote/before-indent"
  read-from-stream stream, curr-token
  var quote?/eax: boolean <- quote-token? curr-token
  check quote?, "F - test-tokenize-quote: quote"
  read-from-stream stream, curr-token
  var open-paren?/eax: boolean <- open-paren-token? curr-token
  check open-paren?, "F - test-tokenize-quote: open paren"
  read-from-stream stream, curr-token  # skip a
  read-from-stream stream, curr-token
  var close-paren?/eax: boolean <- close-paren-token? curr-token
  check close-paren?, "F - test-tokenize-quote: close paren"
}

fn test-tokenize-backquote {
  var in-storage: gap-buffer
  var in/esi: (addr gap-buffer) <- address in-storage
  initialize-gap-buffer-with in, "`(a)"
  #
  var stream-storage: (stream token 0x10)
  var stream/edi: (addr stream token) <- address stream-storage
  #
  var trace-storage: trace
  var trace/edx: (addr trace) <- address trace-storage
  initialize-trace trace, 1/only-errors, 0x10/capacity, 0/visible
  tokenize in, stream, trace
  #
  var curr-token-storage: token
  var curr-token/ebx: (addr token) <- address curr-token-storage
  read-from-stream stream, curr-token
  var curr-token-type/eax: (addr int) <- get curr-token, type
  check-ints-equal *curr-token-type, 3/indent, "F - test-tokenize-backquote/before-indent-type"
  var curr-token-data/eax: (addr int) <- get curr-token, number-data
  check-ints-equal *curr-token-data, 0/spaces, "F - test-tokenize-backquote/before-indent"
  read-from-stream stream, curr-token
  var backquote?/eax: boolean <- backquote-token? curr-token
  check backquote?, "F - test-tokenize-backquote: backquote"
  read-from-stream stream, curr-token
  var open-paren?/eax: boolean <- open-paren-token? curr-token
  check open-paren?, "F - test-tokenize-backquote: open paren"
  read-from-stream stream, curr-token  # skip a
  read-from-stream stream, curr-token
  var close-paren?/eax: boolean <- close-paren-token? curr-token
  check close-paren?, "F - test-tokenize-backquote: close paren"
}

fn test-tokenize-unquote {
  var in-storage: gap-buffer
  var in/esi: (addr gap-buffer) <- address in-storage
  initialize-gap-buffer-with in, ",(a)"
  #
  var stream-storage: (stream token 0x10)
  var stream/edi: (addr stream token) <- address stream-storage
  #
  var trace-storage: trace
  var trace/edx: (addr trace) <- address trace-storage
  initialize-trace trace, 1/only-errors, 0x10/capacity, 0/visible
  tokenize in, stream, trace
  #
  var curr-token-storage: token
  var curr-token/ebx: (addr token) <- address curr-token-storage
  read-from-stream stream, curr-token
  var curr-token-type/eax: (addr int) <- get curr-token, type
  check-ints-equal *curr-token-type, 3/indent, "F - test-tokenize-unquote/before-indent-type"
  var curr-token-data/eax: (addr int) <- get curr-token, number-data
  check-ints-equal *curr-token-data, 0/spaces, "F - test-tokenize-unquote/before-indent"
  read-from-stream stream, curr-token
  var unquote?/eax: boolean <- unquote-token? curr-token
  check unquote?, "F - test-tokenize-unquote: unquote"
  read-from-stream stream, curr-token
  var open-paren?/eax: boolean <- open-paren-token? curr-token
  check open-paren?, "F - test-tokenize-unquote: open paren"
  read-from-stream stream, curr-token  # skip a
  read-from-stream stream, curr-token
  var close-paren?/eax: boolean <- close-paren-token? curr-token
  check close-paren?, "F - test-tokenize-unquote: close paren"
}

fn test-tokenize-unquote-splice {
  var in-storage: gap-buffer
  var in/esi: (addr gap-buffer) <- address in-storage
  initialize-gap-buffer-with in, ",@a"
  #
  var stream-storage: (stream token 0x10)
  var stream/edi: (addr stream token) <- address stream-storage
  #
  var trace-storage: trace
  var trace/edx: (addr trace) <- address trace-storage
  initialize-trace trace, 1/only-errors, 0x10/capacity, 0/visible
  tokenize in, stream, trace
  #
  var curr-token-storage: token
  var curr-token/ebx: (addr token) <- address curr-token-storage
  read-from-stream stream, curr-token
  var curr-token-type/eax: (addr int) <- get curr-token, type
  check-ints-equal *curr-token-type, 3/indent, "F - test-tokenize-unquote-splice/before-indent-type"
  var curr-token-data/eax: (addr int) <- get curr-token, number-data
  check-ints-equal *curr-token-data, 0/spaces, "F - test-tokenize-unquote-splice/before-indent"
  read-from-stream stream, curr-token
  var unquote-splice?/eax: boolean <- unquote-splice-token? curr-token
  check unquote-splice?, "F - test-tokenize-unquote-splice: unquote-splice"
}

fn test-tokenize-dotted-list {
  var in-storage: gap-buffer
  var in/esi: (addr gap-buffer) <- address in-storage
  initialize-gap-buffer-with in, "(a . b)"
  #
  var stream-storage: (stream token 0x10)
  var stream/edi: (addr stream token) <- address stream-storage
  #
  var trace-storage: trace
  var trace/edx: (addr trace) <- address trace-storage
  initialize-trace trace, 1/only-errors, 0x10/capacity, 0/visible
  tokenize in, stream, trace
  #
  var curr-token-storage: token
  var curr-token/ebx: (addr token) <- address curr-token-storage
  read-from-stream stream, curr-token
  var curr-token-type/eax: (addr int) <- get curr-token, type
  check-ints-equal *curr-token-type, 3/indent, "F - test-tokenize-dotted-list/before-indent-type"
  var curr-token-data/eax: (addr int) <- get curr-token, number-data
  check-ints-equal *curr-token-data, 0/spaces, "F - test-tokenize-dotted-list/before-indent"
  read-from-stream stream, curr-token
  var open-paren?/eax: boolean <- open-paren-token? curr-token
  check open-paren?, "F - test-tokenize-dotted-list: open paren"
  read-from-stream stream, curr-token  # skip a
  read-from-stream stream, curr-token
  var dot?/eax: boolean <- dot-token? curr-token
  check dot?, "F - test-tokenize-dotted-list: dot"
  read-from-stream stream, curr-token  # skip b
  read-from-stream stream, curr-token
  var close-paren?/eax: boolean <- close-paren-token? curr-token
  check close-paren?, "F - test-tokenize-dotted-list: close paren"
}

fn test-tokenize-stream-literal {
  var in-storage: gap-buffer
  var in/esi: (addr gap-buffer) <- address in-storage
  initialize-gap-buffer-with in, "[abc def]"
  #
  var stream-storage: (stream token 0x10)
  var stream/edi: (addr stream token) <- address stream-storage
  #
  var trace-storage: trace
  var trace/edx: (addr trace) <- address trace-storage
  initialize-trace trace, 1/only-errors, 0x10/capacity, 0/visible
  tokenize in, stream, trace
  #
  var curr-token-storage: token
  var curr-token/ebx: (addr token) <- address curr-token-storage
  read-from-stream stream, curr-token
  var curr-token-type/eax: (addr int) <- get curr-token, type
  check-ints-equal *curr-token-type, 3/indent, "F - test-tokenize-stream-literal/before-indent-type"
  var curr-token-data/eax: (addr int) <- get curr-token, number-data
  check-ints-equal *curr-token-data, 0/spaces, "F - test-tokenize-stream-literal/before-indent"
  read-from-stream stream, curr-token
  var stream?/eax: boolean <- stream-token? curr-token
  check stream?, "F - test-tokenize-stream-literal: type"
  var curr-token-data-ah/eax: (addr handle stream byte) <- get curr-token, text-data
  var curr-token-data/eax: (addr stream byte) <- lookup *curr-token-data-ah
  var data-equal?/eax: boolean <- stream-data-equal? curr-token-data, "abc def"
  check data-equal?, "F - test-tokenize-stream-literal"
  var empty?/eax: boolean <- stream-empty? stream
  check empty?, "F - test-tokenize-stream-literal: empty?"
}

fn test-tokenize-stream-literal-in-tree {
  var in-storage: gap-buffer
  var in/esi: (addr gap-buffer) <- address in-storage
  initialize-gap-buffer-with in, "([abc def])"
  #
  var stream-storage: (stream token 0x10)
  var stream/edi: (addr stream token) <- address stream-storage
  #
  var trace-storage: trace
  var trace/edx: (addr trace) <- address trace-storage
  initialize-trace trace, 1/only-errors, 0x10/capacity, 0/visible
  tokenize in, stream, trace
  #
  var curr-token-storage: token
  var curr-token/ebx: (addr token) <- address curr-token-storage
  read-from-stream stream, curr-token
  var curr-token-type/eax: (addr int) <- get curr-token, type
  check-ints-equal *curr-token-type, 3/indent, "F - test-tokenize-stream-literal-in-tree/before-indent-type"
  var curr-token-data/eax: (addr int) <- get curr-token, number-data
  check-ints-equal *curr-token-data, 0/spaces, "F - test-tokenize-stream-literal-in-tree/before-indent"
  read-from-stream stream, curr-token
  var bracket?/eax: boolean <- bracket-token? curr-token
  check bracket?, "F - test-tokenize-stream-literal-in-tree: open paren"
  read-from-stream stream, curr-token
  var stream?/eax: boolean <- stream-token? curr-token
  check stream?, "F - test-tokenize-stream-literal-in-tree: type"
  var curr-token-data-ah/eax: (addr handle stream byte) <- get curr-token, text-data
  var curr-token-data/eax: (addr stream byte) <- lookup *curr-token-data-ah
  var data-equal?/eax: boolean <- stream-data-equal? curr-token-data, "abc def"
  check data-equal?, "F - test-tokenize-stream-literal-in-tree"
  read-from-stream stream, curr-token
  var bracket?/eax: boolean <- bracket-token? curr-token
  check bracket?, "F - test-tokenize-stream-literal-in-tree: close paren"
  var empty?/eax: boolean <- stream-empty? stream
  check empty?, "F - test-tokenize-stream-literal-in-tree: empty?"
}

fn test-tokenize-indent {
  var in-storage: gap-buffer
  var in/esi: (addr gap-buffer) <- address in-storage
  initialize-gap-buffer-with in, "abc\n  def"
  #
  var stream-storage: (stream token 0x10)
  var stream/edi: (addr stream token) <- address stream-storage
  #
  var trace-storage: trace
  var trace/edx: (addr trace) <- address trace-storage
  initialize-trace trace, 1/only-errors, 0x10/capacity, 0/visible
  tokenize in, stream, trace
  #
  var curr-token-storage: token
  var curr-token/ebx: (addr token) <- address curr-token-storage
  read-from-stream stream, curr-token
  var curr-token-type/eax: (addr int) <- get curr-token, type
  check-ints-equal *curr-token-type, 3/indent, "F - test-tokenize-indent/before-indent-type"
  var curr-token-data/eax: (addr int) <- get curr-token, number-data
  check-ints-equal *curr-token-data, 0/spaces, "F - test-tokenize-indent/before-indent"
  read-from-stream stream, curr-token
  var curr-token-data-ah/eax: (addr handle stream byte) <- get curr-token, text-data
  var curr-token-data/eax: (addr stream byte) <- lookup *curr-token-data-ah
  check-stream-equal curr-token-data, "abc", "F - test-tokenize-indent/before"
  #
  read-from-stream stream, curr-token
  var curr-token-type/eax: (addr int) <- get curr-token, type
  check-ints-equal *curr-token-type, 3/indent, "F - test-tokenize-indent/type"
  var curr-token-data/eax: (addr int) <- get curr-token, number-data
  check-ints-equal *curr-token-data, 2/spaces, "F - test-tokenize-indent"
  #
  read-from-stream stream, curr-token
  var curr-token-data-ah/eax: (addr handle stream byte) <- get curr-token, text-data
  var curr-token-data/eax: (addr stream byte) <- lookup *curr-token-data-ah
  check-stream-equal curr-token-data, "def", "F - test-tokenize-indent/after"
}

# caller is responsible for threading start-of-line? between calls to next-token
# 'in' may contain whitespace if start-of-line?
fn next-token in: (addr gap-buffer), out: (addr token), start-of-line?: boolean, trace: (addr trace) -> _/edi: boolean {
  trace-text trace, "tokenize", "next-token"
  trace-lower trace
  # save an indent token if necessary
  {
    compare start-of-line?, 0/false
    break-if-=
    next-indent-token in, out, trace  # might not be returned
  }
  skip-spaces-from-gap-buffer in
  var g/eax: grapheme <- peek-from-gap-buffer in
  {
    compare g, 0x23/comment
    break-if-!=
    skip-rest-of-line in
  }
  var g/eax: grapheme <- peek-from-gap-buffer in
  {
    compare g, 0xa/newline
    break-if-!=
    trace-text trace, "tokenize", "newline"
    g <- read-from-gap-buffer in
    initialize-skip-token out  # might drop indent if that's all there was in this line
    trace-higher trace
    return 1/at-start-of-line
  }
  {
    compare start-of-line?, 0/false
    break-if-=
    # still here? no comment or newline? return saved indent
    trace-higher trace
    return 0/not-at-start-of-line
  }
  {
    var done?/eax: boolean <- gap-buffer-scan-done? in
    compare done?, 0/false
    break-if-=
    trace-text trace, "tokenize", "end"
    initialize-skip-token out
    trace-higher trace
    return 1/at-start-of-line
  }
  var _g/eax: grapheme <- peek-from-gap-buffer in
  var g/ecx: grapheme <- copy _g
  {
    var should-trace?/eax: boolean <- should-trace? trace
    compare should-trace?, 0/false
    break-if-=
    var stream-storage: (stream byte 0x40)
    var stream/esi: (addr stream byte) <- address stream-storage
    write stream, "next: "
    var gval/eax: int <- copy g
    write-int32-hex stream, gval
    trace trace, "tokenize", stream
  }
  $next-token:case: {
    # open square brackets begin streams
    {
      compare g, 0x5b/open-square-bracket
      break-if-!=
      var dummy/eax: grapheme <- read-from-gap-buffer in  # skip open bracket
      next-stream-token in, out, trace
      break $next-token:case
    }
    # special-case: '-'
    {
      compare g, 0x2d/minus
      break-if-!=
      var dummy/eax: grapheme <- read-from-gap-buffer in  # skip '-'
      var g2/eax: grapheme <- peek-from-gap-buffer in
      put-back-from-gap-buffer in
      var digit?/eax: boolean <- decimal-digit? g2
      compare digit?, 0/false
      break-if-=
      next-number-token in, out, trace
      break $next-token:case
    }
    # digit
    {
      var digit?/eax: boolean <- decimal-digit? g
      compare digit?, 0/false
      break-if-=
      next-number-token in, out, trace
      break $next-token:case
    }
    # other symbol char
    {
      var symbol?/eax: boolean <- symbol-grapheme? g
      compare symbol?, 0/false
      break-if-=
      next-symbol-token in, out, trace
      break $next-token:case
    }
    # unbalanced close square brackets are errors
    {
      compare g, 0x5d/close-square-bracket
      break-if-!=
      error trace, "unbalanced ']'"
      return start-of-line?
    }
    # other brackets are always single-char tokens
    {
      var bracket?/eax: boolean <- bracket-grapheme? g
      compare bracket?, 0/false
      break-if-=
      var g/eax: grapheme <- read-from-gap-buffer in
      next-bracket-token g, out, trace
      break $next-token:case
    }
    # quote
    {
      compare g, 0x27/single-quote
      break-if-!=
      var g/eax: grapheme <- read-from-gap-buffer in  # consume
      initialize-token out, "'"
      break $next-token:case
    }
    # backquote
    {
      compare g, 0x60/backquote
      break-if-!=
      var g/eax: grapheme <- read-from-gap-buffer in  # consume
      initialize-token out, "`"
      break $next-token:case
    }
    # unquote
    {
      compare g, 0x2c/comma
      break-if-!=
      var g/eax: grapheme <- read-from-gap-buffer in  # consume
      # check for unquote-splice
      {
        g <- peek-from-gap-buffer in
        compare g, 0x40/at-sign
        break-if-!=
        g <- read-from-gap-buffer in
        initialize-token out, ",@"
        break $next-token:case
      }
      initialize-token out, ","
      break $next-token:case
    }
    set-cursor-position 0/screen, 0x40 0x20
    {
      var foo/eax: int <- copy g
      draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, foo, 7/fg 0/bg
    }
    abort "unknown token type"
  }
  trace-higher trace
  {
    var should-trace?/eax: boolean <- should-trace? trace
    compare should-trace?, 0/false
    break-if-=
    var stream-storage: (stream byte 0x400)  # maximum possible token size (next-stream-token)
    var stream/eax: (addr stream byte) <- address stream-storage
    write stream, "=> "
    write-token-text-data stream, out
    trace trace, "tokenize", stream
  }
  return start-of-line?
}

fn next-symbol-token in: (addr gap-buffer), _out: (addr token), trace: (addr trace) {
  trace-text trace, "tokenize", "looking for a symbol"
  trace-lower trace
  var out/eax: (addr token) <- copy _out
  var out-data-ah/eax: (addr handle stream byte) <- get out, text-data
  populate-stream out-data-ah, 0x40
  var _out-data/eax: (addr stream byte) <- lookup *out-data-ah
  var out-data/edi: (addr stream byte) <- copy _out-data
  $next-symbol-token:loop: {
    var done?/eax: boolean <- gap-buffer-scan-done? in
    compare done?, 0/false
    break-if-!=
    var g/eax: grapheme <- peek-from-gap-buffer in
    {
      {
        var should-trace?/eax: boolean <- should-trace? trace
        compare should-trace?, 0/false
      }
      break-if-=
      var stream-storage: (stream byte 0x40)
      var stream/esi: (addr stream byte) <- address stream-storage
      write stream, "next: "
      var gval/eax: int <- copy g
      write-int32-hex stream, gval
      trace trace, "tokenize", stream
    }
    # if non-symbol, return
    {
      var symbol-grapheme?/eax: boolean <- symbol-grapheme? g
      compare symbol-grapheme?, 0/false
      break-if-!=
      trace-text trace, "tokenize", "stop"
      break $next-symbol-token:loop
    }
    var g/eax: grapheme <- read-from-gap-buffer in
    write-grapheme out-data, g
    loop
  }
  trace-higher trace
  {
    var should-trace?/eax: boolean <- should-trace? trace
    compare should-trace?, 0/false
    break-if-=
    var stream-storage: (stream byte 0x40)
    var stream/esi: (addr stream byte) <- address stream-storage
    write stream, "=> "
    rewind-stream out-data
    write-stream stream, out-data
    trace trace, "tokenize", stream
  }
}

fn next-number-token in: (addr gap-buffer), _out: (addr token), trace: (addr trace) {
  trace-text trace, "tokenize", "looking for a number"
  trace-lower trace
  var out/eax: (addr token) <- copy _out
  var out-data-ah/eax: (addr handle stream byte) <- get out, text-data
  populate-stream out-data-ah, 0x40
  var _out-data/eax: (addr stream byte) <- lookup *out-data-ah
  var out-data/edi: (addr stream byte) <- copy _out-data
  $next-number-token:check-minus: {
    var g/eax: grapheme <- peek-from-gap-buffer in
    compare g, 0x2d/minus
    g <- read-from-gap-buffer in  # consume
    write-grapheme out-data, g
  }
  $next-number-token:loop: {
    var done?/eax: boolean <- gap-buffer-scan-done? in
    compare done?, 0/false
    break-if-!=
    var g/eax: grapheme <- peek-from-gap-buffer in
    {
      {
        var should-trace?/eax: boolean <- should-trace? trace
        compare should-trace?, 0/false
      }
      break-if-=
      var stream-storage: (stream byte 0x40)
      var stream/esi: (addr stream byte) <- address stream-storage
      write stream, "next: "
      var gval/eax: int <- copy g
      write-int32-hex stream, gval
      trace trace, "tokenize", stream
    }
    # if not symbol grapheme, return
    {
      var symbol-grapheme?/eax: boolean <- symbol-grapheme? g
      compare symbol-grapheme?, 0/false
      break-if-!=
      trace-text trace, "tokenize", "stop"
      break $next-number-token:loop
    }
    # if not digit grapheme, abort
    {
      var digit?/eax: boolean <- decimal-digit? g
      compare digit?, 0/false
      break-if-!=
      error trace, "invalid number"
      return
    }
    trace-text trace, "tokenize", "append"
    var g/eax: grapheme <- read-from-gap-buffer in
    write-grapheme out-data, g
    loop
  }
  trace-higher trace
}

fn next-stream-token in: (addr gap-buffer), _out: (addr token), trace: (addr trace) {
  trace-text trace, "tokenize", "stream"
  var out/edi: (addr token) <- copy _out
  var out-type/eax: (addr int) <- get out, type
  copy-to *out-type, 1/stream
  var out-data-ah/eax: (addr handle stream byte) <- get out, text-data
  # stream tokens contain whole function definitions on boot, so we always
  # give them plenty of space
  populate-stream out-data-ah, 0x400/max-definition-size=1KB
  var _out-data/eax: (addr stream byte) <- lookup *out-data-ah
  var out-data/edi: (addr stream byte) <- copy _out-data
  {
    var empty?/eax: boolean <- gap-buffer-scan-done? in
    compare empty?, 0/false
    {
      break-if-=
      error trace, "unbalanced '['"
      return
    }
    var g/eax: grapheme <- read-from-gap-buffer in
    compare g, 0x5d/close-square-bracket
    break-if-=
    write-grapheme out-data, g
    loop
  }
  {
    var should-trace?/eax: boolean <- should-trace? trace
    compare should-trace?, 0/false
    break-if-=
    var stream-storage: (stream byte 0x400)  # max-definition-size
    var stream/esi: (addr stream byte) <- address stream-storage
    write stream, "=> "
    rewind-stream out-data
    write-stream stream, out-data
    trace trace, "tokenize", stream
  }
}

fn next-bracket-token g: grapheme, _out: (addr token), trace: (addr trace) {
  trace-text trace, "tokenize", "bracket"
  var out/eax: (addr token) <- copy _out
  var out-data-ah/eax: (addr handle stream byte) <- get out, text-data
  populate-stream out-data-ah, 0x40
  var _out-data/eax: (addr stream byte) <- lookup *out-data-ah
  var out-data/edi: (addr stream byte) <- copy _out-data
  write-grapheme out-data, g
  {
    var should-trace?/eax: boolean <- should-trace? trace
    compare should-trace?, 0/false
    break-if-=
    var stream-storage: (stream byte 0x40)
    var stream/esi: (addr stream byte) <- address stream-storage
    write stream, "=> "
    rewind-stream out-data
    write-stream stream, out-data
    trace trace, "tokenize", stream
  }
}

fn skip-rest-of-line in: (addr gap-buffer) {
  {
    var done?/eax: boolean <- gap-buffer-scan-done? in
    compare done?, 0/false
    break-if-!=
    var g/eax: grapheme <- peek-from-gap-buffer in
    compare g, 0xa/newline
    break-if-=
    g <- read-from-gap-buffer in  # consume
    loop
  }
}

fn next-indent-token in: (addr gap-buffer), _out: (addr token), trace: (addr trace) {
  trace-text trace, "tokenize", "indent"
  trace-lower trace
  var out/edi: (addr token) <- copy _out
  var out-type/eax: (addr int) <- get out, type
  copy-to *out-type, 3/indent
  var dest/edi: (addr int) <- get out, number-data
  copy-to *dest, 0
  {
    var done?/eax: boolean <- gap-buffer-scan-done? in
    compare done?, 0/false
    break-if-!=
    var g/eax: grapheme <- peek-from-gap-buffer in
    {
      {
        var should-trace?/eax: boolean <- should-trace? trace
        compare should-trace?, 0/false
      }
      break-if-=
      var stream-storage: (stream byte 0x40)
      var stream/esi: (addr stream byte) <- address stream-storage
      write stream, "next: "
      var gval/eax: int <- copy g
      write-int32-hex stream, gval
      trace trace, "tokenize", stream
    }
    # if non-space, break
    compare g, 0x20/space
    break-if-!=
    g <- read-from-gap-buffer in
    increment *dest
    loop
  }
  trace-higher trace
  {
    var should-trace?/eax: boolean <- should-trace? trace
    compare should-trace?, 0/false
    break-if-=
    var stream-storage: (stream byte 0x40)
    var stream/esi: (addr stream byte) <- address stream-storage
    write stream, "=> indent "
    write-int32-hex stream, *dest
    trace trace, "tokenize", stream
  }
}

# Mu carves up the space of graphemes into 4 categories:
#   whitespace
#   quotes and unquotes (from a Lisp perspective; doesn't include double
#                        quotes or other Unicode quotes)
#   operators
#   symbols
# (Numbers have their own parsing rules that don't fit cleanly in this
# partition.)
#
# During tokenization operators and symbols are treated identically.
# A later phase digs into that nuance.

fn symbol-grapheme? g: grapheme -> _/eax: boolean {
  var whitespace?/eax: boolean <- whitespace-grapheme? g
  compare whitespace?, 0/false
  {
    break-if-=
    return 0/false
  }
  var quote-or-unquote?/eax: boolean <- quote-or-unquote-grapheme? g
  compare quote-or-unquote?, 0/false
  {
    break-if-=
    return 0/false
  }
  var bracket?/eax: boolean <- bracket-grapheme? g
  compare bracket?, 0/false
  {
    break-if-=
    return 0/false
  }
  compare g, 0x23/hash  # comments get filtered out
  {
    break-if-!=
    return 0/false
  }
  compare g, 0x22/double-quote  # double quotes reserved for now
  {
    break-if-!=
    return 0/false
  }
  return 1/true
}

fn whitespace-grapheme? g: grapheme -> _/eax: boolean {
  compare g, 9/tab
  {
    break-if-!=
    return 1/true
  }
  compare g, 0xa/newline
  {
    break-if-!=
    return 1/true
  }
  compare g, 0x20/space
  {
    break-if-!=
    return 1/true
  }
  return 0/false
}

fn quote-or-unquote-grapheme? g: grapheme -> _/eax: boolean {
  compare g, 0x27/single-quote
  {
    break-if-!=
    return 1/true
  }
  compare g, 0x60/backquote
  {
    break-if-!=
    return 1/true
  }
  compare g, 0x2c/comma
  {
    break-if-!=
    return 1/true
  }
  compare g, 0x40/at-sign
  {
    break-if-!=
    return 1/true
  }
  return 0/false
}

fn bracket-grapheme? g: grapheme -> _/eax: boolean {
  compare g, 0x28/open-paren
  {
    break-if-!=
    return 1/true
  }
  compare g, 0x29/close-paren
  {
    break-if-!=
    return 1/true
  }
  compare g, 0x5b/open-square-bracket
  {
    break-if-!=
    return 1/true
  }
  compare g, 0x5d/close-square-bracket
  {
    break-if-!=
    return 1/true
  }
  compare g, 0x7b/open-curly-bracket
  {
    break-if-!=
    return 1/true
  }
  compare g, 0x7d/close-curly-bracket
  {
    break-if-!=
    return 1/true
  }
  return 0/false
}

fn number-token? _self: (addr token) -> _/eax: boolean {
  var self/eax: (addr token) <- copy _self
  var in-data-ah/eax: (addr handle stream byte) <- get self, text-data
  var _in-data/eax: (addr stream byte) <- lookup *in-data-ah
  var in-data/ecx: (addr stream byte) <- copy _in-data
  rewind-stream in-data
  var g/eax: grapheme <- read-grapheme in-data
  # if '-', read another
  {
    compare g, 0x2d/minus
    break-if-!=
    g <- read-grapheme in-data
  }
  var result/eax: boolean <- decimal-digit? g
  return result
}

fn bracket-token? _self: (addr token) -> _/eax: boolean {
  var self/eax: (addr token) <- copy _self
  {
    var in-type/eax: (addr int) <- get self, type
    compare *in-type, 1/stream
    break-if-!=
    # streams are never paren tokens
    return 0/false
  }
  var in-data-ah/eax: (addr handle stream byte) <- get self, text-data
  var in-data/eax: (addr stream byte) <- lookup *in-data-ah
  rewind-stream in-data
  var g/eax: grapheme <- read-grapheme in-data
  var result/eax: boolean <- bracket-grapheme? g
  return result
}

fn quote-token? _self: (addr token) -> _/eax: boolean {
  var self/eax: (addr token) <- copy _self
  var in-data-ah/eax: (addr handle stream byte) <- get self, text-data
  var in-data/eax: (addr stream byte) <- lookup *in-data-ah
  rewind-stream in-data
  var result/eax: boolean <- stream-data-equal? in-data, "'"
  return result
}

fn backquote-token? _self: (addr token) -> _/eax: boolean {
  var self/eax: (addr token) <- copy _self
  var in-data-ah/eax: (addr handle stream byte) <- get self, text-data
  var in-data/eax: (addr stream byte) <- lookup *in-data-ah
  rewind-stream in-data
  var result/eax: boolean <- stream-data-equal? in-data, "`"
  return result
}

fn unquote-token? _self: (addr token) -> _/eax: boolean {
  var self/eax: (addr token) <- copy _self
  var in-data-ah/eax: (addr handle stream byte) <- get self, text-data
  var in-data/eax: (addr stream byte) <- lookup *in-data-ah
  rewind-stream in-data
  var result/eax: boolean <- stream-data-equal? in-data, ","
  return result
}

fn unquote-splice-token? _self: (addr token) -> _/eax: boolean {
  var self/eax: (addr token) <- copy _self
  var in-data-ah/eax: (addr handle stream byte) <- get self, text-data
  var in-data/eax: (addr stream byte) <- lookup *in-data-ah
  rewind-stream in-data
  var result/eax: boolean <- stream-data-equal? in-data, ",@"
  return result
}

fn open-paren-token? _self: (addr token) -> _/eax: boolean {
  var self/eax: (addr token) <- copy _self
  var in-data-ah/eax: (addr handle stream byte) <- get self, text-data
  var _in-data/eax: (addr stream byte) <- lookup *in-data-ah
  var in-data/ecx: (addr stream byte) <- copy _in-data
  rewind-stream in-data
  var g/eax: grapheme <- read-grapheme in-data
  compare g, 0x28/open-paren
  {
    break-if-!=
    var result/eax: boolean <- stream-empty? in-data
    return result
  }
  return 0/false
}

fn close-paren-token? _self: (addr token) -> _/eax: boolean {
  var self/eax: (addr token) <- copy _self
  var in-data-ah/eax: (addr handle stream byte) <- get self, text-data
  var _in-data/eax: (addr stream byte) <- lookup *in-data-ah
  var in-data/ecx: (addr stream byte) <- copy _in-data
  rewind-stream in-data
  var g/eax: grapheme <- read-grapheme in-data
  compare g, 0x29/close-paren
  {
    break-if-!=
    var result/eax: boolean <- stream-empty? in-data
    return result
  }
  return 0/false
}

fn dot-token? _self: (addr token) -> _/eax: boolean {
  var self/eax: (addr token) <- copy _self
  var in-data-ah/eax: (addr handle stream byte) <- get self, text-data
  var _in-data/eax: (addr stream byte) <- lookup *in-data-ah
  var in-data/ecx: (addr stream byte) <- copy _in-data
  rewind-stream in-data
  var g/eax: grapheme <- read-grapheme in-data
  compare g, 0x2e/dot
  {
    break-if-!=
    var result/eax: boolean <- stream-empty? in-data
    return result
  }
  return 0/false
}

fn test-dot-token {
  var tmp-storage: (handle token)
  var tmp-ah/eax: (addr handle token) <- address tmp-storage
  allocate-token tmp-ah
  var tmp/eax: (addr token) <- lookup *tmp-ah
  initialize-token tmp, "."
  var result/eax: boolean <- dot-token? tmp
  check result, "F - test-dot-token"
}

fn stream-token? _self: (addr token) -> _/eax: boolean {
  var self/eax: (addr token) <- copy _self
  var in-type/eax: (addr int) <- get self, type
  compare *in-type, 1/stream
  {
    break-if-=
    return 0/false
  }
  return 1/true
}

fn skip-token? _self: (addr token) -> _/eax: boolean {
  var self/eax: (addr token) <- copy _self
  var in-type/eax: (addr int) <- get self, type
  compare *in-type, 2/skip
  {
    break-if-=
    return 0/false
  }
  return 1/true
}

fn indent-token? _self: (addr token) -> _/eax: boolean {
  var self/eax: (addr token) <- copy _self
  var in-type/eax: (addr int) <- get self, type
  compare *in-type, 3/indent
  {
    break-if-=
    return 0/false
  }
  return 1/true
}

fn allocate-token _self-ah: (addr handle token) {
  var self-ah/eax: (addr handle token) <- copy _self-ah
  allocate self-ah
  var self/eax: (addr token) <- lookup *self-ah
  var dest-ah/eax: (addr handle stream byte) <- get self, text-data
  populate-stream dest-ah, 0x40/max-symbol-size
}

fn initialize-token _self: (addr token), val: (addr array byte) {
  var self/eax: (addr token) <- copy _self
  var dest-ah/eax: (addr handle stream byte) <- get self, text-data
  populate-stream dest-ah, 0x40
  var dest/eax: (addr stream byte) <- lookup *dest-ah
  write dest, val
}

fn initialize-skip-token _self: (addr token) {
  var self/eax: (addr token) <- copy _self
  var self-type/eax: (addr int) <- get self, type
  copy-to *self-type, 2/skip
}

fn write-token-text-data out: (addr stream byte), _self: (addr token) {
  var self/eax: (addr token) <- copy _self
  var data-ah/eax: (addr handle stream byte) <- get self, text-data
  var data/eax: (addr stream byte) <- lookup *data-ah
  rewind-stream data
  write-stream out, data
}

fn tokens-equal? _a: (addr token), _b: (addr token) -> _/eax: boolean {
  var a/edx: (addr token) <- copy _a
  var b/ebx: (addr token) <- copy _b
  var a-type-addr/eax: (addr int) <- get a, type
  var a-type/eax: int <- copy *a-type-addr
  var b-type-addr/ecx: (addr int) <- get b, type
  compare a-type, *b-type-addr
  {
    break-if-=
    return 0/false
  }
  compare a-type, 2/skip
  {
    break-if-!=
    # skip tokens have no other data
    return 1/true
  }
  compare a-type, 3/indent
  {
    break-if-!=
    # indent tokens have no other data
    var a-number-data-addr/eax: (addr int) <- get a, number-data
    var a-number-data/eax: int <- copy *a-number-data-addr
    var b-number-data-addr/ecx: (addr int) <- get b, number-data
    compare a-number-data, *b-number-data-addr
    {
      break-if-=
      return 0/false
    }
    return 1/true
  }
  var b-data-ah/eax: (addr handle stream byte) <- get b, text-data
  var _b-data/eax: (addr stream byte) <- lookup *b-data-ah
  var b-data/ebx: (addr stream byte) <- copy _b-data
  var a-data-ah/eax: (addr handle stream byte) <- get a, text-data
  var a-data/eax: (addr stream byte) <- lookup *a-data-ah
  var data-match?/eax: boolean <- streams-data-equal? a-data, b-data
  return data-match?
}

fn dump-token-from-cursor _t: (addr token) {
  var t/esi: (addr token) <- copy _t
  var type/eax: (addr int) <- get t, type
  draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, *type, 7/fg 0/bg
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, " ", 7/fg 0/bg
  var text-ah/eax: (addr handle stream byte) <- get t, text-data
  var text/eax: (addr stream byte) <- lookup *text-ah
  rewind-stream text
  draw-stream-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, text, 7/fg 0/bg
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, " ", 7/fg 0/bg
  var num/eax: (addr int) <- get t, number-data
  draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, *num, 7/fg 0/bg
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "\n", 7/fg 0/bg
}
