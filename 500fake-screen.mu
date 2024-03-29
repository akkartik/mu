# Testable primitives for writing to screen.
#
# Mu mostly uses the screen for text, but it builds it out of pixel graphics
# and a bitmap font. There is no support for a blinking cursor, scrolling and
# so on.
#
# Fake screens are primarily for testing text-mode prints. However, they do
# support some rudimentary pixel operations as well. Caveats:
#
# - Drawing pixels atop text or vice versa is not supported. Results in a fake
#   screen will not mimic real screens in these situations.
# - Fake screens currently also assume a fixed-width 8x16 font.
# - Combining characters don't render like in a real screen (which itself
#   isn't ideal).

type screen {
  # text mode
  width: int
  height: int
  data: (handle array screen-cell)
  cursor-x: int  # [0..width)
  cursor-y: int  # [0..height)
  # pixel graphics
  pixels: (handle array byte)
}

type screen-cell {
  data: code-point
  color: int
  background-color: int
  unused?: boolean
}

fn initialize-screen _screen: (addr screen), width: int, height: int, pixel-graphics?: boolean {
  var screen/esi: (addr screen) <- copy _screen
  var tmp/eax: int <- copy 0
  var dest/edi: (addr int) <- copy 0
  # screen->width = width
  dest <- get screen, width
  tmp <- copy width
  copy-to *dest, tmp
  # screen->height = height
  dest <- get screen, height
  tmp <- copy height
  copy-to *dest, tmp
  # populate screen->data
  {
    var data-ah/edi: (addr handle array screen-cell) <- get screen, data
    var capacity/eax: int <- copy width
    capacity <- multiply height
    #
    populate data-ah, capacity
  }
  # if necessary, populate screen->pixels
  {
    compare pixel-graphics?, 0/false
    break-if-=
    var pixels-ah/edi: (addr handle array byte) <- get screen, pixels
    var capacity/eax: int <- copy width
    capacity <- shift-left 3/log2-font-width
    capacity <- multiply height
    capacity <- shift-left 4/log2-font-height
    #
    populate pixels-ah, capacity
  }
  # screen->cursor-x = 0
  dest <- get screen, cursor-x
  copy-to *dest, 0
  # screen->cursor-y = 0
  dest <- get screen, cursor-y
  copy-to *dest, 0
}

# in code-point-utf8s
fn screen-size _screen: (addr screen) -> _/eax: int, _/ecx: int {
  var screen/esi: (addr screen) <- copy _screen
  var width/eax: int <- copy 0
  var height/ecx: int <- copy 0
  compare screen, 0
  {
    break-if-!=
    return 0x80/128, 0x30/48
  }
  # fake screen
  var tmp/edx: (addr int) <- get screen, width
  width <- copy *tmp
  tmp <- get screen, height
  height <- copy *tmp
  return width, height
}

# testable screen primitive
# return number of 8x16 units drawn
fn draw-code-point _screen: (addr screen), c: code-point, x: int, y: int, color: int, background-color: int -> _/eax: int {
  var screen/esi: (addr screen) <- copy _screen
  {
    compare screen, 0
    break-if-!=
    var result/eax: int <- draw-code-point-on-real-screen c, x, y, color, background-color
    return result
  }
  # fake screen
  var wide?/eax: boolean <- wide-code-point? c
  compare wide?, 0/false
  {
    break-if-=
    draw-wide-code-point-on-fake-screen screen, c, x, y, color, background-color
    return 2
  }
  draw-narrow-code-point-on-fake-screen screen, c, x, y, color, background-color
  return 1
}

fn overlay-code-point _screen: (addr screen), c: code-point, x: int, y: int, color: int, background-color: int -> _/eax: int {
  var screen/esi: (addr screen) <- copy _screen
  {
    compare screen, 0
    break-if-!=
    var result/eax: int <- overlay-code-point-on-real-screen c, x, y, color, background-color
    return result
  }
  # fake screen
  # TODO: support overlays in fake screen
  var wide?/eax: boolean <- wide-code-point? c
  compare wide?, 0/false
  {
    break-if-=
    draw-wide-code-point-on-fake-screen screen, c, x, y, color, background-color
    return 2
  }
  draw-narrow-code-point-on-fake-screen screen, c, x, y, color, background-color
  return 1
}

