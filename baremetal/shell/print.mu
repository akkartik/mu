fn print-cell _in: (addr handle cell), out: (addr stream byte), trace: (addr trace) {
  clear-stream out
  var in/eax: (addr handle cell) <- copy _in
  var in-addr/eax: (addr cell) <- lookup *in
  var in-type/ecx: (addr int) <- get in-addr, type
  compare *in-type, 1/number
  {
    break-if-!=
    print-number in-addr, out, trace
    return
  }
  compare *in-type, 2/symbol
  {
    break-if-!=
    print-symbol in-addr, out, trace
    return
  }
}

fn print-symbol _in: (addr cell), out: (addr stream byte), trace: (addr trace) {
  {
    compare trace, 0
    break-if-=
    trace-text trace, "print", "symbol"
  }
  var in/esi: (addr cell) <- copy _in
  var data-ah/eax: (addr handle stream byte) <- get in, text-data
  var _data/eax: (addr stream byte) <- lookup *data-ah
  var data/esi: (addr stream byte) <- copy _data
  rewind-stream data
  {
    var done?/eax: boolean <- stream-empty? data
    compare done?, 0/false
    break-if-!=
    var g/eax: grapheme <- read-grapheme data
    write-grapheme out, g
    loop
  }
}

fn print-number _in: (addr cell), out: (addr stream byte), trace: (addr trace) {
  {
    compare trace, 0
    break-if-=
    trace-text trace, "print", "number"
  }
  var in/esi: (addr cell) <- copy _in
  var val/eax: (addr float) <- get in, number-data
  write-float-decimal-approximate out, *val, 3/precision
}
