# some primitives for moving the cursor without making assumptions about
# raster order
fn cursor-left screen: (addr screen) {
  var cursor-x/eax: int <- copy 0
  var cursor-y/ecx: int <- copy 0
  cursor-x, cursor-y <- cursor-position screen
  compare cursor-x, 0
  {
    break-if->
    return
  }
  cursor-x <- subtract 8  # font-width
  set-cursor-position screen, cursor-x, cursor-y
}

fn cursor-right screen: (addr screen) {
  var cursor-x/eax: int <- copy 0
  var cursor-y/ecx: int <- copy 0
  cursor-x, cursor-y <- cursor-position screen
  compare cursor-x, 0x400  # screen-width
  {
    break-if-<
    return
  }
  cursor-x <- add 8  # font-width
  set-cursor-position screen, cursor-x, cursor-y
}

fn cursor-up screen: (addr screen) {
  var cursor-x/eax: int <- copy 0
  var cursor-y/ecx: int <- copy 0
  cursor-x, cursor-y <- cursor-position screen
  compare cursor-y, 0
  {
    break-if->
    return
  }
  cursor-y <- subtract 0x10  # screen-height
  set-cursor-position screen, cursor-x, cursor-y
}

fn cursor-down screen: (addr screen) {
  var cursor-x/eax: int <- copy 0
  var cursor-y/ecx: int <- copy 0
  cursor-x, cursor-y <- cursor-position screen
  compare cursor-y, 0x300  # screen-height
  {
    break-if-<
    return
  }
  cursor-y <- add 0x10  # screen-height
  set-cursor-position screen, cursor-x, cursor-y
}

fn draw-grapheme-at-cursor screen: (addr screen), g: grapheme, color: int {
  var cursor-x/eax: int <- copy 0
  var cursor-y/ecx: int <- copy 0
  cursor-x, cursor-y <- cursor-position screen
  draw-grapheme screen, g, cursor-x, cursor-y, color
}

# draw a single line of text from x, y to xmax
# return the next 'x' coordinate
# if there isn't enough space, return 0 without modifying the screen
fn draw-text-rightward screen: (addr screen), text: (addr array byte), x: int, xmax: int, y: int, color: int -> _/eax: int {
  var stream-storage: (stream byte 0x100)
  var stream/esi: (addr stream byte) <- address stream-storage
  write stream, text
  # check if we have enough space
  var xcurr/ecx: int <- copy x
  {
    compare xcurr, xmax
    break-if->
    var g/eax: grapheme <- read-grapheme stream
    compare g, 0xffffffff  # end-of-file
    break-if-=
    xcurr <- add 8  # font-width
    loop
  }
  compare xcurr, xmax
  {
    break-if-<=
    return 0
  }
  # we do; actually draw
  rewind-stream stream
  xcurr <- copy x
  {
    var g/eax: grapheme <- read-grapheme stream
    compare g, 0xffffffff  # end-of-file
    break-if-=
    draw-grapheme screen, g, xcurr, y, color
    xcurr <- add 8  # font-width
    loop
  }
  set-cursor-position screen, xcurr, y
  return xcurr
}

fn draw-text-rightward-from-cursor screen: (addr screen), text: (addr array byte), xmax: int, color: int -> _/eax: int {
  var cursor-x/eax: int <- copy 0
  var cursor-y/ecx: int <- copy 0
  cursor-x, cursor-y <- cursor-position screen
  var result/eax: int <- draw-text-rightward screen, text, cursor-x, xmax, cursor-y, color
  return result
}

