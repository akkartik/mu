fn parse-input tokens: (addr stream cell), out: (addr handle cell), trace: (addr trace) {
  rewind-stream tokens
  parse-sexpression tokens, out, trace
  var empty?/eax: boolean <- stream-empty? tokens
  compare empty?, 0/false
  break-if-!=
  error trace, "unexpected tokens at end; only type in a single expression at a time"
}

fn parse-sexpression tokens: (addr stream cell), _out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "read", "parse"
  trace-lower trace
  var curr-token-storage: cell
  var curr-token/ecx: (addr cell) <- address curr-token-storage
  var empty?/eax: boolean <- stream-empty? tokens
  compare empty?, 0/false
  {
    break-if-=
    error trace, "nothing to parse"
    return
  }
  read-from-stream tokens, curr-token
  parse-atom curr-token, _out, trace
  trace-higher trace
}

fn parse-atom _curr-token: (addr cell), _out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "read", "parse atom"
  var curr-token/ecx: (addr cell) <- copy _curr-token
  var curr-token-data-ah/eax: (addr handle stream byte) <- get curr-token, text-data
  var _curr-token-data/eax: (addr stream byte) <- lookup *curr-token-data-ah
  var curr-token-data/esi: (addr stream byte) <- copy _curr-token-data
  trace trace, "read", curr-token-data
  # number
  var is-number-token?/eax: boolean <- is-number-token? curr-token
  compare is-number-token?, 0/false
  {
    break-if-=
    rewind-stream curr-token-data
    var _val/eax: int <- parse-decimal-int-from-stream curr-token-data
    var val/ecx: int <- copy _val
    var val-float/xmm0: float <- convert val
    new-number _out
    var out/eax: (addr handle cell) <- copy _out
    var out-addr/eax: (addr cell) <- lookup *out
    var dest/edi: (addr float) <- get out-addr, number-data
    copy-to *dest, val-float
    {
      var stream-storage: (stream byte 0x40)
      var stream/ecx: (addr stream byte) <- address stream-storage
      write stream, "=> number "
      print-number out-addr, stream, 0/no-trace
      trace trace, "read", stream
    }
    return
  }
  # default: symbol
  # just copy token data
  new-symbol _out
  var out/eax: (addr handle cell) <- copy _out
  var out-addr/eax: (addr cell) <- lookup *out
  var curr-token-data-ah/ecx: (addr handle stream byte) <- get curr-token, text-data
  var dest-ah/edx: (addr handle stream byte) <- get out-addr, text-data
  copy-object curr-token-data-ah, dest-ah
  {
    var stream-storage: (stream byte 0x40)
    var stream/ecx: (addr stream byte) <- address stream-storage
    write stream, "=> symbol "
    print-symbol out-addr, stream, 0/no-trace
    trace trace, "read", stream
  }
}
