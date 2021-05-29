# We reuse the cell data structure for tokenization
# Token cells are special, though. They have no type, they're always atoms,
# they always have text-data.

fn tokenize in: (addr gap-buffer), out: (addr stream cell), trace: (addr trace) {
  trace-text trace, "tokenize", "tokenize"
  trace-lower trace
  rewind-gap-buffer in
  var token-storage: cell
  var token/edx: (addr cell) <- address token-storage
  {
    skip-whitespace-from-gap-buffer in
    var done?/eax: boolean <- gap-buffer-scan-done? in
    compare done?, 0/false
    break-if-!=
    #
    next-token in, token, trace
    var skip?/eax: boolean <- comment-token? token
    compare skip?, 0/false
    loop-if-!=
    var error?/eax: boolean <- has-errors? trace
    compare error?, 0/false
    {
      break-if-=
      return
    }
    write-to-stream out, token  # shallow-copy text-data
    loop
  }
  trace-higher trace
}

fn test-tokenize-quote {
  var in-storage: gap-buffer
  var in/esi: (addr gap-buffer) <- address in-storage
  initialize-gap-buffer-with in, "'(a)"
  #
  var stream-storage: (stream cell 0x10)
  var stream/edi: (addr stream cell) <- address stream-storage
  #
  var trace-storage: trace
  var trace/edx: (addr trace) <- address trace-storage
  initialize-trace trace, 1/only-errors, 0x10/capacity, 0/visible
  tokenize in, stream, trace
  #
  var curr-token-storage: cell
  var curr-token/ebx: (addr cell) <- address curr-token-storage
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
  var stream-storage: (stream cell 0x10)
  var stream/edi: (addr stream cell) <- address stream-storage
  #
  var trace-storage: trace
  var trace/edx: (addr trace) <- address trace-storage
  initialize-trace trace, 1/only-errors, 0x10/capacity, 0/visible
  tokenize in, stream, trace
  #
  var curr-token-storage: cell
  var curr-token/ebx: (addr cell) <- address curr-token-storage
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
  var stream-storage: (stream cell 0x10)
  var stream/edi: (addr stream cell) <- address stream-storage
  #
  var trace-storage: trace
  var trace/edx: (addr trace) <- address trace-storage
  initialize-trace trace, 1/only-errors, 0x10/capacity, 0/visible
  tokenize in, stream, trace
  #
  var curr-token-storage: cell
  var curr-token/ebx: (addr cell) <- address curr-token-storage
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
  var stream-storage: (stream cell 0x10)
  var stream/edi: (addr stream cell) <- address stream-storage
  #
  var trace-storage: trace
  var trace/edx: (addr trace) <- address trace-storage
  initialize-trace trace, 1/only-errors, 0x10/capacity, 0/visible
  tokenize in, stream, trace
  #
  var curr-token-storage: cell
  var curr-token/ebx: (addr cell) <- address curr-token-storage
  read-from-stream stream, curr-token
  var unquote-splice?/eax: boolean <- unquote-splice-token? curr-token
  check unquote-splice?, "F - test-tokenize-unquote-splice: unquote-splice"
}