# draw text in the rectangle from (xmin, ymin) to (xmax, ymax), starting from (x, y), wrapping as necessary
# return the next (x, y) coordinate in raster order where drawing stopped
# that way the caller can draw more if given the same min and max bounding-box.
# if there isn't enough space, return 0 without modifying the screen
fn draw-text-wrapping-right-then-down screen: (addr screen), text: (addr array byte), xmin: int, ymin: int, xmax: int, ymax: int, x: int, y: int, color: int -> _/eax: int, _/ecx: int {
  var stream-storage: (stream byte 0x100)
  var stream/esi: (addr stream byte) <- address stream-storage
  write stream, text
  # check if we have enough space
  var xcurr/edx: int <- copy x
  var ycurr/ecx: int <- copy y
  {
    compare ycurr, ymax
    break-if->=
    var g/eax: grapheme <- read-grapheme stream
    compare g, 0xffffffff  # end-of-file
    break-if-=
    xcurr <- add 8  # font-width
    compare xcurr, xmax
    {
      break-if-<
      xcurr <- copy xmin
      ycurr <- add 0x10  # font-height
    }
    loop
  }
  compare ycurr, ymax
  {
    break-if-<
    return 0, 0
  }
  # we do; actually draw
  rewind-stream stream
  xcurr <- copy x
  ycurr <- copy y
  {
    var g/eax: grapheme <- read-grapheme stream
    compare g, 0xffffffff  # end-of-file
    break-if-=
    draw-grapheme screen, g, xcurr, ycurr, color
    xcurr <- add 8  # font-width
    compare xcurr, xmax
    {
      break-if-<
      xcurr <- copy xmin
      ycurr <- add 0x10  # font-height
    }
    loop
  }
  set-cursor-position screen, xcurr, ycurr
  return xcurr, ycurr
}

fn draw-text-wrapping-right-then-down-over-full-screen screen: (addr screen), text: (addr array byte), x: int, y: int, color: int -> _/eax: int, _/ecx: int {
  var cursor-x/eax: int <- copy 0
  var cursor-y/ecx: int <- copy 0
  cursor-x, cursor-y <- draw-text-wrapping-right-then-down screen, text, 0, 0, 0x400, 0x300, x, y, color  # 1024, 768
  return cursor-x, cursor-y
}

fn draw-text-wrapping-right-then-down-from-cursor screen: (addr screen), text: (addr array byte), xmin: int, ymin: int, xmax: int, ymax: int, color: int {
  var cursor-x/eax: int <- copy 0
  var cursor-y/ecx: int <- copy 0
  cursor-x, cursor-y <- cursor-position screen
  var end-x/edx: int <- copy cursor-x
  end-x <- add 8  # font-width
  compare end-x, xmax
  {
    break-if-<
    cursor-x <- copy xmin
    cursor-y <- add 0x10  # font-height
  }
  cursor-x, cursor-y <- draw-text-wrapping-right-then-down screen, text, xmin, ymin, xmax, ymax, cursor-x, cursor-y, color
}

fn draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen: (addr screen), text: (addr array byte), color: int {
  draw-text-wrapping-right-then-down-from-cursor screen, text, 0, 0, 0x400, 0x300, color  # 1024, 768
}

## Text direction: down then right

# draw a single line of text vertically from x, y to ymax
# return the next 'y' coordinate
# if there isn't enough space, return 0 without modifying the screen
fn draw-text-downward screen: (addr screen), text: (addr array byte), x: int, y: int, ymax: int, color: int -> _/eax: int {
  var stream-storage: (stream byte 0x100)
  var stream/esi: (addr stream byte) <- address stream-storage
  write stream, text
  # check if we have enough space
  var ycurr/ecx: int <- copy y
  {
    compare ycurr, ymax
    break-if->
    var g/eax: grapheme <- read-grapheme stream
    compare g, 0xffffffff  # end-of-file
    break-if-=
    ycurr <- add 0x10  # font-height
    loop
  }
  compare ycurr, ymax
  {
    break-if-<=
    return 0
  }
  # we do; actually draw
  rewind-stream stream
  ycurr <- copy y
  {
    var g/eax: grapheme <- read-grapheme stream
    compare g, 0xffffffff  # end-of-file
    break-if-=
    draw-grapheme screen, g, x, ycurr, color
    ycurr <- add 0x10  # font-height
    loop
  }
  set-cursor-position screen, x, ycurr
  return ycurr
}

