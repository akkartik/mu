fn parse-input tokens: (addr stream cell), out: (addr handle cell), trace: (addr trace) {
  rewind-stream tokens
  var empty?/eax: boolean <- stream-empty? tokens
  compare empty?, 0/false
  {
    break-if-=
    error trace, "nothing to parse"
    return
  }
  var close-paren?/eax: boolean <- parse-sexpression tokens, out, trace
  {
    compare close-paren?, 0/false
    break-if-=
    error trace, "')' is not a valid expression"
    return
  }
  {
    var empty?/eax: boolean <- stream-empty? tokens
    compare empty?, 0/false
    break-if-!=
    error trace, "unexpected tokens at end; only type in a single expression at a time"
  }
}

# return value: true if close-paren was encountered
fn parse-sexpression tokens: (addr stream cell), _out: (addr handle cell), trace: (addr trace) -> _/eax: boolean {
  trace-text trace, "read", "parse"
  trace-lower trace
  var curr-token-storage: cell
  var curr-token/ecx: (addr cell) <- address curr-token-storage
  var empty?/eax: boolean <- stream-empty? tokens
  compare empty?, 0/false
  {
    break-if-=
    error trace, "end of stream; never found a balancing ')'"
    return 1/true
  }
  read-from-stream tokens, curr-token
  $parse-sexpression:type-check: {
    # single quote -> parse as list with a special car
    var quote-token?/eax: boolean <- quote-token? curr-token
    compare quote-token?, 0/false
    {
      break-if-=
      var out/edi: (addr handle cell) <- copy _out
      allocate-pair out
      var out-addr/eax: (addr cell) <- lookup *out
      var left-ah/ecx: (addr handle cell) <- get out-addr, left
      new-symbol left-ah, "'"
      var right-ah/ecx: (addr handle cell) <- get out-addr, right
      var result/eax: boolean <- parse-sexpression tokens, right-ah, trace
      return result
    }
    # not bracket -> parse atom
    var bracket-token?/eax: boolean <- bracket-token? curr-token
    compare bracket-token?, 0/false
    {
      break-if-!=
      parse-atom curr-token, _out, trace
      break $parse-sexpression:type-check
    }
    # open paren -> parse list
    var open-paren?/eax: boolean <- open-paren-token? curr-token
    compare open-paren?, 0/false
    {
      break-if-=
      var curr/esi: (addr handle cell) <- copy _out
      allocate-pair curr
      var curr-addr/eax: (addr cell) <- lookup *curr
      var left/ecx: (addr handle cell) <- get curr-addr, left
      {
        var close-paren?/eax: boolean <- parse-sexpression tokens, left, trace
        compare close-paren?, 0/false
        break-if-!=
        var curr-addr/eax: (addr cell) <- lookup *curr
        curr <- get curr-addr, right
        var tmp-storage: (handle cell)
        var tmp/edx: (addr handle cell) <- address tmp-storage
        $parse-sexpression:list-loop: {
          var close-paren?/eax: boolean <- parse-sexpression tokens, tmp, trace
          allocate-pair curr
          compare close-paren?, 0/false
          break-if-!=
          var curr-addr/eax: (addr cell) <- lookup *curr
          var left/ecx: (addr handle cell) <- get curr-addr, left
          copy-object tmp, left
          #
          curr <- get curr-addr, right
          loop
        }
      }
      break $parse-sexpression:type-check
    }
    # close paren -> parse list
    var close-paren?/eax: boolean <- close-paren-token? curr-token
    compare close-paren?, 0/false
    {
      break-if-=
      trace-higher trace
      return 1/true
    }
    # otherwise abort
    var stream-storage: (stream byte 0x40)
    var stream/edx: (addr stream byte) <- address stream-storage
    write stream, "unexpected token "
    var curr-token-data-ah/eax: (addr handle stream byte) <- get curr-token, text-data
    var curr-token-data/eax: (addr stream byte) <- lookup *curr-token-data-ah
    rewind-stream curr-token-data
    write-stream stream, curr-token-data
    trace trace, "error", stream
  }
  trace-higher trace
  return 0/false
}

fn parse-atom _curr-token: (addr cell), _out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "read", "parse atom"
  var curr-token/ecx: (addr cell) <- copy _curr-token
  var curr-token-data-ah/eax: (addr handle stream byte) <- get curr-token, text-data
  var _curr-token-data/eax: (addr stream byte) <- lookup *curr-token-data-ah
  var curr-token-data/esi: (addr stream byte) <- copy _curr-token-data
  trace trace, "read", curr-token-data
  # number
  var number-token?/eax: boolean <- number-token? curr-token
  compare number-token?, 0/false
  {
    break-if-=
    rewind-stream curr-token-data
    var _val/eax: int <- parse-decimal-int-from-stream curr-token-data
    var val/ecx: int <- copy _val
    var val-float/xmm0: float <- convert val
    allocate-number _out
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
  allocate-symbol _out
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
