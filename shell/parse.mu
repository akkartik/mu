fn parse-input tokens: (addr stream token), out: (addr handle cell), trace: (addr trace) {
  rewind-stream tokens
  var empty?/eax: boolean <- stream-empty? tokens
  compare empty?, 0/false
  {
    break-if-=
    error trace, "nothing to parse"
    return
  }
  var close-paren?/eax: boolean <- copy 0/false
  var dummy?/ecx: boolean <- copy 0/false
  close-paren?, dummy? <- parse-sexpression tokens, out, trace
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

# return values:
#   unmatched close-paren encountered?
#   dot encountered? (only used internally by recursive calls)
fn parse-sexpression tokens: (addr stream token), _out: (addr handle cell), trace: (addr trace) -> _/eax: boolean, _/ecx: boolean {
  trace-text trace, "parse", "parse"
  trace-lower trace
  var curr-token-storage: token
  var curr-token/ecx: (addr token) <- address curr-token-storage
  var empty?/eax: boolean <- stream-empty? tokens
  compare empty?, 0/false
  {
    break-if-=
    error trace, "end of stream; never found a balancing ')'"
    trace-higher trace
    return 1/true, 0/false
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
      var left-ah/edx: (addr handle cell) <- get out-addr, left
      new-symbol left-ah, "'"
      var right-ah/edx: (addr handle cell) <- get out-addr, right
      var close-paren?/eax: boolean <- copy 0/false
      var dot?/ecx: boolean <- copy 0/false
      close-paren?, dot? <- parse-sexpression tokens, right-ah, trace
      trace-higher trace
      return close-paren?, dot?
    }
    # backquote quote -> parse as list with a special car
    var backquote-token?/eax: boolean <- backquote-token? curr-token
    compare backquote-token?, 0/false
    {
      break-if-=
      var out/edi: (addr handle cell) <- copy _out
      allocate-pair out
      var out-addr/eax: (addr cell) <- lookup *out
      var left-ah/edx: (addr handle cell) <- get out-addr, left
      new-symbol left-ah, "`"
      var right-ah/edx: (addr handle cell) <- get out-addr, right
      var close-paren?/eax: boolean <- copy 0/false
      var dot?/ecx: boolean <- copy 0/false
      close-paren?, dot? <- parse-sexpression tokens, right-ah, trace
      trace-higher trace
      return close-paren?, dot?
    }
    # unquote -> parse as list with a special car
    var unquote-token?/eax: boolean <- unquote-token? curr-token
    compare unquote-token?, 0/false
    {
      break-if-=
      var out/edi: (addr handle cell) <- copy _out
      allocate-pair out
      var out-addr/eax: (addr cell) <- lookup *out
      var left-ah/edx: (addr handle cell) <- get out-addr, left
      new-symbol left-ah, ","
      var right-ah/edx: (addr handle cell) <- get out-addr, right
      var close-paren?/eax: boolean <- copy 0/false
      var dot?/ecx: boolean <- copy 0/false
      close-paren?, dot? <- parse-sexpression tokens, right-ah, trace
      trace-higher trace
      return close-paren?, dot?
    }
    # unquote-splice -> parse as list with a special car
    var unquote-splice-token?/eax: boolean <- unquote-splice-token? curr-token
    compare unquote-splice-token?, 0/false
    {
      break-if-=
      var out/edi: (addr handle cell) <- copy _out
      allocate-pair out
      var out-addr/eax: (addr cell) <- lookup *out
      var left-ah/edx: (addr handle cell) <- get out-addr, left
      new-symbol left-ah, ",@"
      var right-ah/edx: (addr handle cell) <- get out-addr, right
      var close-paren?/eax: boolean <- copy 0/false
      var dot?/ecx: boolean <- copy 0/false
      close-paren?, dot? <- parse-sexpression tokens, right-ah, trace
      trace-higher trace
      return close-paren?, dot?
    }
    # dot -> return
    var dot?/eax: boolean <- dot-token? curr-token
    compare dot?, 0/false
    {
      break-if-=
      trace-higher trace
      return 0/false, 1/true
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
      var left/edx: (addr handle cell) <- get curr-addr, left
      {
        var close-paren?/eax: boolean <- copy 0/false
        var dot?/ecx: boolean <- copy 0/false
        close-paren?, dot? <- parse-sexpression tokens, left, trace
        {
          compare dot?, 0/false
          break-if-=
          error trace, "'.' cannot be at the start of a list"
          return 1/true, dot?
        }
        compare close-paren?, 0/false
        break-if-!=
        var curr-addr/eax: (addr cell) <- lookup *curr
        curr <- get curr-addr, right
        var tmp-storage: (handle cell)
        var tmp/edx: (addr handle cell) <- address tmp-storage
        $parse-sexpression:list-loop: {
          var close-paren?/eax: boolean <- copy 0/false
          var dot?/ecx: boolean <- copy 0/false
          close-paren?, dot? <- parse-sexpression tokens, tmp, trace
          # '.' -> clean up right here and return
          compare dot?, 0/false
          {
            break-if-=
            parse-dot-tail tokens, curr, trace
            return 0/false, 0/false
          }
          allocate-pair curr
          # ')' -> return
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
    # close paren -> return
    var close-paren?/eax: boolean <- close-paren-token? curr-token
    compare close-paren?, 0/false
    {
      break-if-=
      trace-higher trace
      return 1/true, 0/false
    }
    # otherwise abort
    var stream-storage: (stream byte 0x400)
    var stream/edx: (addr stream byte) <- address stream-storage
    write stream, "unexpected token "
    var curr-token-data-ah/eax: (addr handle stream byte) <- get curr-token, text-data
    var curr-token-data/eax: (addr stream byte) <- lookup *curr-token-data-ah
    rewind-stream curr-token-data
    write-stream stream, curr-token-data
    error-stream trace, stream
  }
  trace-higher trace
  return 0/false, 0/false
}

fn parse-atom _curr-token: (addr token), _out: (addr handle cell), trace: (addr trace) {
  trace-text trace, "parse", "parse atom"
  var curr-token/ecx: (addr token) <- copy _curr-token
  var curr-token-data-ah/eax: (addr handle stream byte) <- get curr-token, text-data
  var _curr-token-data/eax: (addr stream byte) <- lookup *curr-token-data-ah
  var curr-token-data/esi: (addr stream byte) <- copy _curr-token-data
  trace trace, "parse", curr-token-data
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
      {
        var should-trace?/eax: boolean <- should-trace? trace
        compare should-trace?, 0/false
      }
      break-if-=
      var stream-storage: (stream byte 0x400)
      var stream/ecx: (addr stream byte) <- address stream-storage
      write stream, "=> number "
      var nested-trace-storage: trace
      var nested-trace/edi: (addr trace) <- address nested-trace-storage
      initialize-trace nested-trace, 1/only-errors, 0x10/capacity, 0/visible
      print-number out-addr, stream, nested-trace
      trace trace, "parse", stream
    }
    return
  }
  # default: copy either to a symbol or a stream
  # stream token -> literal
  var stream-token?/eax: boolean <- stream-token? curr-token
  compare stream-token?, 0/false
  {
    break-if-=
    allocate-stream _out
  }
  compare stream-token?, 0/false
  {
    break-if-!=
    allocate-symbol _out
  }
  # copy token data
  var out/eax: (addr handle cell) <- copy _out
  var out-addr/eax: (addr cell) <- lookup *out
  var curr-token-data-ah/ecx: (addr handle stream byte) <- get curr-token, text-data
  var dest-ah/edx: (addr handle stream byte) <- get out-addr, text-data
  copy-object curr-token-data-ah, dest-ah
  {
    {
      var should-trace?/eax: boolean <- should-trace? trace
      compare should-trace?, 0/false
    }
    break-if-=
    var stream-storage: (stream byte 0x400)
    var stream/ecx: (addr stream byte) <- address stream-storage
    write stream, "=> symbol "
    var nested-trace-storage: trace
    var nested-trace/edi: (addr trace) <- address nested-trace-storage
    initialize-trace nested-trace, 1/only-errors, 0x10/capacity, 0/visible
    print-symbol out-addr, stream, nested-trace
    trace trace, "parse", stream
  }
}

fn parse-dot-tail tokens: (addr stream token), _out: (addr handle cell), trace: (addr trace) {
  var out/edi: (addr handle cell) <- copy _out
  var close-paren?/eax: boolean <- copy 0/false
  var dot?/ecx: boolean <- copy 0/false
  close-paren?, dot? <- parse-sexpression tokens, out, trace
  compare close-paren?, 0/false
  {
    break-if-=
    error trace, "'. )' makes no sense"
    return
  }
  compare dot?, 0/false
  {
    break-if-=
    error trace, "'. .' makes no sense"
    return
  }
  #
  var dummy: (handle cell)
  var dummy-ah/edi: (addr handle cell) <- address dummy
  close-paren?, dot? <- parse-sexpression tokens, dummy-ah, trace
  compare close-paren?, 0/false
  {
    break-if-!=
    error trace, "cannot have multiple expressions between '.' and ')'"
    return
  }
  compare dot?, 0/false
  {
    break-if-=
    error trace, "cannot have two dots in a single list"
    return
  }
}