fn test-tokenize-dotted-list {
  var in-storage: gap-buffer
  var in/esi: (addr gap-buffer) <- address in-storage
  initialize-gap-buffer-with in, "(a . b)"
  #
  var stream-storage: (stream cell 0x10)
  var stream/edi: (addr stream cell) <- address stream-storage
  #
  var trace-storage: trace
  var trace/edx: (addr trace) <- address trace-storage
  initialize-trace trace, 1/only-errors, 0x10/capacity, 0/visible
  tokenize in, stream, trace
  #
  var curr-token-storage: cell
  var curr-token/ebx: (addr cell) <- address curr-token-storage
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
  var stream-storage: (stream cell 0x10)
  var stream/edi: (addr stream cell) <- address stream-storage
  #
  var trace-storage: trace
  var trace/edx: (addr trace) <- address trace-storage
  initialize-trace trace, 1/only-errors, 0x10/capacity, 0/visible
  tokenize in, stream, trace
  #
  var curr-token-storage: cell
  var curr-token/ebx: (addr cell) <- address curr-token-storage
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
  var stream-storage: (stream cell 0x10)
  var stream/edi: (addr stream cell) <- address stream-storage
  #
  var trace-storage: trace
  var trace/edx: (addr trace) <- address trace-storage
  initialize-trace trace, 1/only-errors, 0x10/capacity, 0/visible
  tokenize in, stream, trace
  #
  var curr-token-storage: cell
  var curr-token/ebx: (addr cell) <- address curr-token-storage
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

fn next-token in: (addr gap-buffer), _out-cell: (addr cell), trace: (addr trace) {
  trace-text trace, "tokenize", "next-token"
  trace-lower trace
  var _g/eax: grapheme <- peek-from-gap-buffer in
  var g/ecx: grapheme <- copy _g
  {
    var stream-storage: (stream byte 0x40)
    var stream/esi: (addr stream byte) <- address stream-storage
    write stream, "next: "
    var gval/eax: int <- copy g
    write-int32-hex stream, gval
    trace trace, "tokenize", stream
  }
  var out-cell/eax: (addr cell) <- copy _out-cell
  {
    var out-cell-type/eax: (addr int) <- get out-cell, type
    copy-to *out-cell-type, 0/uninitialized
  }
  var out-ah/edi: (addr handle stream byte) <- get out-cell, text-data
  $next-token:allocate: {
    # Allocate a large buffer if it's a stream.
    # Sometimes a whole function definition will need to fit in it.
    compare g, 0x5b/open-square-bracket
    {
      break-if-!=
      populate-stream out-ah, 0x400/max-definition-size=1KB
      break $next-token:allocate
    }
    populate-stream out-ah, 0x40
  }
  var _out/eax: (addr stream byte) <- lookup *out-ah
  var out/edi: (addr stream byte) <- copy _out
  clear-stream out
  $next-token:case: {
    # open square brackets begin streams
    {
      compare g, 0x5b/open-square-bracket
      break-if-!=
      var dummy/eax: grapheme <- read-from-gap-buffer in  # skip open bracket
      next-stream-token in, out, trace
      var out-cell/eax: (addr cell) <- copy _out-cell
      var out-cell-type/eax: (addr int) <- get out-cell, type
      copy-to *out-cell-type, 3/stream
      break $next-token:case
    }
    # comment
    {
      compare g, 0x23/comment
      break-if-!=
      rest-of-line in, out, trace
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
      return
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
    # non-symbol operators
    {
      var operator?/eax: boolean <- operator-grapheme? g
      compare operator?, 0/false
      break-if-=
      next-operator-token in, out, trace
      break $next-token:case
    }
    # quote
    {
      compare g, 0x27/single-quote
      break-if-!=
      var g/eax: grapheme <- read-from-gap-buffer in  # consume
      write-grapheme out, g
      break $next-token:case
    }
    # backquote
    {
      compare g, 0x60/single-quote
      break-if-!=
      var g/eax: grapheme <- read-from-gap-buffer in  # consume
      write-grapheme out, g
      break $next-token:case
    }
    # unquote
    {
      compare g, 0x2c/comma
      break-if-!=
      var g/eax: grapheme <- read-from-gap-buffer in  # consume
      write-grapheme out, g
      # check for unquote-splice
      {
        var g2/eax: grapheme <- peek-from-gap-buffer in
        compare g2, 0x40/at-sign
        break-if-!=
        g2 <- read-from-gap-buffer in
        write-grapheme out, g2
      }
      break $next-token:case
    }
    abort "unknown token type"
  }
  trace-higher trace
  var stream-storage: (stream byte 0x400)  # maximum possible token size (next-stream-token)
  var stream/eax: (addr stream byte) <- address stream-storage
  write stream, "=> "
  rewind-stream out
  write-stream stream, out
  trace trace, "tokenize", stream
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
  var stream-storage: (stream byte 0x40)
  var stream/esi: (addr stream byte) <- address stream-storage
  write stream, "=> "
  rewind-stream out
  write-stream stream, out
  trace trace, "tokenize", stream
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
  var stream-storage: (stream byte 0x40)
  var stream/esi: (addr stream byte) <- address stream-storage
  write stream, "=> "
  rewind-stream out
  write-stream stream, out
  trace trace, "tokenize", stream
}

fn next-number-token in: (addr gap-buffer), out: (addr stream byte), trace: (addr trace) {
  trace-text trace, "tokenize", "looking for a number"
  trace-lower trace
  $next-number-token:loop: {
    var done?/eax: boolean <- gap-buffer-scan-done? in
    compare done?, 0/false
    break-if-!=
    var g/eax: grapheme <- peek-from-gap-buffer in
    {
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
  var stream-storage: (stream byte 0x400)  # max-definition-size
  var stream/esi: (addr stream byte) <- address stream-storage
  write stream, "=> "
  rewind-stream out
  write-stream stream, out
  trace trace, "tokenize", stream
}

fn next-bracket-token g: grapheme, out: (addr stream byte), trace: (addr trace) {
  trace-text trace, "tokenize", "bracket"
  write-grapheme out, g
  var stream-storage: (stream byte 0x40)
  var stream/esi: (addr stream byte) <- address stream-storage
  write stream, "=> "
  rewind-stream out
  write-stream stream, out
  trace trace, "tokenize", stream
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
  var stream-storage: (stream byte 0x80)
  var stream/esi: (addr stream byte) <- address stream-storage
  write stream, "=> "
  rewind-stream out
  write-stream stream, out
  trace trace, "tokenize", stream
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

fn number-token? _in: (addr cell) -> _/eax: boolean {
  var in/eax: (addr cell) <- copy _in
  var in-data-ah/eax: (addr handle stream byte) <- get in, text-data
  var in-data/eax: (addr stream byte) <- lookup *in-data-ah
  rewind-stream in-data
  var g/eax: grapheme <- read-grapheme in-data
  var result/eax: boolean <- decimal-digit? g
  return result
}

fn bracket-token? _in: (addr cell) -> _/eax: boolean {
  var in/eax: (addr cell) <- copy _in
  {
    var in-type/eax: (addr int) <- get in, type
    compare *in-type, 3/stream
    break-if-!=
    # streams are never paren tokens
    return 0/false
  }
  var in-data-ah/eax: (addr handle stream byte) <- get in, text-data
  var in-data/eax: (addr stream byte) <- lookup *in-data-ah
  rewind-stream in-data
  var g/eax: grapheme <- read-grapheme in-data
  var result/eax: boolean <- bracket-grapheme? g
  return result
}

fn quote-token? _in: (addr cell) -> _/eax: boolean {
  var in/eax: (addr cell) <- copy _in
  var in-data-ah/eax: (addr handle stream byte) <- get in, text-data
  var in-data/eax: (addr stream byte) <- lookup *in-data-ah
  rewind-stream in-data
  var result/eax: boolean <- stream-data-equal? in-data, "'"
  return result
}

fn backquote-token? _in: (addr cell) -> _/eax: boolean {
  var in/eax: (addr cell) <- copy _in
  var in-data-ah/eax: (addr handle stream byte) <- get in, text-data
  var in-data/eax: (addr stream byte) <- lookup *in-data-ah
  rewind-stream in-data
  var result/eax: boolean <- stream-data-equal? in-data, "`"
  return result
}

fn unquote-token? _in: (addr cell) -> _/eax: boolean {
  var in/eax: (addr cell) <- copy _in
  var in-data-ah/eax: (addr handle stream byte) <- get in, text-data
  var in-data/eax: (addr stream byte) <- lookup *in-data-ah
  rewind-stream in-data
  var result/eax: boolean <- stream-data-equal? in-data, ","
  return result
}

fn unquote-splice-token? _in: (addr cell) -> _/eax: boolean {
  var in/eax: (addr cell) <- copy _in
  var in-data-ah/eax: (addr handle stream byte) <- get in, text-data
  var in-data/eax: (addr stream byte) <- lookup *in-data-ah
  rewind-stream in-data
  var result/eax: boolean <- stream-data-equal? in-data, ",@"
  return result
}

fn open-paren-token? _in: (addr cell) -> _/eax: boolean {
  var in/eax: (addr cell) <- copy _in
  var in-data-ah/eax: (addr handle stream byte) <- get in, text-data
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

fn close-paren-token? _in: (addr cell) -> _/eax: boolean {
  var in/eax: (addr cell) <- copy _in
  var in-data-ah/eax: (addr handle stream byte) <- get in, text-data
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

fn dot-token? _in: (addr cell) -> _/eax: boolean {
  var in/eax: (addr cell) <- copy _in
  var in-data-ah/eax: (addr handle stream byte) <- get in, text-data
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
  var tmp-storage: (handle cell)
  var tmp-ah/eax: (addr handle cell) <- address tmp-storage
  new-symbol tmp-ah, "."
  var tmp/eax: (addr cell) <- lookup *tmp-ah
  var result/eax: boolean <- dot-token? tmp
  check result, "F - test-dot-token"
}

fn stream-token? _in: (addr cell) -> _/eax: boolean {
  var in/eax: (addr cell) <- copy _in
  var in-type/eax: (addr int) <- get in, type
  compare *in-type, 3/stream
  {
    break-if-=
    return 0/false
  }
  return 1/true
}

fn comment-token? _in: (addr cell) -> _/eax: boolean {
  var in/eax: (addr cell) <- copy _in
  var in-data-ah/eax: (addr handle stream byte) <- get in, text-data
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
