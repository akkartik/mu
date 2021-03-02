# We reuse the cell data structure for tokenization
# Token cells are special, though. They have no type, they're always atoms,
# they always have text-data.

fn tokenize in: (addr gap-buffer), out: (addr stream cell), trace: (addr trace) {
  trace-text trace, "read", "tokenize"
  trace-lower trace
  rewind-gap-buffer in
  var token-storage: cell
  var token/edx: (addr cell) <- address token-storage
  {
    var done?/eax: boolean <- gap-buffer-scan-done? in
    compare done?, 0/false
    break-if-!=
    # initialize token data each iteration to avoid aliasing
    var dest-ah/eax: (addr handle stream byte) <- get token, text-data
    populate-stream dest-ah, 0x40/max-token-size
    #
    next-token in, token, trace
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

fn next-token in: (addr gap-buffer), _out-cell: (addr cell), trace: (addr trace) {
  trace-text trace, "read", "next-token"
  trace-lower trace
  var out-cell/eax: (addr cell) <- copy _out-cell
  var out-ah/eax: (addr handle stream byte) <- get out-cell, text-data
  var _out/eax: (addr stream byte) <- lookup *out-ah
  var out/edi: (addr stream byte) <- copy _out
  $next-token:body: {
    clear-stream out
    skip-whitespace-from-gap-buffer in
    var g/eax: grapheme <- peek-from-gap-buffer in
    {
      var stream-storage: (stream byte 0x40)
      var stream/esi: (addr stream byte) <- address stream-storage
      write stream, "next: "
      var gval/eax: int <- copy g
      write-int32-hex stream, gval
      trace trace, "read", stream
    }
    # digit
    {
      var digit?/eax: boolean <- is-decimal-digit? g
      compare digit?, 0/false
      break-if-=
      next-number-token in, out, trace
      break $next-token:body
    }
    # other symbol char
    {
      var symbol?/eax: boolean <- is-symbol-grapheme? g
      compare symbol?, 0/false
      break-if-=
      next-symbol-token in, out, trace
      break $next-token:body
    }
    # brackets are always single-char tokens
    {
      var bracket?/eax: boolean <- is-bracket-grapheme? g
      compare bracket?, 0/false
      break-if-=
      var g/eax: grapheme <- read-from-gap-buffer in
      next-bracket-token g, out, trace
      break $next-token:body
    }
  }
  trace-higher trace
  var stream-storage: (stream byte 0x40)
  var stream/eax: (addr stream byte) <- address stream-storage
  write stream, "=> "
  rewind-stream out
  write-stream stream, out
  trace trace, "read", stream
}

fn next-symbol-token in: (addr gap-buffer), out: (addr stream byte), trace: (addr trace) {
  trace-text trace, "read", "looking for a symbol"
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
      trace trace, "read", stream
    }
    # if non-symbol, return
    {
      var symbol-grapheme?/eax: boolean <- is-symbol-grapheme? g
      compare symbol-grapheme?, 0/false
      break-if-!=
      trace-text trace, "read", "stop"
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
  trace trace, "read", stream
}

fn next-number-token in: (addr gap-buffer), out: (addr stream byte), trace: (addr trace) {
  trace-text trace, "read", "looking for a number"
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
      trace trace, "read", stream
    }
    # if not symbol grapheme, return
    {
      var symbol-grapheme?/eax: boolean <- is-symbol-grapheme? g
      compare symbol-grapheme?, 0/false
      break-if-!=
      trace-text trace, "read", "stop"
      break $next-number-token:loop
    }
    # if not digit grapheme, abort
    {
      var digit?/eax: boolean <- is-decimal-digit? g
      compare digit?, 0/false
      break-if-!=
      error trace, "invalid number"
      return
    }
    trace-text trace, "read", "append"
    var g/eax: grapheme <- read-from-gap-buffer in
    write-grapheme out, g
    loop
  }
  trace-higher trace
}

fn next-bracket-token g: grapheme, out: (addr stream byte), trace: (addr trace) {
  trace-text trace, "read", "bracket"
  write-grapheme out, g
  var stream-storage: (stream byte 0x40)
  var stream/esi: (addr stream byte) <- address stream-storage
  write stream, "=> "
  rewind-stream out
  write-stream stream, out
  trace trace, "read", stream
}

fn is-symbol-grapheme? g: grapheme -> _/eax: boolean {
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
  compare g, 0x2c/comma
  {
    break-if-!=
    return 0/false
  }
  # '-' is a symbol char
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
  compare g, 0x40/at-sign
  {
    break-if-!=
    return 0/false
  }
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

fn is-bracket-grapheme? g: grapheme -> _/eax: boolean {
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

fn is-number-token? _in: (addr cell) -> _/eax: boolean {
  var in/eax: (addr cell) <- copy _in
  var in-data-ah/eax: (addr handle stream byte) <- get in, text-data
  var in-data/eax: (addr stream byte) <- lookup *in-data-ah
  rewind-stream in-data
  var g/eax: grapheme <- read-grapheme in-data
  var result/eax: boolean <- is-decimal-digit? g
  return result
}

fn is-bracket-token? _in: (addr cell) -> _/eax: boolean {
  var in/eax: (addr cell) <- copy _in
  var in-data-ah/eax: (addr handle stream byte) <- get in, text-data
  var in-data/eax: (addr stream byte) <- lookup *in-data-ah
  rewind-stream in-data
  var g/eax: grapheme <- read-grapheme in-data
  var result/eax: boolean <- is-bracket-grapheme? g
  return result
}

fn is-open-paren-token? _in: (addr cell) -> _/eax: boolean {
  var in/eax: (addr cell) <- copy _in
  var in-data-ah/eax: (addr handle stream byte) <- get in, text-data
  var in-data/eax: (addr stream byte) <- lookup *in-data-ah
  rewind-stream in-data
  var g/eax: grapheme <- read-grapheme in-data
  compare g, 0x28/open-paren
  {
    break-if-!=
    return 1/true
  }
  return 0/false
}

fn is-close-paren-token? _in: (addr cell) -> _/eax: boolean {
  var in/eax: (addr cell) <- copy _in
  var in-data-ah/eax: (addr handle stream byte) <- get in, text-data
  var in-data/eax: (addr stream byte) <- lookup *in-data-ah
  rewind-stream in-data
  var g/eax: grapheme <- read-grapheme in-data
  compare g, 0x29/open-paren
  {
    break-if-!=
    return 1/true
  }
  return 0/false
}
