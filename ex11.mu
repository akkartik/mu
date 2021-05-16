# Demo of an interactive app: controlling a Bezier curve on screen
#
# To build a disk image:
#   ./translate ex11.mu            # emits code.img
# To run:
#   qemu-system-i386 code.img
# Or:
#   bochs -f bochsrc               # bochsrc loads code.img
#
# Expected output: a spline with 3 control points. Use `Tab` to switch cursor
# between control points, and arrow keys to move the control point at the
# cursor.

fn main screen: (addr screen), keyboard: (addr keyboard), data-disk: (addr disk) {
  var env-storage: environment
  var env/esi: (addr environment) <- address env-storage
  initialize-environment env, 0x80 0x80, 0x200 0x180, 0x380 0x280
  {
    render screen, env
    edit keyboard, env
    loop
  }
}

type environment {
  p0: (handle point)
  p1: (handle point)
  p2: (handle point)
  cursor: (handle point)  # one of p0, p1 or p2
}

type point {
  x: int
  y: int
}

fn render screen: (addr screen), _self: (addr environment) {
  clear-screen screen
  var self/esi: (addr environment) <- copy _self
  var tmp-ah/ecx: (addr handle point) <- get self, p0
  var tmp/eax: (addr point) <- lookup *tmp-ah
  var p0/ebx: (addr point) <- copy tmp
  tmp-ah <- get self, p1
  tmp <- lookup *tmp-ah
  var p1/edx: (addr point) <- copy tmp
  tmp-ah <- get self, p2
  tmp <- lookup *tmp-ah
  var p2/ecx: (addr point) <- copy tmp
  # control lines
  line    screen, p0, p1,                 7/color
  line    screen, p1, p2,                 7/color
  # curve above control lines
  bezier  screen, p0, p1, p2,             0xc/color
  # points above curve
  disc    screen, p0,           3/radius, 7/color   0xf/border
  disc    screen, p1,           3/radius, 7/color   0xf/border
  disc    screen, p2,           3/radius, 7/color   0xf/border
  # cursor last of all
  var cursor-ah/eax: (addr handle point) <- get self, cursor
  var cursor/eax: (addr point) <- lookup *cursor-ah
  cursor screen, cursor, 0xa/side, 3/color
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

fn cursor screen: (addr screen), _p: (addr point), side: int, color: int {
  var half-side/eax: int <- copy side
  half-side <- shift-right 1
  var p/esi: (addr point) <- copy _p
  var x-a/ecx: (addr int) <- get p, x
  var left-x/ecx: int <- copy *x-a
  left-x <- subtract half-side
  var y-a/edx: (addr int) <- get p, y
  var top-y/edx: int <- copy *y-a
  top-y <- subtract half-side
  var max/eax: int <- copy left-x
  max <- add side
  draw-horizontal-line screen, top-y, left-x, max, color
  max <- copy top-y
  max <- add side
  draw-vertical-line screen, left-x, top-y, max, color
  var right-x/ebx: int <- copy left-x
  right-x <- add side
  draw-vertical-line screen, right-x, top-y, max, color
  var bottom-y/edx: int <- copy top-y
  bottom-y <- add side
  draw-horizontal-line screen, bottom-y, left-x, right-x, color
}

fn edit keyboard: (addr keyboard), _self: (addr environment) {
  var self/esi: (addr environment) <- copy _self
  var key/eax: byte <- read-key keyboard
  compare key, 0
  loop-if-=
  {
    compare key, 9/tab
    break-if-!=
    toggle-cursor self
    return
  }
  {
    compare key, 0x80/left-arrow
    break-if-!=
    cursor-left self
    return
  }
  {
    compare key, 0x83/right-arrow
    break-if-!=
    cursor-right self
    return
  }
  {
    compare key, 0x81/down-arrow
    break-if-!=
    cursor-down self
    return
  }
  {
    compare key, 0x82/up-arrow
    break-if-!=
    cursor-up self
    return
  }
}

fn toggle-cursor _self: (addr environment) {
  var self/esi: (addr environment) <- copy _self
  var cursor-ah/edi: (addr handle point) <- get self, cursor
  var p0-ah/ecx: (addr handle point) <- get self, p0
  var p1-ah/edx: (addr handle point) <- get self, p1
  var p2-ah/ebx: (addr handle point) <- get self, p2
  {
    var p0?/eax: boolean <- handle-equal? *p0-ah, *cursor-ah
    compare p0?, 0/false
    break-if-=
    copy-object p1-ah, cursor-ah
    return
  }
  {
    var p1?/eax: boolean <- handle-equal? *p1-ah, *cursor-ah
    compare p1?, 0/false
    break-if-=
    copy-object p2-ah, cursor-ah
    return
  }
  {
    var p2?/eax: boolean <- handle-equal? *p2-ah, *cursor-ah
    compare p2?, 0/false
    break-if-=
    copy-object p0-ah, cursor-ah
    return
  }
  abort "lost cursor"
}

fn cursor-left _self: (addr environment) {
  var self/esi: (addr environment) <- copy _self
  var cursor-ah/esi: (addr handle point) <- get self, cursor
  var cursor/eax: (addr point) <- lookup *cursor-ah
  var cursor-x/eax: (addr int) <- get cursor, x
  compare *cursor-x, 0x20
  {
    break-if-<
    subtract-from *cursor-x, 0x20
  }
}

fn cursor-right _self: (addr environment) {
  var self/esi: (addr environment) <- copy _self
  var cursor-ah/esi: (addr handle point) <- get self, cursor
  var cursor/eax: (addr point) <- lookup *cursor-ah
  var cursor-x/eax: (addr int) <- get cursor, x
  compare *cursor-x, 0x3f0
  {
    break-if->
    add-to *cursor-x, 0x20
  }
}

fn cursor-up _self: (addr environment) {
  var self/esi: (addr environment) <- copy _self
  var cursor-ah/esi: (addr handle point) <- get self, cursor
  var cursor/eax: (addr point) <- lookup *cursor-ah
  var cursor-y/eax: (addr int) <- get cursor, y
  compare *cursor-y, 0x20
  {
    break-if-<
    subtract-from *cursor-y, 0x20
  }
}

fn cursor-down _self: (addr environment) {
  var self/esi: (addr environment) <- copy _self
  var cursor-ah/esi: (addr handle point) <- get self, cursor
  var cursor/eax: (addr point) <- lookup *cursor-ah
  var cursor-y/eax: (addr int) <- get cursor, y
  compare *cursor-y, 0x2f0
  {
    break-if->
    add-to *cursor-y, 0x20
  }
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

fn initialize-environment _self: (addr environment), x0: int, y0: int, x1: int, y1: int, x2: int, y2: int {
  var self/esi: (addr environment) <- copy _self
  var p0-ah/eax: (addr handle point) <- get self, p0
  allocate p0-ah
  var p0/eax: (addr point) <- lookup *p0-ah
  initialize-point p0, x0 y0
  var p1-ah/eax: (addr handle point) <- get self, p1
  allocate p1-ah
  var p1/eax: (addr point) <- lookup *p1-ah
  initialize-point p1, x1 y1
  var p2-ah/eax: (addr handle point) <- get self, p2
  allocate p2-ah
  var p2/eax: (addr point) <- lookup *p2-ah
  initialize-point p2, x2 y2
  # cursor initially at p0
  var cursor-ah/edi: (addr handle point) <- get self, cursor
  var src-ah/esi: (addr handle point) <- get self, p0
  copy-object src-ah, cursor-ah
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
