# Demo of an interactive app: controlling a Bezier curve on screen

fn main screen: (addr screen), keyboard: (addr keyboard), data-disk: (addr disk) {
  var p0-storage: point
  var p0/ecx: (addr point) <- address p0-storage
  initialize-point p0, 5 5
  var p1-storage: point
  var p1/edx: (addr point) <- address p1-storage
  initialize-point p1, 0x80 0x100
  var p2-storage: point
  var p2/ebx: (addr point) <- address p2-storage
  initialize-point p2, 0x200 0x140
  render screen, p0, p1, p2
}

type point {
  x: int
  y: int
}

fn initialize-point _p: (addr point), x: int, y: int {
  var p/esi: (addr point) <- copy _p
  var dest/eax: (addr int) <- get p, x
  var src/ecx: int <- copy x
  copy-to *dest, src
  dest <- get p, y
  src <- copy y
  copy-to *dest, src
}

fn render screen: (addr screen), p0: (addr point), p1: (addr point), p2: (addr point) {
  # control lines
  line    screen, p0, p1,                 7/color
  line    screen, p1, p2,                 7/color
  # curve above control lines
  bezier  screen, p0, p1, p2,             0xc/color
  # points above curve
  disc    screen, p0,           3/radius, 7/color   0xf/border
  disc    screen, p1,           3/radius, 7/color   0xf/border
  disc    screen, p2,           3/radius, 7/color   0xf/border
}

fn bezier screen: (addr screen), _p0: (addr point), _p1: (addr point), _p2: (addr point), color: int {
  var p0/esi: (addr point) <- copy _p0
  var x0/ecx: (addr int) <- get p0, x
  var y0/edx: (addr int) <- get p0, y
  var p1/esi: (addr point) <- copy _p1
  var x1/ebx: (addr int) <- get p1, x
  var y1/eax: (addr int) <- get p1, y
  var p2/esi: (addr point) <- copy _p2
  var x2/edi: (addr int) <- get p2, x
  var y2/esi: (addr int) <- get p2, y
  draw-monotonic-bezier screen, *x0 *y0, *x1 *y1, *x2 *y2, color
}

fn line screen: (addr screen), _p0: (addr point), _p1: (addr point), color: int {
  var p0/esi: (addr point) <- copy _p0
  var x0/ecx: (addr int) <- get p0, x
  var y0/edx: (addr int) <- get p0, y
  var p1/esi: (addr point) <- copy _p1
  var x1/ebx: (addr int) <- get p1, x
  var y1/eax: (addr int) <- get p1, y
  draw-line screen, *x0 *y0, *x1 *y1, color
}

fn disc screen: (addr screen), _p: (addr point), radius: int, color: int, border-color: int {
  var p/esi: (addr point) <- copy _p
  var x/ecx: (addr int) <- get p, x
  var y/edx: (addr int) <- get p, y
  draw-disc screen, *x *y, radius, color, border-color
}
