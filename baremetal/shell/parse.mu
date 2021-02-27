fn parse-sexpression tokens: (addr stream cell), _out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "read", "parse"
  trace-lower trace
  rewind-stream tokens
  var curr-token-storage: cell
  var curr-token/ecx: (addr cell) <- address curr-token-storage
  {
    var done?/eax: boolean <- stream-empty? tokens
    compare done?, 0/false
    break-if-!=
    read-from-stream tokens, curr-token
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
        trace-higher trace
        write stream, "=> number "
        print-number out-addr, stream, 0/no-trace
        trace trace, "read", stream
      }
      return
    }
    # Temporary default: just convert first token to symbol and return it.
    var out/eax: (addr handle cell) <- copy _out
    allocate out
    var out-addr/eax: (addr cell) <- lookup *out
    copy-object curr-token, out-addr
    var type/ecx: (addr int) <- get out-addr, type
    copy-to *type, 2/symbol
    return
  }
  abort "unexpected tokens at end; only type in a single expression at a time"
}