fn draw-narrow-code-point-on-fake-screen _screen: (addr screen), c: code-point, x: int, y: int, color: int, background-color: int {
  var screen/esi: (addr screen) <- copy _screen
  # ignore if out of bounds
  {
    compare x, 0
    break-if->=
    return
  }
  {
    var xmax-addr/eax: (addr int) <- get screen, width
    var xmax/eax: int <- copy *xmax-addr
    compare x, xmax
    break-if-<
    {
      loop
    }
    return
  }
  {
    compare y, 0
    break-if->=
    return
  }
  {
    var ymax-addr/eax: (addr int) <- get screen, height
    var ymax/eax: int <- copy *ymax-addr
    compare y, ymax
    break-if-<
    return
  }
  #
  var index/ecx: int <- screen-cell-index screen, x, y
  var data-ah/eax: (addr handle array screen-cell) <- get screen, data
  var data/eax: (addr array screen-cell) <- lookup *data-ah
  var offset/ecx: (offset screen-cell) <- compute-offset data, index
  var dest-cell/ecx: (addr screen-cell) <- index data, offset
  var dest-code-point/eax: (addr code-point) <- get dest-cell, data
  var c2/edx: code-point <- copy c
  copy-to *dest-code-point, c2
  var dest-color/eax: (addr int) <- get dest-cell, color
  var src-color/edx: int <- copy color
  copy-to *dest-color, src-color
  dest-color <- get dest-cell, background-color
  src-color <- copy background-color
  copy-to *dest-color, src-color
  var dest/eax: (addr boolean) <- get dest-cell, unused?
  copy-to *dest, 0/false
}

fn draw-wide-code-point-on-fake-screen _screen: (addr screen), c: code-point, x: int, y: int, color: int, background-color: int {
  var screen/esi: (addr screen) <- copy _screen
  # ignore if out of bounds
  {
    compare x, 0
    break-if->=
    return
  }
  {
    var xmax-addr/eax: (addr int) <- get screen, width
    var xmax/eax: int <- copy *xmax-addr
    xmax <- decrement  # wide code-points need an extra unit
    compare x, xmax
    break-if-<
    return
  }
  {
    compare y, 0
    break-if->=
    return
  }
  {
    var ymax-addr/eax: (addr int) <- get screen, height
    var ymax/eax: int <- copy *ymax-addr
    compare y, ymax
    break-if-<
    return
  }
  #
  var index/ecx: int <- screen-cell-index screen, x, y
  {
    var data-ah/eax: (addr handle array screen-cell) <- get screen, data
    var data/eax: (addr array screen-cell) <- lookup *data-ah
    var offset/ecx: (offset screen-cell) <- compute-offset data, index
    var dest-cell/ecx: (addr screen-cell) <- index data, offset
    var dest-code-point/eax: (addr code-point) <- get dest-cell, data
    var c2/edx: code-point <- copy c
    copy-to *dest-code-point, c2
    var dest-color/eax: (addr int) <- get dest-cell, color
    var src-color/edx: int <- copy color
    copy-to *dest-color, src-color
    dest-color <- get dest-cell, background-color
    src-color <- copy background-color
    copy-to *dest-color, src-color
    var dest/eax: (addr boolean) <- get dest-cell, unused?
    copy-to *dest, 0/false
  }
  # set next screen-cell to unused
  index <- increment
  {
    var data-ah/eax: (addr handle array screen-cell) <- get screen, data
    var data/eax: (addr array screen-cell) <- lookup *data-ah
    var offset/ecx: (offset screen-cell) <- compute-offset data, index
    var dest-cell/ecx: (addr screen-cell) <- index data, offset
    var dest/eax: (addr boolean) <- get dest-cell, unused?
    copy-to *dest, 1/true
  }
}

