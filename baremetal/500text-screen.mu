# Testable primitives for writing text to screen.
# (Mu doesn't yet have testable primitives for graphics.)
#
# Unlike the top-level, this text mode has no scrolling.

# coordinates here don't match top-level
# Here we're consistent with graphics mode. Top-level is consistent with
# terminal emulators.
type screen {
  width: int
  height: int
  data: (handle array screen-cell)
  cursor-x: int
  cursor-y: int
}

type screen-cell {
  data: grapheme
  color: int
}

fn initialize-screen screen: (addr screen), width: int, height: int {
  var screen-addr/esi: (addr screen) <- copy screen
  var tmp/eax: int <- copy 0
  var dest/edi: (addr int) <- copy 0
  # screen->width = width
  dest <- get screen-addr, width
  tmp <- copy width
  copy-to *dest, tmp
  # screen->height = height
  dest <- get screen-addr, height
  tmp <- copy height
  copy-to *dest, tmp
  # screen->data = new screen-cell[width*height]
  {
    var data-addr/edi: (addr handle array screen-cell) <- get screen-addr, data
    tmp <- multiply width
    populate data-addr, tmp
  }
  # screen->cursor-x = 0
  dest <- get screen-addr, cursor-x
  copy-to *dest, 0
  # screen->cursor-y = 0
  dest <- get screen-addr, cursor-y
  copy-to *dest, 0
}

# in graphemes
fn screen-size screen: (addr screen) -> _/eax: int, _/ecx: int {
  var width/eax: int <- copy 0
  var height/ecx: int <- copy 0
  compare screen, 0
  {
    break-if-!=
    return 0x80/128, 0x30/48
  }
  # fake screen
  var screen-addr/esi: (addr screen) <- copy screen
  var tmp/edx: (addr int) <- get screen-addr, width
  width <- copy *tmp
  tmp <- get screen-addr, height
  height <- copy *tmp
  return width, height
}

# testable screen primitive
# background color isn't configurable yet
fn draw-grapheme screen: (addr screen), g: grapheme, x: int, y: int, color: int {
  {
    compare screen, 0
    break-if-!=
    draw-grapheme-on-real-screen g, x, y, color, 0
    return
  }
  # fake screen
  var screen-addr/esi: (addr screen) <- copy screen
  var idx/ecx: int <- screen-cell-index screen-addr, x, y
  var data-ah/eax: (addr handle array screen-cell) <- get screen-addr, data
  var data/eax: (addr array screen-cell) <- lookup *data-ah
  var offset/ecx: (offset screen-cell) <- compute-offset data, idx
  var dest-cell/ecx: (addr screen-cell) <- index data, offset
  var dest-grapheme/eax: (addr grapheme) <- get dest-cell, data
  var g2/edx: grapheme <- copy g
  copy-to *dest-grapheme, g2
  var dest-color/eax: (addr int) <- get dest-cell, color
  var color2/edx: grapheme <- copy color
  copy-to *dest-color, color2
}

fn screen-cell-index screen-on-stack: (addr screen), x: int, y: int -> _/ecx: int {
  var screen/esi: (addr screen) <- copy screen-on-stack
  var height-addr/eax: (addr int) <- get screen, height
  var result/ecx: int <- copy y
  result <- multiply *height-addr
  result <- add x
  return result
}

fn cursor-position screen: (addr screen) -> _/eax: int, _/ecx: int {
  {
    compare screen, 0
    break-if-!=
    var x/eax: int <- copy 0
    var y/ecx: int <- copy 0
    x, y <- cursor-position-on-real-screen
    return x, y
  }
  # fake screen
  var screen-addr/esi: (addr screen) <- copy screen
  var cursor-x-addr/eax: (addr int) <- get screen-addr, cursor-x
  var cursor-y-addr/ecx: (addr int) <- get screen-addr, cursor-y
  return *cursor-x-addr, *cursor-y-addr
}