fn draw-text-downward-from-cursor screen: (addr screen), text: (addr array byte), ymax: int, color: int {
  var cursor-x/eax: int <- copy 0
  var cursor-y/ecx: int <- copy 0
  cursor-x, cursor-y <- cursor-position screen
  var result/eax: int <- draw-text-downward screen, text, cursor-x, cursor-y, ymax, color
}

# draw text down and right in the rectangle from (xmin, ymin) to (xmax, ymax), starting from (x, y), wrapping as necessary
# return the next (x, y) coordinate in raster order where drawing stopped
# that way the caller can draw more if given the same min and max bounding-box.
# if there isn't enough space, return 0 without modifying the screen
fn draw-text-wrapping-down-then-right screen: (addr screen), text: (addr array byte), xmin: int, ymin: int, xmax: int, ymax: int, x: int, y: int, color: int -> _/eax: int, _/ecx: int {
  var stream-storage: (stream byte 0x100)
  var stream/esi: (addr stream byte) <- address stream-storage
  write stream, text
  # check if we have enough space
  var xcurr/edx: int <- copy x
  var ycurr/ecx: int <- copy y
  {
    compare xcurr, xmax
    break-if->=
    var g/eax: grapheme <- read-grapheme stream
    compare g, 0xffffffff  # end-of-file
    break-if-=
    ycurr <- add 0x10  # font-height
    compare ycurr, ymax
    {
      break-if-<
      xcurr <- add 8  # font-width
      ycurr <- copy ymin
    }
    loop
  }
  compare xcurr, xmax
  {
    break-if-<
    return 0, 0
  }
  # we do; actually draw
  rewind-stream stream
  xcurr <- copy x
  ycurr <- copy y
  {
    var g/eax: grapheme <- read-grapheme stream
    compare g, 0xffffffff  # end-of-file
    break-if-=
    draw-grapheme screen, g, xcurr, ycurr, color
    ycurr <- add 0x10  # font-height
    compare ycurr, ymax
    {
      break-if-<
      xcurr <- add 8  # font-width
      ycurr <- copy ymin
    }
    loop
  }
  set-cursor-position screen, xcurr, ycurr
  return xcurr, ycurr
}

fn draw-text-wrapping-down-then-right-over-full-screen screen: (addr screen), text: (addr array byte), x: int, y: int, color: int -> _/eax: int, _/ecx: int {
  var cursor-x/eax: int <- copy 0
  var cursor-y/ecx: int <- copy 0
  cursor-x, cursor-y <- draw-text-wrapping-down-then-right screen, text, 0, 0, 0x400, 0x300, x, y, color  # 1024, 768
  return cursor-x, cursor-y
}

fn draw-text-wrapping-down-then-right-from-cursor screen: (addr screen), text: (addr array byte), xmin: int, ymin: int, xmax: int, ymax: int, color: int {
  var cursor-x/eax: int <- copy 0
  var cursor-y/ecx: int <- copy 0
  cursor-x, cursor-y <- cursor-position screen
  var end-y/edx: int <- copy cursor-y
  end-y <- add 0x10  # font-height
  compare end-y, ymax
  {
    break-if-<
    cursor-x <- add 8  # font-width
    cursor-y <- copy ymin
  }
  cursor-x, cursor-y <- draw-text-wrapping-down-then-right screen, text, xmin, ymin, xmax, ymax, cursor-x, cursor-y, color
}

fn draw-text-wrapping-down-then-right-from-cursor-over-full-screen screen: (addr screen), text: (addr array byte), color: int {
  draw-text-wrapping-down-then-right-from-cursor screen, text, 0, 0, 0x400, 0x300, color  # 1024, 768
}
