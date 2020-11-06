
## Rendering values

fn render-value screen: (addr screen), _val: (addr value), max-width: int {
$render-value:body: {
  var val/esi: (addr value) <- copy _val
  var val-type/ecx: (addr int) <- get val, type
  # per-type rendering logic goes here
  compare *val-type, 1  # string
  {
    break-if-!=
    var val-ah/eax: (addr handle array byte) <- get val, text-data
    var val-string/eax: (addr array byte) <- lookup *val-ah
    compare val-string, 0
    break-if-=
    var orig-len/ecx: int <- length val-string
    var truncated: (handle array byte)
    var truncated-ah/esi: (addr handle array byte) <- address truncated
    substring val-string, 0, 0xc, truncated-ah
    var truncated-string/eax: (addr array byte) <- lookup *truncated-ah
#?     {
#?       var foo/eax: int <- copy truncated-string
#?       print-int32-hex 0, foo
#?       print-string 0, "\n"
#?     }
    var len/edx: int <- length truncated-string
    start-color screen, 0xf2, 7
    print-code-point screen, 0x275d  # open-quote
    print-string screen, truncated-string
    compare len, orig-len
    {
      break-if-=
      print-code-point screen, 0x2026  # ellipses
    }
    print-code-point screen, 0x275e  # close-quote
    reset-formatting screen
    break $render-value:body
  }
  compare *val-type, 2  # array
  {
    break-if-!=
    var val-ah/eax: (addr handle array value) <- get val, array-data
    var val-array/eax: (addr array value) <- lookup *val-ah
    render-array screen, val-array
    break $render-value:body
  }
  compare *val-type, 3  # file
  {
    break-if-!=
    var val-ah/eax: (addr handle buffered-file) <- get val, file-data
    var val-file/eax: (addr buffered-file) <- lookup *val-ah
    start-color screen, 0, 7
    # TODO
    print-string screen, " FILE "
    break $render-value:body
  }
  compare *val-type, 4  # file
  {
    break-if-!=
    var val-ah/eax: (addr handle screen) <- get val, screen-data
    var val-screen/eax: (addr screen) <- lookup *val-ah
    start-color screen, 0, 7
    # TODO
    print-string screen, " SCREEN "
    break $render-value:body
  }
  # render ints by default for now
  var val-int/eax: (addr int) <- get val, int-data
  render-integer screen, *val-int, max-width
}
}

# synaesthesia
fn render-integer screen: (addr screen), val: int, max-width: int {
$render-integer:body: {
  # if max-width is 0, we're inside an array. No coloring.
  compare max-width, 0
  {
    break-if-!=
    print-int32-decimal screen, val
    break $render-integer:body
  }
  var bg/eax: int <- hash-color val
  var fg/ecx: int <- copy 7
  {
    compare bg, 2
    break-if-!=
    fg <- copy 0
  }
  {
    compare bg, 3
    break-if-!=
    fg <- copy 0
  }
  {
    compare bg, 6
    break-if-!=
    fg <- copy 0
  }
  start-color screen, fg, bg
  print-grapheme screen, 0x20  # space
  print-int32-decimal-right-justified screen, val, max-width
  print-grapheme screen, 0x20  # space
}
}

fn render-array screen: (addr screen), _a: (addr array value) {
  start-color screen, 0xf2, 7
  # don't surround in spaces
  print-grapheme screen, 0x5b  # '['
  var a/esi: (addr array value) <- copy _a
  var max/ecx: int <- length a
  var i/eax: int <- copy 0
  {
    compare i, max
    break-if->=
    {
      compare i, 0
      break-if-=
      print-string screen, " "
    }
    var off/ecx: (offset value) <- compute-offset a, i
    var x/ecx: (addr value) <- index a, off
    render-value screen, x, 0
    i <- increment
    loop
  }
  print-grapheme screen, 0x5d  # ']'
}

fn hash-color val: int -> _/eax: int {
  var result/eax: int <- try-modulo val, 7  # assumes that 7 is always the background color
  return result
}

fn value-width _v: (addr value), top-level: boolean -> _/eax: int {
  var v/esi: (addr value) <- copy _v
  var type/eax: (addr int) <- get v, type
  {
    compare *type, 0  # int
    break-if-!=
    var v-int/edx: (addr int) <- get v, int-data
    var result/eax: int <- decimal-size *v-int
    return result
  }
  {
    compare *type, 1  # string
    break-if-!=
    var s-ah/eax: (addr handle array byte) <- get v, text-data
    var s/eax: (addr array byte) <- lookup *s-ah
    compare s, 0
    break-if-=
    var result/eax: int <- length s
    compare result, 0xd  # max string size
    {
      break-if-<=
      result <- copy 0xd
    }
    # if it's a nested string, include space for quotes
    # we don't do this for the top-level, where the quotes will overflow
    # into surrounding padding.
    compare top-level, 0  # false
    {
      break-if-!=
      result <- add 2
    }
    return result
  }
  {
    compare *type, 2  # array
    break-if-!=
    var a-ah/eax: (addr handle array value) <- get v, array-data
    var a/eax: (addr array value) <- lookup *a-ah
    compare a, 0
    break-if-=
    var result/eax: int <- array-width a
    return result
  }
  {
    compare *type, 3  # file handle
    break-if-!=
    var f-ah/eax: (addr handle buffered-file) <- get v, file-data
    var f/eax: (addr buffered-file) <- lookup *f-ah
    compare f, 0
    break-if-=
    # TODO: visualizing file handles
    return 4
  }
  {
    compare *type, 4  # screen
    break-if-!=
    var screen-ah/eax: (addr handle screen) <- get v, screen-data
    var screen/eax: (addr screen) <- lookup *screen-ah
    compare screen, 0
    break-if-=
    # TODO: visualizing screen
    return 6
  }
  return 0
}

# keep sync'd with render-array
fn array-width _a: (addr array value) -> _/eax: int {
  var a/esi: (addr array value) <- copy _a
  var max/ecx: int <- length a
  var i/eax: int <- copy 0
  var result/edi: int <- copy 0
  {
    compare i, max
    break-if->=
    {
      compare i, 0
      break-if-=
      result <- increment  # for space
    }
    var off/ecx: (offset value) <- compute-offset a, i
    var x/ecx: (addr value) <- index a, off
    {
      var w/eax: int <- value-width x, 0
      result <- add w
    }
    i <- increment
    loop
  }
  # we won't add 2 for surrounding brackets since we don't surround arrays in
  # spaces like other value types
  return result
}