# fake screens only
fn screen-cell-index _screen: (addr screen), x: int, y: int -> _/ecx: int {
  var screen/esi: (addr screen) <- copy _screen
  var width-addr/eax: (addr int) <- get screen, width
  var result/ecx: int <- copy y
  result <- multiply *width-addr
  result <- add x
  return result
}

fn cursor-position _screen: (addr screen) -> _/eax: int, _/ecx: int {
  var screen/esi: (addr screen) <- copy _screen
  {
    compare screen, 0
    break-if-!=
    var x/eax: int <- copy 0
    var y/ecx: int <- copy 0
    x, y <- cursor-position-on-real-screen
    return x, y
  }
  # fake screen
  var cursor-x-addr/eax: (addr int) <- get screen, cursor-x
  var cursor-y-addr/ecx: (addr int) <- get screen, cursor-y
  return *cursor-x-addr, *cursor-y-addr
}

fn set-cursor-position _screen: (addr screen), x: int, y: int {
  var screen/esi: (addr screen) <- copy _screen
  {
    compare screen, 0
    break-if-!=
    set-cursor-position-on-real-screen x, y
    return
  }
  # fake screen
  # ignore x < 0
  {
    compare x, 0
    break-if->=
    return
  }
  # ignore x >= width
  {
    var width-addr/eax: (addr int) <- get screen, width
    var width/eax: int <- copy *width-addr
    compare x, width
    break-if-<=
    return
  }
  # ignore y < 0
  {
    compare y, 0
    break-if->=
    return
  }
  # ignore y >= height
  {
    var height-addr/eax: (addr int) <- get screen, height
    var height/eax: int <- copy *height-addr
    compare y, height
    break-if-<
    return
  }
  # screen->cursor-x = x
  var dest/edi: (addr int) <- get screen, cursor-x
  var src/eax: int <- copy x
  copy-to *dest, src
  # screen->cursor-y = y
  dest <- get screen, cursor-y
  src <- copy y
  copy-to *dest, src
}

fn draw-cursor screen: (addr screen), c: code-point {
  {
    compare screen, 0
    break-if-!=
    draw-cursor-on-real-screen c
    return
  }
  # fake screen
  var cursor-x/eax: int <- copy 0
  var cursor-y/ecx: int <- copy 0
  cursor-x, cursor-y <- cursor-position screen
  var dummy/eax: int <- draw-code-point screen, c, cursor-x, cursor-y, 0/fg, 7/bg
}

fn clear-screen _screen: (addr screen) {
  var screen/esi: (addr screen) <- copy _screen
  {
    compare screen, 0
    break-if-!=
    clear-real-screen
    return
  }
  # fake screen
  set-cursor-position screen, 0, 0
  var y/eax: int <- copy 0
  var height/ecx: (addr int) <- get screen, height
  {
    compare y, *height
    break-if->=
    var x/edx: int <- copy 0
    var width/ebx: (addr int) <- get screen, width
    {
      compare x, *width
      break-if->=
      var dummy/eax: int <- draw-code-point screen, 0/nul, x, y, 0/fg=black, 0/bg=black
      x <- increment
      loop
    }
    y <- increment
    loop
  }
  set-cursor-position screen, 0, 0
  var pixels-ah/eax: (addr handle array byte) <- get screen, pixels
  var pixels/eax: (addr array byte) <- lookup *pixels-ah
  var i/ecx: int <- copy 0
  var max/edx: int <- length pixels
  {
    compare i, max
    break-if->=
    var curr/eax: (addr byte) <- index pixels, i
    var zero/ebx: byte <- copy 0
    copy-byte-to *curr, zero
    i <- increment
    loop
  }
}

