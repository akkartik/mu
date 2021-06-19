# tokens are like cells, but not recursive
type token {
  type: int
  # type 0: default
  # type 1: stream
  text-data: (handle stream byte)
  # type 2: skip (end of line or end of file)
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
    var comment?/eax: boolean <- comment-token? token
    compare comment?, 0/false
    loop-if-!=
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
  var number?/eax: boolean <- number-token? curr-token
  check number?, "F - test-tokenize-negative-number"
  var curr-token-data-ah/eax: (addr handle stream byte) <- get curr-token, text-data
  var curr-token-data/eax: (addr stream byte) <- lookup *curr-token-data-ah
  check-stream-equal curr-token-data, "-123", "F - test-tokenize-negative-number: value"
}

fn test-tokenize-number-followed-by-hyphen {
  var in-storage: gap-buffer
  var in/esi: (addr gap-buffer) <- address in-storage
  initialize-gap-buffer-with in, "123-4 a"
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
  var number?/eax: boolean <- number-token? curr-token
  check number?, "F - test-tokenize-number-followed-by-hyphen"
  var curr-token-data-ah/eax: (addr handle stream byte) <- get curr-token, text-data
  var curr-token-data/eax: (addr stream byte) <- lookup *curr-token-data-ah
  check-stream-equal curr-token-data, "123", "F - test-tokenize-number-followed-by-hyphen: value"
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

# caller is responsible for threading start-of-line? between calls to next-token
# 'in' may contain whitespace if start-of-line?
fn next-token in: (addr gap-buffer), _out: (addr token), start-of-line?: boolean, trace: (addr trace) -> _/edi: boolean {
  trace-text trace, "tokenize", "next-token"
  trace-lower trace
  skip-spaces-from-gap-buffer in
  {
    var g/eax: grapheme <- peek-from-gap-buffer in
    compare g, 0xa/newline
    break-if-!=
    trace-text trace, "tokenize", "newline"
    g <- read-from-gap-buffer in
    var out/eax: (addr token) <- copy _out
    var out-type/eax: (addr int) <- get out, type
    copy-to *out-type, 2/skip
    return 1/at-start-of-line
  }
  {
    var done?/eax: boolean <- gap-buffer-scan-done? in
    compare done?, 0/false
    break-if-=
    trace-text trace, "tokenize", "end"
    var out/eax: (addr token) <- copy _out
    var out-type/eax: (addr int) <- get out, type
    copy-to *out-type, 2/skip
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
  var out/eax: (addr token) <- copy _out
  var out-data-ah/edi: (addr handle stream byte) <- get out, text-data
  $next-token:allocate: {
    # Allocate a large buffer if it's a stream.
    # Sometimes a whole function definition will need to fit in it.
    compare g, 0x5b/open-square-bracket
    {
      break-if-!=
      populate-stream out-data-ah, 0x400/max-definition-size=1KB
      break $next-token:allocate
    }
    populate-stream out-data-ah, 0x40
  }
  var _out-data/eax: (addr stream byte) <- lookup *out-data-ah
  var out-data/edi: (addr stream byte) <- copy _out-data
  clear-stream out-data
  $next-token:case: {
    # open square brackets begin streams
    {
      compare g, 0x5b/open-square-bracket
      break-if-!=
      var dummy/eax: grapheme <- read-from-gap-buffer in  # skip open bracket
      next-stream-token in, out-data, trace
      var out/eax: (addr token) <- copy _out
      # streams set the type
      var out-type/eax: (addr int) <- get out, type
      copy-to *out-type, 1/stream
      break $next-token:case
    }
    # comment
    {
      compare g, 0x23/comment
      break-if-!=
      rest-of-line in, out-data, trace
      copy-to start-of-line?, 1/true
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
      next-number-token in, out-data, trace
      break $next-token:case
    }
    # digit
    {
      var digit?/eax: boolean <- decimal-digit? g
      compare digit?, 0/false
      break-if-=
      next-number-token in, out-data, trace
      break $next-token:case
    }
    # other symbol char
    {
      var symbol?/eax: boolean <- symbol-grapheme? g
      compare symbol?, 0/false
      break-if-=
      next-symbol-token in, out-data, trace
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
      next-bracket-token g, out-data, trace
      break $next-token:case
    }
    # non-symbol operators
    {
      var operator?/eax: boolean <- operator-grapheme? g
      compare operator?, 0/false
      break-if-=
      next-operator-token in, out-data, trace
      break $next-token:case
    }
    # quote
    {
      compare g, 0x27/single-quote
      break-if-!=
      var g/eax: grapheme <- read-from-gap-buffer in  # consume
      write-grapheme out-data, g
      break $next-token:case
    }
    # backquote
    {
      compare g, 0x60/backquote
      break-if-!=
      var g/eax: grapheme <- read-from-gap-buffer in  # consume
      write-grapheme out-data, g
      break $next-token:case
    }
    # unquote
    {
      compare g, 0x2c/comma
      break-if-!=
      var g/eax: grapheme <- read-from-gap-buffer in  # consume
      write-grapheme out-data, g
      # check for unquote-splice
      {
        var g2/eax: grapheme <- peek-from-gap-buffer in
        compare g2, 0x40/at-sign
        break-if-!=
        g2 <- read-from-gap-buffer in
        write-grapheme out-data, g2
      }
      break $next-token:case
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
    rewind-stream out-data
    write-stream stream, out-data
    trace trace, "tokenize", stream
  }
  return start-of-line?
}

fn next-symbol-token in: (addr gap-buffer), out: (addr stream byte), trace: (addr trace) {
  trace-text trace, "tokenize", "looking for a symbol"
  trace-lower trace
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
    write-grapheme out, g
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
    rewind-stream out
    write-stream stream, out
    trace trace, "tokenize", stream
  }
}

fn next-operator-token in: (addr gap-buffer), out: (addr stream byte), trace: (addr trace) {
  trace-text trace, "tokenize", "looking for a operator"
  trace-lower trace
  $next-operator-token:loop: {
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
    # if non-operator, return
    {
      var operator-grapheme?/eax: boolean <- operator-grapheme? g
      compare operator-grapheme?, 0/false
      break-if-!=
      trace-text trace, "tokenize", "stop"
      break $next-operator-token:loop
    }
    var g/eax: grapheme <- read-from-gap-buffer in
    write-grapheme out, g
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
    rewind-stream out
    write-stream stream, out
    trace trace, "tokenize", stream
  }
}

fn next-number-token in: (addr gap-buffer), out: (addr stream byte), trace: (addr trace) {
  trace-text trace, "tokenize", "looking for a number"
  trace-lower trace
  $next-number-token:check-minus: {
    var g/eax: grapheme <- peek-from-gap-buffer in
    compare g, 0x2d/minus
    g <- read-from-gap-buffer in  # consume
    write-grapheme out, g
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
    write-grapheme out, g
    loop
  }
  trace-higher trace
}

fn next-stream-token in: (addr gap-buffer), out: (addr stream byte), trace: (addr trace) {
  trace-text trace, "tokenize", "stream"
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
    write-grapheme out, g
    loop
  }
  {
    var should-trace?/eax: boolean <- should-trace? trace
    compare should-trace?, 0/false
    break-if-=
    var stream-storage: (stream byte 0x400)  # max-definition-size
    var stream/esi: (addr stream byte) <- address stream-storage
    write stream, "=> "
    rewind-stream out
    write-stream stream, out
    trace trace, "tokenize", stream
  }
}

fn next-bracket-token g: grapheme, out: (addr stream byte), trace: (addr trace) {
  trace-text trace, "tokenize", "bracket"
  write-grapheme out, g
  {
    var should-trace?/eax: boolean <- should-trace? trace
    compare should-trace?, 0/false
    break-if-=
    var stream-storage: (stream byte 0x40)
    var stream/esi: (addr stream byte) <- address stream-storage
    write stream, "=> "
    rewind-stream out
    write-stream stream, out
    trace trace, "tokenize", stream
  }
}

fn rest-of-line in: (addr gap-buffer), out: (addr stream byte), trace: (addr trace) {
  trace-text trace, "tokenize", "comment"
  {
    var empty?/eax: boolean <- gap-buffer-scan-done? in
    compare empty?, 0/false
    {
      break-if-=
      return
    }
    var g/eax: grapheme <- read-from-gap-buffer in
    compare g, 0xa/newline
    break-if-=
    write-grapheme out, g
    loop
  }
  {
    var should-trace?/eax: boolean <- should-trace? trace
    compare should-trace?, 0/false
    break-if-=
    var stream-storage: (stream byte 0x80)
    var stream/esi: (addr stream byte) <- address stream-storage
    write stream, "=> "
    rewind-stream out
    write-stream stream, out
    trace trace, "tokenize", stream
  }
}

fn symbol-grapheme? g: grapheme -> _/eax: boolean {
  ## whitespace
  compare g, 9/tab
  {
    break-if-!=
    return 0/false
  }
  compare g, 0xa/newline
  {
    break-if-!=
    return 0/false
  }
  compare g, 0x20/space
  {
    break-if-!=
    return 0/false
  }
  ## quotes
  compare g, 0x22/double-quote
  {
    break-if-!=
    return 0/false
  }
  compare g, 0x60/backquote
  {
    break-if-!=
    return 0/false
  }
  ## brackets
  compare g, 0x28/open-paren
  {
    break-if-!=
    return 0/false
  }
  compare g, 0x29/close-paren
  {
    break-if-!=
    return 0/false
  }
  compare g, 0x5b/open-square-bracket
  {
    break-if-!=
    return 0/false
  }
  compare g, 0x5d/close-square-bracket
  {
    break-if-!=
    return 0/false
  }
  compare g, 0x7b/open-curly-bracket
  {
    break-if-!=
    return 0/false
  }
  compare g, 0x7d/close-curly-bracket
  {
    break-if-!=
    return 0/false
  }
  # - other punctuation
  # '!' is a symbol char
  compare g, 0x23/hash
  {
    break-if-!=
    return 0/false
  }
  # '$' is a symbol char
  compare g, 0x25/percent
  {
    break-if-!=
    return 0/false
  }
  compare g, 0x26/ampersand
  {
    break-if-!=
    return 0/false
  }
  compare g, 0x27/single-quote
  {
    break-if-!=
    return 0/false
  }
  compare g, 0x60/backquote
  {
    break-if-!=
    return 0/false
  }
  compare g, 0x2c/comma
  {
    break-if-!=
    return 0/false
  }
  compare g, 0x40/at-sign
  {
    break-if-!=
    return 0/false
  }
  compare g, 0x2a/asterisk
  {
    break-if-!=
    return 0/false
  }
  compare g, 0x2b/plus
  {
    break-if-!=
    return 0/false
  }
  compare g, 0x2d/dash  # '-' not allowed in symbols
  {
    break-if-!=
    return 0/false
  }
  compare g, 0x2e/period
  {
    break-if-!=
    return 0/false
  }
  compare g, 0x2f/slash
  {
    break-if-!=
    return 0/false
  }
  compare g, 0x3a/colon
  {
    break-if-!=
    return 0/false
  }
  compare g, 0x3b/semi-colon
  {
    break-if-!=
    return 0/false
  }
  compare g, 0x3c/less-than
  {
    break-if-!=
    return 0/false
  }
  compare g, 0x3d/equal
  {
    break-if-!=
    return 0/false
  }
  compare g, 0x3e/greater-than
  {
    break-if-!=
    return 0/false
  }
  # '?' is a symbol char
  compare g, 0x5c/backslash
  {
    break-if-!=
    return 0/false
  }
  compare g, 0x5e/caret
  {
    break-if-!=
    return 0/false
  }
  # '_' is a symbol char
  compare g, 0x7c/vertical-line
  {
    break-if-!=
    return 0/false
  }
  compare g, 0x7e/tilde
  {
    break-if-!=
    return 0/false
  }
  return 1/true
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

fn operator-grapheme? g: grapheme -> _/eax: boolean {
  # '$' is a symbol char
  compare g, 0x25/percent
  {
    break-if-!=
    return 1/false
  }
  compare g, 0x26/ampersand
  {
    break-if-!=
    return 1/true
  }
  compare g, 0x27/single-quote
  {
    break-if-!=
    return 0/true
  }
  compare g, 0x60/backquote
  {
    break-if-!=
    return 0/false
  }
  compare g, 0x2c/comma
  {
    break-if-!=
    return 0/false
  }
  compare g, 0x40/at-sign
  {
    break-if-!=
    return 0/false
  }
  compare g, 0x2a/asterisk
  {
    break-if-!=
    return 1/true
  }
  compare g, 0x2b/plus
  {
    break-if-!=
    return 1/true
  }
  compare g, 0x2d/dash  # '-' not allowed in symbols
  {
    break-if-!=
    return 1/true
  }
  compare g, 0x2e/period
  {
    break-if-!=
    return 1/true
  }
  compare g, 0x2f/slash
  {
    break-if-!=
    return 1/true
  }
  compare g, 0x3a/colon
  {
    break-if-!=
    return 1/true
  }
  compare g, 0x3b/semi-colon
  {
    break-if-!=
    return 1/true
  }
  compare g, 0x3c/less-than
  {
    break-if-!=
    return 1/true
  }
  compare g, 0x3d/equal
  {
    break-if-!=
    return 1/true
  }
  compare g, 0x3e/greater-than
  {
    break-if-!=
    return 1/true
  }
  # '?' is a symbol char
  compare g, 0x5c/backslash
  {
    break-if-!=
    return 1/true
  }
  compare g, 0x5e/caret
  {
    break-if-!=
    return 1/true
  }
  # '_' is a symbol char
  compare g, 0x7c/vertical-line
  {
    break-if-!=
    return 1/true
  }
  compare g, 0x7e/tilde
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
  new-token tmp-ah, "."
  var tmp/eax: (addr token) <- lookup *tmp-ah
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

fn comment-token? _self: (addr token) -> _/eax: boolean {
  var self/eax: (addr token) <- copy _self
  var in-data-ah/eax: (addr handle stream byte) <- get self, text-data
  var in-data/eax: (addr stream byte) <- lookup *in-data-ah
  rewind-stream in-data
  var g/eax: grapheme <- read-grapheme in-data
  compare g, 0x23/hash
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

fn allocate-token _self-ah: (addr handle token) {
  var self-ah/eax: (addr handle token) <- copy _self-ah
  allocate self-ah
  var self/eax: (addr token) <- lookup *self-ah
  var dest-ah/eax: (addr handle stream byte) <- get self, text-data
  populate-stream dest-ah, 0x40/max-symbol-size
}

fn initialize-token _self-ah: (addr handle token), val: (addr array byte) {
  var self-ah/eax: (addr handle token) <- copy _self-ah
  var self/eax: (addr token) <- lookup *self-ah
  var dest-ah/eax: (addr handle stream byte) <- get self, text-data
  var dest/eax: (addr stream byte) <- lookup *dest-ah
  write dest, val
}

fn new-token self-ah: (addr handle token), val: (addr array byte) {
  allocate-token self-ah
  initialize-token self-ah, val
}
