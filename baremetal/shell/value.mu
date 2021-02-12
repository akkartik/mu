# todo: turn this into a sum type
type value {
  type: int
  number-data: float  # if type = 0
  text-data: (handle array byte)  # if type = 1
  array-data: (handle array value)  # if type = 2
}

# top-level? is a hack just for numbers
# we'll eventually need to return a y coordinate as well to render 2D values
fn render-value screen: (addr screen), _val: (addr value), x: int, y: int, top-level?: boolean -> _/eax: int {
  var val/esi: (addr value) <- copy _val
  var val-type/ecx: (addr int) <- get val, type
  compare *val-type, 1/string
  {
    break-if-!=
    var val-ah/eax: (addr handle array byte) <- get val, text-data
    var _val-string/eax: (addr array byte) <- lookup *val-ah
    var val-string/ecx: (addr array byte) <- copy _val-string
    var new-x/eax: int <- render-string screen, val-string, x, y
    return new-x
  }
  compare *val-type, 2/array
  {
    break-if-!=
    var val-ah/eax: (addr handle array value) <- get val, array-data
    var _val-array/eax: (addr array value) <- lookup *val-ah
    var val-array/edx: (addr array value) <- copy _val-array
    var new-x/eax: int <- render-array screen, val-array, x, y
    return new-x
  }
  # render ints by default for now
  var val-num/eax: (addr float) <- get val, number-data
  var new-x/eax: int <- render-number screen, *val-num, x, y, top-level?
  return new-x
}

fn initialize-value-with-integer _self: (addr value), n: int {
  var self/esi: (addr value) <- copy _self
  var type/eax: (addr int) <- get self, type
  copy-to *type, 0/number
  var val/xmm0: float <- convert n
  var dest/eax: (addr float) <- get self, number-data
  copy-to *dest, val
}

fn initialize-value-with-float _self: (addr value), n: float {
  var self/esi: (addr value) <- copy _self
  var type/eax: (addr int) <- get self, type
  copy-to *type, 0/number
  var val/xmm0: float <- copy n
  var dest/eax: (addr float) <- get self, number-data
  copy-to *dest, val
}

# synaesthesia
# TODO: right-justify
fn render-number screen: (addr screen), val: float, x: int, y: int, top-level?: boolean -> _/eax: int {
  # if we're inside an array, don't color
  compare top-level?, 0
  {
    break-if-!=
    var new-x/eax: int <- render-float-decimal screen, val, 3/precision, x, y, 3/fg, 0/bg
    return new-x
  }
  var val-int/eax: int <- convert val
  var _bg/eax: int <- hash-color val-int
  var bg/ecx: int <- copy _bg
  var fg/edx: int <- copy 7
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
  draw-code-point screen, 0x20/space, x, y, fg, bg
  increment x
  var new-x/eax: int <- render-float-decimal screen, val, 3/precision, x, y, fg, bg
  draw-code-point screen, 0x20/space, new-x, y, fg, bg
  new-x <- increment
  return new-x
}

fn hash-color val: int -> _/eax: int {
  var quotient/eax: int <- copy 0
  var remainder/edx: int <- copy 0
  quotient, remainder <- integer-divide val, 7  # assumes that 7 is always the background color
  return remainder
}

fn test-render-number {
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x20, 4
  # integers render with some padding spaces
  var new-x/eax: int <- render-number screen, 0/n, 0/x, 0/y, 1/at-top-level
  check-screen-row screen, 0/y, " 0 ", "F - test-render-number"
  check-ints-equal new-x, 3, "F - test-render-number: result"
  # we won't bother testing the background colors; lots of flexibility there
}

fn initialize-value-with-string _self: (addr value), s: (addr array byte) {
  var self/esi: (addr value) <- copy _self
  var type/eax: (addr int) <- get self, type
  copy-to *type, 1/string
  var dest/eax: (addr handle array byte) <- get self, text-data
  copy-array-object s, dest
}

