# todo: turn this into a sum type
type value {
  type: int
  number-data: float  # if type = 0
  text-data: (handle array byte)  # if type = 1
  array-data: (handle array value)  # if type = 2
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
