fn print-cell _in: (addr handle cell), out: (addr stream byte), trace: (addr trace) {
  trace-text trace, "print", "print"
  trace-lower trace
  var in/eax: (addr handle cell) <- copy _in
  var in-addr/eax: (addr cell) <- lookup *in
  {
    var nil?/eax: boolean <- nil? in-addr
    compare nil?, 0/false
    break-if-=
    write out, "()"
    trace-higher trace
    return
  }
  var in-type/ecx: (addr int) <- get in-addr, type
  compare *in-type, 0/pair
  {
    break-if-!=
    print-list in-addr, out, trace
    trace-higher trace
    return
  }
  compare *in-type, 1/number
  {
    break-if-!=
    print-number in-addr, out, trace
    trace-higher trace
    return
  }
  compare *in-type, 2/symbol
  {
    break-if-!=
    print-symbol in-addr, out, trace
    trace-higher trace
    return
  }
}

# debug helper
fn dump-cell in-ah: (addr handle cell) {
  var stream-storage: (stream byte 0x40)
  var stream/edx: (addr stream byte) <- address stream-storage
  print-cell in-ah, stream, 0/no-trace
  var d1/eax: int <- copy 0
  var d2/ecx: int <- copy 0
  d1, d2 <- draw-stream-wrapping-right-then-down 0/screen, stream, 0/xmin, 0/ymin, 0x80/xmax, 0x30/ymax, 0/x, 0/y, 7/fg, 0/bg
}

fn print-symbol _in: (addr cell), out: (addr stream byte), trace: (addr trace) {
  trace-text trace, "print", "symbol"
  var in/esi: (addr cell) <- copy _in
  var data-ah/eax: (addr handle stream byte) <- get in, text-data
  var _data/eax: (addr stream byte) <- lookup *data-ah
  var data/esi: (addr stream byte) <- copy _data
  rewind-stream data
  write-stream out, data
  # trace
  rewind-stream data
  var stream-storage: (stream byte 0x40)
  var stream/ecx: (addr stream byte) <- address stream-storage
  write stream, "=> symbol "
  write-stream stream, data
  trace trace, "print", stream
}

fn print-number _in: (addr cell), out: (addr stream byte), trace: (addr trace) {
  var in/esi: (addr cell) <- copy _in
  var val/eax: (addr float) <- get in, number-data
  write-float-decimal-approximate out, *val, 3/precision
  # trace
  var stream-storage: (stream byte 0x40)
  var stream/ecx: (addr stream byte) <- address stream-storage
  write stream, "=> number "
  write-float-decimal-approximate stream, *val, 3/precision
  trace trace, "print", stream
}

fn print-list _in: (addr cell), out: (addr stream byte), trace: (addr trace) {
  var curr/esi: (addr cell) <- copy _in
  write out, "("
  $print-list:loop: {
    var left/ecx: (addr handle cell) <- get curr, left
    print-cell left, out, trace
    var right/ecx: (addr handle cell) <- get curr, right
    var right-addr/eax: (addr cell) <- lookup *right
    {
      compare right-addr, 0
      break-if-!=
      abort "null encountered"
    }
    {
      var right-nil?/eax: boolean <- nil? right-addr
      compare right-nil?, 0/false
      {
        break-if-=
        trace-text trace, "print", "right is null"
        break $print-list:loop
      }
    }
    write out, " "
    var right-type-addr/edx: (addr int) <- get right-addr, type
    {
      compare *right-type-addr, 0/pair
      break-if-=
      write out, ". "
      print-cell right, out, trace
      break $print-list:loop
    }
    curr <- copy right-addr
    loop
  }
  write out, ")"
}

# Most lisps intern nil, but we don't really have globals yet, so we'll be
# less efficient for now.
fn nil? _in: (addr cell) -> _/eax: boolean {
  var in/esi: (addr cell) <- copy _in
  # if type != pair, return false
  var type/eax: (addr int) <- get in, type
  compare *type, 0/pair
  {
    break-if-=
    return 0/false
  }
  # if left != null, return false
  var left-ah/eax: (addr handle cell) <- get in, left
  var left/eax: (addr cell) <- lookup *left-ah
  compare left, 0
  {
    break-if-=
    return 0/false
  }
  # if right != null, return false
  var right-ah/eax: (addr handle cell) <- get in, right
  var right/eax: (addr cell) <- lookup *right-ah
  compare right, 0
  {
    break-if-=
    return 0/false
  }
  return 1/true
}

fn test-print-cell-zero {
  var num-storage: (handle cell)
  var num/esi: (addr handle cell) <- address num-storage
  new-integer num, 0
  var out-storage: (stream byte 0x40)
  var out/edi: (addr stream byte) <- address out-storage
  print-cell num, out, 0/no-trace
  check-stream-equal out, "0", "F - test-print-cell-zero"
}