fn render-string screen: (addr screen), _val: (addr array byte), x: int, y: int -> _/eax: int {
  var val/esi: (addr array byte) <- copy _val
  compare val, 0
  {
    break-if-!=
    return x
  }
  var orig-len/ecx: int <- length val
  # truncate to 12 graphemes
  # TODO: more sophisticated interactive rendering
  var truncated: (handle array byte)
  var truncated-ah/eax: (addr handle array byte) <- address truncated
  substring val, 0, 0xc, truncated-ah
  var _truncated-string/eax: (addr array byte) <- lookup *truncated-ah
  var truncated-string/edx: (addr array byte) <- copy _truncated-string
  var len/ebx: int <- length truncated-string
  draw-code-point screen, 0x22/double-quote, x, y, 7/fg, 0/bg
  increment x
  var new-x/eax: int <- draw-text-rightward-over-full-screen screen, truncated-string, x, y, 7/fg, 0/bg
  compare len, orig-len
  {
    break-if-=
    new-x <- draw-text-rightward-over-full-screen screen, "...", new-x, y, 7/fg, 0/bg
  }
  draw-code-point screen, 0x22/double-quote, new-x, y, 7/fg, 0/bg
  new-x <- increment
  return new-x
}

fn test-render-string {
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x20, 4
  # strings render with quotes
  var new-x/eax: int <- render-string screen, "abc", 0/x, 0/y
  check-screen-row screen, 0/y, "\"abc\"", "F - test-render-string"
  check-ints-equal new-x, 5, "F - test-render-string: result"
}

fn initialize-value-with-array-of-integers _self: (addr value), s: (addr array byte) {
  # parse s into a temporary array of ints
  var tmp-storage: (handle array int)
  var tmp-ah/eax: (addr handle array int) <- address tmp-storage
  parse-array-of-decimal-ints s, tmp-ah  # leak
  var _tmp/eax: (addr array int ) <- lookup *tmp-ah
  var tmp/esi: (addr array int ) <- copy _tmp
  # load the array into values
  var self/edi: (addr value) <- copy _self
  var type/eax: (addr int) <- get self, type
  copy-to *type, 2/string
  var dest-array-ah/eax: (addr handle array value) <- get self, array-data
  var len/ebx: int <- length tmp
  populate dest-array-ah, len
  var _dest-array/eax: (addr array value) <- lookup *dest-array-ah
  var dest-array/edi: (addr array value) <- copy _dest-array
  var i/eax: int <- copy 0
  {
    compare i, len
    break-if->=
    var src-addr/ecx: (addr int) <- index tmp, i
    var src/ecx: int <- copy *src-addr
    var src-f/xmm0: float <- convert src
    var dest-offset/edx: (offset value) <- compute-offset dest-array, i
    var dest-val/edx: (addr value) <- index dest-array, dest-offset
    var dest/edx: (addr float) <- get dest-val, number-data
    copy-to *dest, src-f
    i <- increment
    loop
  }
}

fn render-array screen: (addr screen), _arr: (addr array value), x: int, y: int -> _/eax: int {
  # don't surround in spaces
  draw-code-point screen, 0x5b/open-bracket, x, y, 7/fg, 0/bg
  increment x
  var arr/esi: (addr array value) <- copy _arr
  var max/ecx: int <- length arr
  var i/edx: int <- copy 0
  var new-x/eax: int <- copy x
  {
    compare i, max
    break-if->=
    {
      compare i, 0
      break-if-=
      draw-code-point screen, 0x20/space, new-x, y, 7/fg, 0/bg
      new-x <- increment
    }
    var off/ecx: (offset value) <- compute-offset arr, i
    var x/ecx: (addr value) <- index arr, off
    new-x <- render-value screen, x, new-x, y, 0/nested
    i <- increment
    loop
  }
  draw-code-point screen, 0x5d/close-bracket, new-x, y, 7/fg, 0/bg
  new-x <- increment
  return new-x
}

fn test-render-array {
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x20, 4
  #
  var val-storage: value
  var val/eax: (addr value) <- address val-storage
  initialize-value-with-array-of-integers val, "0 1 2"
  var val-array-ah/eax: (addr handle array value) <- get val, array-data
  var val-array/eax: (addr array value) <- lookup *val-array-ah
  var new-x/eax: int <- render-array screen, val-array, 0/x, 0/y
  check-screen-row screen, 0/y, "[0 1 2]", "F - test-render-array"
  check-ints-equal new-x, 7, "F - test-render-array: result"
}