fn fake-screen-empty? _screen: (addr screen) -> _/eax: boolean {
  var screen/esi: (addr screen) <- copy _screen
  var y/eax: int <- copy 0
  var height/ecx: (addr int) <- get screen, height
  {
    compare y, *height
    break-if->=
    var x/edx: int <- copy 0
    var width/ebx: (addr int) <- get screen, width
    {
      compare x, *width
      break-if->=
      var c/eax: code-point <- screen-code-point-at screen, x, y
      {
        compare c, 0
        break-if-=
        compare c, 0x20/space
        break-if-=
        return 0/false
      }
      x <- increment
      loop
    }
    y <- increment
    loop
  }
  var pixels-ah/eax: (addr handle array byte) <- get screen, pixels
  var pixels/eax: (addr array byte) <- lookup *pixels-ah
  var y/ebx: int <- copy 0
  var height-addr/edx: (addr int) <- get screen, height
  var height/edx: int <- copy *height-addr
  height <- shift-left 4/log2-font-height
  {
    compare y, height
    break-if->=
    var width-addr/edx: (addr int) <- get screen, width
    var width/edx: int <- copy *width-addr
    width <- shift-left 3/log2-font-width
    var x/edi: int <- copy 0
    {
      compare x, width
      break-if->=
      var index/ecx: int <- pixel-index screen, x, y
      var color-addr/ecx: (addr byte) <- index pixels, index
      var color/ecx: byte <- copy-byte *color-addr
      compare color, 0
      {
        break-if-=
        return 0/false
      }
      x <- increment
      loop
    }
    y <- increment
    loop
  }
  return 1/true
}

fn clear-rect _screen: (addr screen), xmin: int, ymin: int, xmax: int, ymax: int, background-color: int {
  var screen/esi: (addr screen) <- copy _screen
  {
    compare screen, 0
    break-if-!=
    clear-rect-on-real-screen xmin, ymin, xmax, ymax, background-color
    return
  }
  # fake screen
  set-cursor-position screen, 0, 0
  var y/eax: int <- copy ymin
  var ymax/ecx: int <- copy ymax
  {
    compare y, ymax
    break-if->=
    var x/edx: int <- copy xmin
    var xmax/ebx: int <- copy xmax
    {
      compare x, xmax
      break-if->=
      var dummy/eax: int <- draw-code-point screen, 0x20/space, x, y, 0/fg, background-color
      x <- increment
      loop
    }
    y <- increment
    loop
  }
  set-cursor-position screen, 0, 0
}

# there's no code-point-utf8 that guarantees to cover every pixel, so we'll bump down
# to pixels for a real screen
fn clear-real-screen {
  var y/eax: int <- copy 0
  {
    compare y, 0x300/screen-height=768
    break-if->=
    var x/edx: int <- copy 0
    {
      compare x, 0x400/screen-width=1024
      break-if->=
      pixel-on-real-screen x, y, 0/color=black
      x <- increment
      loop
    }
    y <- increment
    loop
  }
}

fn clear-rect-on-real-screen xmin: int, ymin: int, xmax: int, ymax: int, background-color: int {
  var y/eax: int <- copy ymin
  y <- shift-left 4/log2-font-height
  var ymax/ecx: int <- copy ymax
  ymax <- shift-left 4/log2-font-height
  {
    compare y, ymax
    break-if->=
    var x/edx: int <- copy xmin
    x <- shift-left 3/log2-font-width
    var xmax/ebx: int <- copy xmax
    xmax <- shift-left 3/log2-font-width
    {
      compare x, xmax
      break-if->=
      pixel-on-real-screen x, y, background-color
      x <- increment
      loop
    }
    y <- increment
    loop
  }
}

fn screen-cell-unused-at? _screen: (addr screen), x: int, y: int -> _/eax: boolean {
  var screen/esi: (addr screen) <- copy _screen
  var index/ecx: int <- screen-cell-index screen, x, y
  var result/eax: boolean <- screen-cell-unused-at-index? screen, index
  return result
}