fn test-print-cell-integer {
  var num-storage: (handle cell)
  var num/esi: (addr handle cell) <- address num-storage
  new-integer num, 1
  var out-storage: (stream byte 0x40)
  var out/edi: (addr stream byte) <- address out-storage
  print-cell num, out, 0/no-trace
  check-stream-equal out, "1", "F - test-print-cell-integer"
}

fn test-print-cell-integer-2 {
  var num-storage: (handle cell)
  var num/esi: (addr handle cell) <- address num-storage
  new-integer num, 0x30
  var out-storage: (stream byte 0x40)
  var out/edi: (addr stream byte) <- address out-storage
  print-cell num, out, 0/no-trace
  check-stream-equal out, "48", "F - test-print-cell-integer-2"
}

fn test-print-cell-fraction {
  var num-storage: (handle cell)
  var num/esi: (addr handle cell) <- address num-storage
  var val/xmm0: float <- rational 1, 2
  new-float num, val
  var out-storage: (stream byte 0x40)
  var out/edi: (addr stream byte) <- address out-storage
  print-cell num, out, 0/no-trace
  check-stream-equal out, "0.5", "F - test-print-cell-fraction"
}

fn test-print-cell-symbol {
  var sym-storage: (handle cell)
  var sym/esi: (addr handle cell) <- address sym-storage
  new-symbol sym, "abc"
  var out-storage: (stream byte 0x40)
  var out/edi: (addr stream byte) <- address out-storage
  print-cell sym, out, 0/no-trace
  check-stream-equal out, "abc", "F - test-print-cell-symbol"
}

fn test-print-cell-nil-list {
  var nil-storage: (handle cell)
  var nil/esi: (addr handle cell) <- address nil-storage
  allocate-pair nil
  var out-storage: (stream byte 0x40)
  var out/edi: (addr stream byte) <- address out-storage
  print-cell nil, out, 0/no-trace
  check-stream-equal out, "()", "F - test-print-cell-nil-list"
}

fn test-print-cell-singleton-list {
  # list
  var left-storage: (handle cell)
  var left/ecx: (addr handle cell) <- address left-storage
  new-symbol left, "abc"
  var nil-storage: (handle cell)
  var nil/edx: (addr handle cell) <- address nil-storage
  allocate-pair nil
  var list-storage: (handle cell)
  var list/esi: (addr handle cell) <- address list-storage
  new-pair list, *left, *nil
  #
  var out-storage: (stream byte 0x40)
  var out/edi: (addr stream byte) <- address out-storage
  print-cell list, out, 0/no-trace
  check-stream-equal out, "(abc)", "F - test-print-cell-singleton-list"
}

fn test-print-cell-list {
  # list = cons "abc", nil
  var left-storage: (handle cell)
  var left/ecx: (addr handle cell) <- address left-storage
  new-symbol left, "abc"
  var nil-storage: (handle cell)
  var nil/edx: (addr handle cell) <- address nil-storage
  allocate-pair nil
  var list-storage: (handle cell)
  var list/esi: (addr handle cell) <- address list-storage
  new-pair list, *left, *nil
  # list = cons 64, list
  new-integer left, 0x40
  new-pair list, *left, *list
  #
  var out-storage: (stream byte 0x40)
  var out/edi: (addr stream byte) <- address out-storage
  print-cell list, out, 0/no-trace
  check-stream-equal out, "(64 abc)", "F - test-print-cell-list"
}

fn test-print-cell-list-of-nil {
  # list = cons "abc", nil
  var left-storage: (handle cell)
  var left/ecx: (addr handle cell) <- address left-storage
  allocate-pair left
  var nil-storage: (handle cell)
  var nil/edx: (addr handle cell) <- address nil-storage
  allocate-pair nil
  var list-storage: (handle cell)
  var list/esi: (addr handle cell) <- address list-storage
  new-pair list, *left, *nil
  # list = cons 64, list
  new-integer left, 0x40
  new-pair list, *left, *list
  #
  var out-storage: (stream byte 0x40)
  var out/edi: (addr stream byte) <- address out-storage
  print-cell list, out, 0/no-trace
  check-stream-equal out, "(64 ())", "F - test-print-cell-list-nil"
}

fn test-print-dotted-list {
  # list = cons 64, "abc"
  var left-storage: (handle cell)
  var left/ecx: (addr handle cell) <- address left-storage
  new-symbol left, "abc"
  var right-storage: (handle cell)
  var right/edx: (addr handle cell) <- address right-storage
  new-integer right, 0x40
  var list-storage: (handle cell)
  var list/esi: (addr handle cell) <- address list-storage
  new-pair list, *left, *right
  #
  var out-storage: (stream byte 0x40)
  var out/edi: (addr stream byte) <- address out-storage
  print-cell list, out, 0/no-trace
  check-stream-equal out, "(abc . 64)", "F - test-print-dotted-list"
}
