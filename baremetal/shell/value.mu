# todo: turn this into a sum type
type value {
  type: int
  number-data: float  # if type = 0
  text-data: (handle array byte)  # if type = 1
  array-data: (handle array value)  # if type = 2
  file-data: (handle buffered-file)  # if type = 3
  filename: (handle array byte)  # if type = 3
  screen-data: (handle screen)  # if type = 4
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