fn screen-cell-unused-at-index? _screen: (addr screen), _index: int -> _/eax: boolean {
  var screen/esi: (addr screen) <- copy _screen
  var data-ah/eax: (addr handle array screen-cell) <- get screen, data
  var data/eax: (addr array screen-cell) <- lookup *data-ah
  var index/ecx: int <- copy _index
  var offset/ecx: (offset screen-cell) <- compute-offset data, index
  var cell/eax: (addr screen-cell) <- index data, offset
  var src/eax: (addr boolean) <- get cell, unused?
  return *src
}

fn screen-code-point-at _screen: (addr screen), x: int, y: int -> _/eax: code-point {
  var screen/esi: (addr screen) <- copy _screen
  var index/ecx: int <- screen-cell-index screen, x, y
  var result/eax: code-point <- screen-code-point-at-index screen, index
  return result
}

fn screen-code-point-at-index _screen: (addr screen), _index: int -> _/eax: code-point {
  var screen/esi: (addr screen) <- copy _screen
  var data-ah/eax: (addr handle array screen-cell) <- get screen, data
  var data/eax: (addr array screen-cell) <- lookup *data-ah
  var index/ecx: int <- copy _index
  var offset/ecx: (offset screen-cell) <- compute-offset data, index
  var cell/eax: (addr screen-cell) <- index data, offset
  var src/eax: (addr code-point) <- get cell, data
  return *src
}

fn screen-color-at _screen: (addr screen), x: int, y: int -> _/eax: int {
  var screen/esi: (addr screen) <- copy _screen
  var index/ecx: int <- screen-cell-index screen, x, y
  var result/eax: int <- screen-color-at-index screen, index
  return result
}

fn screen-color-at-index _screen: (addr screen), _index: int -> _/eax: int {
  var screen/esi: (addr screen) <- copy _screen
  var data-ah/eax: (addr handle array screen-cell) <- get screen, data
  var data/eax: (addr array screen-cell) <- lookup *data-ah
  var index/ecx: int <- copy _index
  var offset/ecx: (offset screen-cell) <- compute-offset data, index
  var cell/eax: (addr screen-cell) <- index data, offset
  var src/eax: (addr int) <- get cell, color
  var result/eax: int <- copy *src
  return result
}

fn screen-background-color-at _screen: (addr screen), x: int, y: int -> _/eax: int {
  var screen/esi: (addr screen) <- copy _screen
  var index/ecx: int <- screen-cell-index screen, x, y
  var result/eax: int <- screen-background-color-at-index screen, index
  return result
}

fn screen-background-color-at-index _screen: (addr screen), _index: int -> _/eax: int {
  var screen/esi: (addr screen) <- copy _screen
  var data-ah/eax: (addr handle array screen-cell) <- get screen, data
  var data/eax: (addr array screen-cell) <- lookup *data-ah
  var index/ecx: int <- copy _index
  var offset/ecx: (offset screen-cell) <- compute-offset data, index
  var cell/eax: (addr screen-cell) <- index data, offset
  var src/eax: (addr int) <- get cell, background-color
  var result/eax: int <- copy *src
  return result
}

fn pixel screen: (addr screen), x: int, y: int, color: int {
  {
    compare screen, 0
    break-if-!=
    pixel-on-real-screen x, y, color
    return
  }
  # fake screen
  var screen/esi: (addr screen) <- copy screen
  var pixels-ah/eax: (addr handle array byte) <- get screen, pixels
  var pixels/eax: (addr array byte) <- lookup *pixels-ah
  {
    compare pixels, 0
    break-if-!=
    abort "pixel graphics not enabled for this screen"
  }
  # ignore if out of bounds
  {
    compare x, 0
    break-if->=
    return
  }
  {
    var xmax-addr/eax: (addr int) <- get screen, width
    var xmax/eax: int <- copy *xmax-addr
    xmax <- shift-left 3/log2-font-width
    compare x, xmax
    break-if-<
    return
  }
  {
    compare y, 0
    break-if->=
    return
  }
  {
    var ymax-addr/eax: (addr int) <- get screen, height
    var ymax/eax: int <- copy *ymax-addr
    ymax <- shift-left 4/log2-font-height
    compare y, ymax
    break-if-<
    return
  }
  #
  var index/ecx: int <- pixel-index screen, x, y
  var dest/ecx: (addr byte) <- index pixels, index
  var src/eax: byte <- copy-byte color
  copy-byte-to *dest, src
}

