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

type screen {
  # text mode
  width: int
  height: int
  data: (handle array screen-cell)
  cursor-x: int  # [0..width)
  cursor-y: int  # [0..height)
  # pixel graphics
  pixels: (handle stream pixel)  # sparse representation
}

type screen-cell {
  data: grapheme
  color: int
  background-color: int
}

type pixel {
  x: int  # [0..width*font-width)
  y: int  # [0..height*font-height)
  color: int  # [0..256)
}

fn initialize-screen _screen: (addr screen), width: int, height: int {
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
  # screen->data = new screen-cell[width*height]
  {
    var data-addr/edi: (addr handle array screen-cell) <- get screen, data
    tmp <- multiply width
    populate data-addr, tmp
  }
  var pixels-ah/ecx: (addr handle stream pixel) <- get screen, pixels
  tmp <- shift-left 3/log2-font-width
  tmp <- shift-left 4/log2-font-height
  populate-stream pixels-ah, tmp
  # screen->cursor-x = 0
  dest <- get screen, cursor-x
  copy-to *dest, 0
  # screen->cursor-y = 0
  dest <- get screen, cursor-y
  copy-to *dest, 0
}

# in graphemes
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

fn pixel screen: (addr screen), x: int, y: int, color: int {
  {
    compare screen, 0
    break-if-!=
    pixel-on-real-screen x, y, color
    return
  }
  # fake screen
  # prepare a pixel
  var pixel-storage: pixel
  var src/ecx: int <- copy x
  var dest/edx: (addr int) <- get pixel-storage, x
  copy-to *dest, src
  src <- copy y
  dest <- get pixel-storage, y
  copy-to *dest, src
  src <- copy color
  dest <- get pixel-storage, color
  copy-to *dest, src
  # save it
  var src/ecx: (addr pixel) <- address pixel-storage
  var screen/eax: (addr screen) <- copy screen
  var dest-stream-ah/eax: (addr handle stream pixel) <- get screen, pixels
  var dest-stream/eax: (addr stream pixel) <- lookup *dest-stream-ah
  {
    var full?/eax: boolean <- stream-full? dest-stream
    compare full?, 0/false
    break-if-=
    abort "tried to draw too many pixels on the fake screen; adjust initialize-screen"
  }
  write-to-stream dest-stream, src
}

# testable screen primitive
fn draw-grapheme _screen: (addr screen), g: grapheme, x: int, y: int, color: int, background-color: int {
  var screen/esi: (addr screen) <- copy _screen
  {
    compare screen, 0
    break-if-!=
    draw-grapheme-on-real-screen g, x, y, color, background-color
    return
  }
  # fake screen
  var idx/ecx: int <- screen-cell-index screen, x, y
  var data-ah/eax: (addr handle array screen-cell) <- get screen, data
  var data/eax: (addr array screen-cell) <- lookup *data-ah
  var offset/ecx: (offset screen-cell) <- compute-offset data, idx
  var dest-cell/ecx: (addr screen-cell) <- index data, offset
  var dest-grapheme/eax: (addr grapheme) <- get dest-cell, data
  var g2/edx: grapheme <- copy g
  copy-to *dest-grapheme, g2
  var dest-color/eax: (addr int) <- get dest-cell, color
  var src-color/edx: int <- copy color
  copy-to *dest-color, src-color
  dest-color <- get dest-cell, background-color
  src-color <- copy background-color
  copy-to *dest-color, src-color
}

# we can't really render non-ASCII yet, but when we do we'll be ready
fn draw-code-point screen: (addr screen), c: code-point, x: int, y: int, color: int, background-color: int {
  var g/eax: grapheme <- copy c
  draw-grapheme screen, g, x, y, color, background-color
}