fn set-cursor-position screen: (addr screen), x: int, y: int {
  {
    compare screen, 0
    break-if-!=
    set-cursor-position-on-real-screen x, y
    return
  }
  # fake screen
  var screen-addr/esi: (addr screen) <- copy screen
  # ignore x < 0
  {
    compare x, 0
    break-if->=
    return
  }
  # ignore x >= width
  {
    var width-addr/eax: (addr int) <- get screen-addr, width
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
    var height-addr/eax: (addr int) <- get screen-addr, height
    var height/eax: int <- copy *height-addr
    compare y, height
    break-if-<
    return
  }
  # screen->cursor-x = x
  var dest/edi: (addr int) <- get screen-addr, cursor-x
  var src/eax: int <- copy x
  copy-to *dest, src
  # screen->cursor-y = y
  dest <- get screen-addr, cursor-y
  src <- copy y
  copy-to *dest, src
}

fn show-cursor screen: (addr screen), g: grapheme {
  {
    compare screen, 0
    break-if-!=
    show-cursor-on-real-screen g
    return
  }
  # fake screen
  var cursor-x/eax: int <- copy 0
  var cursor-y/ecx: int <- copy 0
  cursor-x, cursor-y <- cursor-position screen
  draw-grapheme screen, g, cursor-x, cursor-y, 0  # cursor color not tracked for fake screen
}

fn clear-screen screen: (addr screen) {
  {
    compare screen, 0
    break-if-!=
    clear-real-screen
    return
  }
  # fake screen
  var space/edi: grapheme <- copy 0x20
  set-cursor-position screen, 0, 0
  var screen-addr/esi: (addr screen) <- copy screen
  var y/eax: int <- copy 1
  var height/ecx: (addr int) <- get screen-addr, height
  {
    compare y, *height
    break-if->
    var x/edx: int <- copy 1
    var width/ebx: (addr int) <- get screen-addr, width
    {
      compare x, *width
      break-if->
      draw-grapheme screen, space, x, y, 0/fg=black
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

fn screen-grapheme-at screen-on-stack: (addr screen), x: int, y: int -> _/eax: grapheme {
  var screen-addr/esi: (addr screen) <- copy screen-on-stack
  var idx/ecx: int <- screen-cell-index screen-addr, x, y
  var result/eax: grapheme <- screen-grapheme-at-idx screen-addr, idx
  return result
}

fn screen-grapheme-at-idx screen-on-stack: (addr screen), idx-on-stack: int -> _/eax: grapheme {
  var screen-addr/esi: (addr screen) <- copy screen-on-stack
  var data-ah/eax: (addr handle array screen-cell) <- get screen-addr, data
  var data/eax: (addr array screen-cell) <- lookup *data-ah
  var idx/ecx: int <- copy idx-on-stack
  var offset/ecx: (offset screen-cell) <- compute-offset data, idx
  var cell/eax: (addr screen-cell) <- index data, offset
  var src/eax: (addr grapheme) <- get cell, data
  return *src
}

fn screen-color-at screen-on-stack: (addr screen), x: int, y: int -> _/eax: int {
  var screen-addr/esi: (addr screen) <- copy screen-on-stack
  var idx/ecx: int <- screen-cell-index screen-addr, x, y
  var result/eax: int <- screen-color-at-idx screen-addr, idx
  return result
}

fn screen-color-at-idx screen-on-stack: (addr screen), idx-on-stack: int -> _/eax: int {
  var screen-addr/esi: (addr screen) <- copy screen-on-stack
  var data-ah/eax: (addr handle array screen-cell) <- get screen-addr, data
  var data/eax: (addr array screen-cell) <- lookup *data-ah
  var idx/ecx: int <- copy idx-on-stack
  var offset/ecx: (offset screen-cell) <- compute-offset data, idx
  var cell/eax: (addr screen-cell) <- index data, offset
  var src/eax: (addr int) <- get cell, color
  var result/eax: int <- copy *src
  return result
}