fn pixel-index _screen: (addr screen), x: int, y: int -> _/ecx: int {
  var screen/esi: (addr screen) <- copy _screen
  var width-addr/eax: (addr int) <- get screen, width
  var result/ecx: int <- copy y
  result <- multiply *width-addr
  result <- shift-left 3/log2-font-width
  result <- add x
  return result
}

# double-buffering primitive
# 'screen' must be a fake screen. 'target-screen' is usually real.
# Both screens must have the same size.
fn copy-pixels _screen: (addr screen), target-screen: (addr screen) {
  var screen/esi: (addr screen) <- copy _screen
  var pixels-ah/eax: (addr handle array byte) <- get screen, pixels
  var _pixels/eax: (addr array byte) <- lookup *pixels-ah
  var pixels/edi: (addr array byte) <- copy _pixels
  var width-a/edx: (addr int) <- get screen, width
  var width/edx: int <- copy *width-a
  width <- shift-left 3/log2-font-width
  var height-a/ebx: (addr int) <- get screen, height
  var height/ebx: int <- copy *height-a
  height <- shift-left 4/log2-font-height
  var i/esi: int <- copy 0
  var y/ecx: int <- copy 0
  {
    # screen top left pixels x y width height
    compare y, height
    break-if->=
    var x/eax: int <- copy 0
    {
      compare x, width
      break-if->=
      {
        var color-addr/ebx: (addr byte) <- index pixels, i
        var color/ebx: byte <- copy-byte *color-addr
        var color2/ebx: int <- copy color
        pixel target-screen, x, y, color2
      }
      x <- increment
      i <- increment
      loop
    }
    y <- increment
    loop
  }
}

# It turns out double-buffering screen-cells is useless because rendering fonts
# takes too long. (At least under Qemu.)
# So we'll instead convert screen-cells to pixels when double-buffering.
# 'screen' must be a fake screen.
fn convert-screen-cells-to-pixels _screen: (addr screen) {
  var screen/esi: (addr screen) <- copy _screen
  var width-a/ebx: (addr int) <- get screen, width
  var height-a/edx: (addr int) <- get screen, height
  var data-ah/eax: (addr handle array byte) <- get screen, pixels
  var _data/eax: (addr array byte) <- lookup *data-ah
  var data: (addr array byte)
  copy-to data, _data
  var y/ecx: int <- copy 0
  {
    compare y, *height-a
    break-if->=
    var x/edi: int <- copy 0
    $convert-screen-cells-to-pixels:loop-x: {
      compare x, *width-a
      break-if->=
      {
        var tmp/eax: code-point <- screen-code-point-at screen, x, y
        # skip null code-points that only get created when clearing screen
        # there may be other pixels drawn there, and we don't want to clobber them
        # this is a situation where fake screens aren't faithful to real screens; we don't support overlap between screen-cells and raw pixels
        compare tmp, 0
        break-if-=
        var c: code-point
        copy-to c, tmp
        var tmp/eax: int <- screen-color-at screen, x, y
        var fg: int
        copy-to fg, tmp
        var bg/eax: int <- screen-background-color-at screen, x, y
        var offset/eax: int <- draw-code-point-on-screen-array data, c, x, y, fg, bg, *width-a, *height-a
        x <- add offset
        loop $convert-screen-cells-to-pixels:loop-x
      }
      x <- increment
      loop
    }
    y <- increment
    loop
  }
}