# not really needed for a real screen, though it shouldn't do any harm
fn screen-cell-index _screen: (addr screen), x: int, y: int -> _/ecx: int {
  var screen/esi: (addr screen) <- copy _screen
  # only one bounds check isn't automatically handled
  {
    var xmax/eax: (addr int) <- get screen, width
    var xcurr/ecx: int <- copy x
    compare xcurr, *xmax
    break-if-<
    abort "tried to print out of screen bounds"
  }
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

fn draw-cursor screen: (addr screen), g: grapheme {
  {
    compare screen, 0
    break-if-!=
    draw-cursor-on-real-screen g
    return
  }
  # fake screen
  var cursor-x/eax: int <- copy 0
  var cursor-y/ecx: int <- copy 0
  cursor-x, cursor-y <- cursor-position screen
  draw-grapheme screen, g, cursor-x, cursor-y, 0/fg, 7/bg
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
      draw-code-point screen, 0x20/space, x, y, 0/fg=black, 0/bg=black
      x <- increment
      loop
    }
    y <- increment
    loop
  }
  set-cursor-position screen, 0, 0
  var dest-stream-ah/eax: (addr handle stream pixel) <- get screen, pixels
  var dest-stream/eax: (addr stream pixel) <- lookup *dest-stream-ah
  clear-stream dest-stream
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
      var g/eax: grapheme <- screen-grapheme-at screen, x, y
      {
        compare g, 0
        break-if-=
        compare g, 0x20/space
        break-if-=
        return 0/false
      }
      x <- increment
      loop
    }
    y <- increment
    loop
  }
  var pixels-ah/eax: (addr handle stream pixel) <- get screen, pixels
  var pixels/eax: (addr stream pixel) <- lookup *pixels-ah
  rewind-stream pixels
  var result/eax: boolean <- stream-empty? pixels
  return result
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
      draw-code-point screen, 0x20/space, x, y, 0/fg, background-color
      x <- increment
      loop
    }
    y <- increment
    loop
  }
  set-cursor-position screen, 0, 0
}

# there's no grapheme that guarantees to cover every pixel, so we'll bump down
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
  y <- shift-left 4/log-font-height
  var ymax/ecx: int <- copy ymax
  ymax <- shift-left 4/log-font-height
  {
    compare y, ymax
    break-if->=
    var x/edx: int <- copy xmin
    x <- shift-left 3/log-font-width
    var xmax/ebx: int <- copy xmax
    xmax <- shift-left 3/log-font-width
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

fn screen-grapheme-at _screen: (addr screen), x: int, y: int -> _/eax: grapheme {
  var screen/esi: (addr screen) <- copy _screen
  var idx/ecx: int <- screen-cell-index screen, x, y
  var result/eax: grapheme <- screen-grapheme-at-idx screen, idx
  return result
}

fn screen-grapheme-at-idx _screen: (addr screen), idx-on-stack: int -> _/eax: grapheme {
  var screen/esi: (addr screen) <- copy _screen
  var data-ah/eax: (addr handle array screen-cell) <- get screen, data
  var data/eax: (addr array screen-cell) <- lookup *data-ah
  var idx/ecx: int <- copy idx-on-stack
  var offset/ecx: (offset screen-cell) <- compute-offset data, idx
  var cell/eax: (addr screen-cell) <- index data, offset
  var src/eax: (addr grapheme) <- get cell, data
  return *src
}

fn screen-color-at _screen: (addr screen), x: int, y: int -> _/eax: int {
  var screen/esi: (addr screen) <- copy _screen
  var idx/ecx: int <- screen-cell-index screen, x, y
  var result/eax: int <- screen-color-at-idx screen, idx
  return result
}

fn screen-color-at-idx _screen: (addr screen), idx-on-stack: int -> _/eax: int {
  var screen/esi: (addr screen) <- copy _screen
  var data-ah/eax: (addr handle array screen-cell) <- get screen, data
  var data/eax: (addr array screen-cell) <- lookup *data-ah
  var idx/ecx: int <- copy idx-on-stack
  var offset/ecx: (offset screen-cell) <- compute-offset data, idx
  var cell/eax: (addr screen-cell) <- index data, offset
  var src/eax: (addr int) <- get cell, color
  var result/eax: int <- copy *src
  return result
}

fn screen-background-color-at _screen: (addr screen), x: int, y: int -> _/eax: int {
  var screen/esi: (addr screen) <- copy _screen
  var idx/ecx: int <- screen-cell-index screen, x, y
  var result/eax: int <- screen-background-color-at-idx screen, idx
  return result
}

fn screen-background-color-at-idx _screen: (addr screen), idx-on-stack: int -> _/eax: int {
  var screen/esi: (addr screen) <- copy _screen
  var data-ah/eax: (addr handle array screen-cell) <- get screen, data
  var data/eax: (addr array screen-cell) <- lookup *data-ah
  var idx/ecx: int <- copy idx-on-stack
  var offset/ecx: (offset screen-cell) <- compute-offset data, idx
  var cell/eax: (addr screen-cell) <- index data, offset
  var src/eax: (addr int) <- get cell, background-color
  var result/eax: int <- copy *src
  return result
}
