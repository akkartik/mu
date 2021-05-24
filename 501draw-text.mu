# some primitives for moving the cursor without making assumptions about
# raster order
fn move-cursor-left screen: (addr screen) {
  var cursor-x/eax: int <- copy 0
  var cursor-y/ecx: int <- copy 0
  cursor-x, cursor-y <- cursor-position screen
  compare cursor-x, 0
  {
    break-if->
    return
  }
  cursor-x <- decrement
  set-cursor-position screen, cursor-x, cursor-y
}

fn move-cursor-right screen: (addr screen) {
  var _width/eax: int <- copy 0
  var dummy/ecx: int <- copy 0
  _width, dummy <- screen-size screen
  var limit/edx: int <- copy _width
  limit <- decrement
  var cursor-x/eax: int <- copy 0
  var cursor-y/ecx: int <- copy 0
  cursor-x, cursor-y <- cursor-position screen
  compare cursor-x, limit
  {
    break-if-<
    return
  }
  cursor-x <- increment
  set-cursor-position screen, cursor-x, cursor-y
}

fn move-cursor-up screen: (addr screen) {
  var cursor-x/eax: int <- copy 0
  var cursor-y/ecx: int <- copy 0
  cursor-x, cursor-y <- cursor-position screen
  compare cursor-y, 0
  {
    break-if->
    return
  }
  cursor-y <- decrement
  set-cursor-position screen, cursor-x, cursor-y
}

fn move-cursor-down screen: (addr screen) {
  var dummy/eax: int <- copy 0
  var _height/ecx: int <- copy 0
  dummy, _height <- screen-size screen
  var limit/edx: int <- copy _height
  limit <- decrement
  var cursor-x/eax: int <- copy 0
  var cursor-y/ecx: int <- copy 0
  cursor-x, cursor-y <- cursor-position screen
  compare cursor-y, limit
  {
    break-if-<
    return
  }
  cursor-y <- increment
  set-cursor-position screen, cursor-x, cursor-y
}

fn move-cursor-to-left-margin-of-next-line screen: (addr screen) {
  var dummy/eax: int <- copy 0
  var _height/ecx: int <- copy 0
  dummy, _height <- screen-size screen
  var limit/edx: int <- copy _height
  limit <- decrement
  var cursor-x/eax: int <- copy 0
  var cursor-y/ecx: int <- copy 0
  cursor-x, cursor-y <- cursor-position screen
  compare cursor-y, limit
  {
    break-if-<
    return
  }
  cursor-y <- increment
  cursor-x <- copy 0
  set-cursor-position screen, cursor-x, cursor-y
}

fn draw-grapheme-at-cursor screen: (addr screen), g: grapheme, color: int, background-color: int {
  var cursor-x/eax: int <- copy 0
  var cursor-y/ecx: int <- copy 0
  cursor-x, cursor-y <- cursor-position screen
  draw-grapheme screen, g, cursor-x, cursor-y, color, background-color
}

# we can't really render non-ASCII yet, but when we do we'll be ready
fn draw-code-point-at-cursor screen: (addr screen), c: code-point, color: int, background-color: int {
  var g/eax: grapheme <- copy c
  draw-grapheme-at-cursor screen, g, color, background-color
}

# draw a single line of text from x, y to xmax
# return the next 'x' coordinate
# if there isn't enough space, truncate
fn draw-text-rightward screen: (addr screen), text: (addr array byte), x: int, xmax: int, y: int, color: int, background-color: int -> _/eax: int {
  var stream-storage: (stream byte 0x200/print-buffer-size)
  var stream/esi: (addr stream byte) <- address stream-storage
  write stream, text
  var xcurr/eax: int <- draw-stream-rightward screen, stream, x, xmax, y, color, background-color
  return xcurr
}

# draw a single-line stream from x, y to xmax
# return the next 'x' coordinate
# if there isn't enough space, truncate
fn draw-stream-rightward screen: (addr screen), stream: (addr stream byte), x: int, xmax: int, y: int, color: int, background-color: int -> _/eax: int {
  var xcurr/ecx: int <- copy x
  {
    var g/eax: grapheme <- read-grapheme stream
    compare g, 0xffffffff/end-of-file
    break-if-=
    draw-grapheme screen, g, xcurr, y, color, background-color
    xcurr <- increment
    loop
  }
  set-cursor-position screen, xcurr, y
  return xcurr
}

fn draw-text-rightward-over-full-screen screen: (addr screen), text: (addr array byte), x: int, y: int, color: int, background-color: int -> _/eax: int {
  var width/eax: int <- copy 0
  var height/ecx: int <- copy 0
  width, height <- screen-size screen
  var result/eax: int <- draw-text-rightward screen, text, x, width, y, color, background-color
  return result
}

fn draw-text-rightward-from-cursor screen: (addr screen), text: (addr array byte), xmax: int, color: int, background-color: int {
  var cursor-x/eax: int <- copy 0
  var cursor-y/ecx: int <- copy 0
  cursor-x, cursor-y <- cursor-position screen
  cursor-x <- draw-text-rightward screen, text, cursor-x, xmax, cursor-y, color, background-color
  set-cursor-position screen, cursor-x, cursor-y
}

fn draw-text-rightward-from-cursor-over-full-screen screen: (addr screen), text: (addr array byte), color: int, background-color: int {
  var width/eax: int <- copy 0
  var height/ecx: int <- copy 0
  width, height <- screen-size screen
  draw-text-rightward-from-cursor screen, text, width, color, background-color
}

fn render-grapheme screen: (addr screen), g: grapheme, xmin: int, ymin: int, xmax: int, ymax: int, x: int, y: int, color: int, background-color: int -> _/eax: int, _/ecx: int {
  compare g, 0xa/newline
  var x/eax: int <- copy x
  {
    break-if-!=
    # minimum effort to clear cursor
    draw-code-point screen, 0x20/space, x, y, color, background-color
    x <- copy xmin
    increment y
    return x, y
  }
  draw-grapheme screen, g, x, y, color, background-color
  x <- increment
  compare x, xmax
  {
    break-if-<
    x <- copy xmin
    increment y
  }
  return x, y
}

# draw text in the rectangle from (xmin, ymin) to (xmax, ymax), starting from (x, y), wrapping as necessary
# return the next (x, y) coordinate in raster order where drawing stopped
# that way the caller can draw more if given the same min and max bounding-box.
# if there isn't enough space, truncate
fn draw-text-wrapping-right-then-down screen: (addr screen), _text: (addr array byte), xmin: int, ymin: int, xmax: int, ymax: int, _x: int, _y: int, color: int, background-color: int -> _/eax: int, _/ecx: int {
  var stream-storage: (stream byte 0x200/print-buffer-size)  # 4 rows of text = 1/12th of a real screen
                                                             # fake screens unlikely to be larger
                                                             # so this seems a reasonable size
                                                             # allocated on the stack, so quickly reclaimed
  var stream/edi: (addr stream byte) <- address stream-storage
  var text/esi: (addr array byte) <- copy _text
  var len/eax: int <- length text
  compare len, 0x200
  {
    break-if-<
    write stream, "ERROR: stream too small in draw-text-wrapping-right-then-down"
  }
  compare len, 0x200
  {
    break-if->=
    write stream, text
  }
  var x/eax: int <- copy _x
  var y/ecx: int <- copy _y
  x, y <- draw-stream-wrapping-right-then-down screen, stream, xmin, ymin, xmax, ymax, x, y, color, background-color
  return x, y
}

# draw a stream in the rectangle from (xmin, ymin) to (xmax, ymax), starting from (x, y), wrapping as necessary
# return the next (x, y) coordinate in raster order where drawing stopped
# that way the caller can draw more if given the same min and max bounding-box.
# if there isn't enough space, truncate
fn draw-stream-wrapping-right-then-down screen: (addr screen), stream: (addr stream byte), xmin: int, ymin: int, xmax: int, ymax: int, x: int, y: int, color: int, background-color: int -> _/eax: int, _/ecx: int {
  var xcurr/eax: int <- copy x
  var ycurr/ecx: int <- copy y
  var g/ebx: grapheme <- copy 0
  {
    {
      var _g/eax: grapheme <- read-grapheme stream
      g <- copy _g
    }
    compare g, 0xffffffff/end-of-file
    break-if-=
    xcurr, ycurr <- render-grapheme screen, g, xmin, ymin, xmax, ymax, xcurr, ycurr, color, background-color
    loop
  }
  set-cursor-position screen, xcurr, ycurr
  return xcurr, ycurr
}

fn draw-stream-wrapping-right-then-down-from-cursor screen: (addr screen), stream: (addr stream byte), xmin: int, ymin: int, xmax: int, ymax: int, color: int, background-color: int {
  var cursor-x/eax: int <- copy 0
  var cursor-y/ecx: int <- copy 0
  cursor-x, cursor-y <- cursor-position screen
  var end-x/edx: int <- copy cursor-x
  end-x <- increment
  compare end-x, xmax
  {
    break-if-<
    cursor-x <- copy xmin
    cursor-y <- increment
  }
  cursor-x, cursor-y <- draw-stream-wrapping-right-then-down screen, stream, xmin, ymin, xmax, ymax, cursor-x, cursor-y, color, background-color
}

fn draw-stream-wrapping-right-then-down-from-cursor-over-full-screen screen: (addr screen), stream: (addr stream byte), color: int, background-color: int {
  var width/eax: int <- copy 0
  var height/ecx: int <- copy 0
  width, height <- screen-size screen
  draw-stream-wrapping-right-then-down-from-cursor screen, stream, 0/xmin, 0/ymin, width, height, color, background-color
}

fn move-cursor-rightward-and-downward screen: (addr screen), xmin: int, xmax: int {
  var cursor-x/eax: int <- copy 0
  var cursor-y/ecx: int <- copy 0
  cursor-x, cursor-y <- cursor-position screen
  cursor-x <- increment
  compare cursor-x, xmax
  {
    break-if-<
    cursor-x <- copy xmin
    cursor-y <- increment
  }
  set-cursor-position screen, cursor-x, cursor-y
}

fn draw-text-wrapping-right-then-down-over-full-screen screen: (addr screen), text: (addr array byte), x: int, y: int, color: int, background-color: int -> _/eax: int, _/ecx: int {
  var x2/eax: int <- copy 0
  var y2/ecx: int <- copy 0
  x2, y2 <- screen-size screen  # width, height
  x2, y2 <- draw-text-wrapping-right-then-down screen, text, 0/xmin, 0/ymin, x2, y2, x, y, color, background-color
  return x2, y2  # cursor-x, cursor-y
}

fn draw-text-wrapping-right-then-down-from-cursor screen: (addr screen), text: (addr array byte), xmin: int, ymin: int, xmax: int, ymax: int, color: int, background-color: int {
  var cursor-x/eax: int <- copy 0
  var cursor-y/ecx: int <- copy 0
  cursor-x, cursor-y <- cursor-position screen
  var end-x/edx: int <- copy cursor-x
  end-x <- increment
  compare end-x, xmax
  {
    break-if-<
    cursor-x <- copy xmin
    cursor-y <- increment
  }
  cursor-x, cursor-y <- draw-text-wrapping-right-then-down screen, text, xmin, ymin, xmax, ymax, cursor-x, cursor-y, color, background-color
}

fn draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen: (addr screen), text: (addr array byte), color: int, background-color: int {
  var width/eax: int <- copy 0
  var height/ecx: int <- copy 0
  width, height <- screen-size screen
  draw-text-wrapping-right-then-down-from-cursor screen, text, 0/xmin, 0/ymin, width, height, color, background-color
}

fn draw-int32-hex-wrapping-right-then-down screen: (addr screen), n: int, xmin: int, ymin: int, xmax: int, ymax: int, x: int, y: int, color: int, background-color: int -> _/eax: int, _/ecx: int {
  var stream-storage: (stream byte 0x100)
  var stream/esi: (addr stream byte) <- address stream-storage
  write-int32-hex stream, n
  var xcurr/edx: int <- copy x
  var ycurr/ecx: int <- copy y
  {
    var g/eax: grapheme <- read-grapheme stream
    compare g, 0xffffffff/end-of-file
    break-if-=
    draw-grapheme screen, g, xcurr, ycurr, color, background-color
    xcurr <- increment
    compare xcurr, xmax
    {
      break-if-<
      xcurr <- copy xmin
      ycurr <- increment
    }
    loop
  }
  set-cursor-position screen, xcurr, ycurr
  return xcurr, ycurr
}

fn draw-int32-hex-wrapping-right-then-down-over-full-screen screen: (addr screen), n: int, x: int, y: int, color: int, background-color: int -> _/eax: int, _/ecx: int {
  var x2/eax: int <- copy 0
  var y2/ecx: int <- copy 0
  x2, y2 <- screen-size screen  # width, height
  x2, y2 <- draw-int32-hex-wrapping-right-then-down screen, n, 0/xmin, 0/ymin, x2, y2, x, y, color, background-color
  return x2, y2  # cursor-x, cursor-y
}

fn draw-int32-hex-wrapping-right-then-down-from-cursor screen: (addr screen), n: int, xmin: int, ymin: int, xmax: int, ymax: int, color: int, background-color: int {
  var cursor-x/eax: int <- copy 0
  var cursor-y/ecx: int <- copy 0
  cursor-x, cursor-y <- cursor-position screen
  var end-x/edx: int <- copy cursor-x
  end-x <- increment
  compare end-x, xmax
  {
    break-if-<
    cursor-x <- copy xmin
    cursor-y <- increment
  }
  cursor-x, cursor-y <- draw-int32-hex-wrapping-right-then-down screen, n, xmin, ymin, xmax, ymax, cursor-x, cursor-y, color, background-color
}

fn draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen screen: (addr screen), n: int, color: int, background-color: int {
  var width/eax: int <- copy 0
  var height/ecx: int <- copy 0
  width, height <- screen-size screen
  draw-int32-hex-wrapping-right-then-down-from-cursor screen, n, 0/xmin, 0/ymin, width, height, color, background-color
}

fn draw-int32-decimal-wrapping-right-then-down screen: (addr screen), n: int, xmin: int, ymin: int, xmax: int, ymax: int, x: int, y: int, color: int, background-color: int -> _/eax: int, _/ecx: int {
  var stream-storage: (stream byte 0x100)
  var stream/esi: (addr stream byte) <- address stream-storage
  write-int32-decimal stream, n
  var xcurr/edx: int <- copy x
  var ycurr/ecx: int <- copy y
  {
    var g/eax: grapheme <- read-grapheme stream
    compare g, 0xffffffff/end-of-file
    break-if-=
    draw-grapheme screen, g, xcurr, ycurr, color, background-color
    xcurr <- increment
    compare xcurr, xmax
    {
      break-if-<
      xcurr <- copy xmin
      ycurr <- increment
    }
    loop
  }
  set-cursor-position screen, xcurr, ycurr
  return xcurr, ycurr
}

fn draw-int32-decimal-wrapping-right-then-down-over-full-screen screen: (addr screen), n: int, x: int, y: int, color: int, background-color: int -> _/eax: int, _/ecx: int {
  var x2/eax: int <- copy 0
  var y2/ecx: int <- copy 0
  x2, y2 <- screen-size screen  # width, height
  x2, y2 <- draw-int32-decimal-wrapping-right-then-down screen, n, 0/xmin, 0/ymin, x2, y2, x, y, color, background-color
  return x2, y2  # cursor-x, cursor-y
}

fn draw-int32-decimal-wrapping-right-then-down-from-cursor screen: (addr screen), n: int, xmin: int, ymin: int, xmax: int, ymax: int, color: int, background-color: int {
  var cursor-x/eax: int <- copy 0
  var cursor-y/ecx: int <- copy 0
  cursor-x, cursor-y <- cursor-position screen
  var end-x/edx: int <- copy cursor-x
  end-x <- increment
  compare end-x, xmax
  {
    break-if-<
    cursor-x <- copy xmin
    cursor-y <- increment
  }
  cursor-x, cursor-y <- draw-int32-decimal-wrapping-right-then-down screen, n, xmin, ymin, xmax, ymax, cursor-x, cursor-y, color, background-color
}

fn draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen screen: (addr screen), n: int, color: int, background-color: int {
  var width/eax: int <- copy 0
  var height/ecx: int <- copy 0
  width, height <- screen-size screen
  draw-int32-decimal-wrapping-right-then-down-from-cursor screen, n, 0/xmin, 0/ymin, width, height, color, background-color
}

## Text direction: down then right

# draw a single line of text vertically from x, y to ymax
# return the next 'y' coordinate
# if there isn't enough space, truncate
fn draw-text-downward screen: (addr screen), text: (addr array byte), x: int, y: int, ymax: int, color: int, background-color: int -> _/eax: int {
  var stream-storage: (stream byte 0x100)
  var stream/esi: (addr stream byte) <- address stream-storage
  write stream, text
  var ycurr/eax: int <- draw-stream-downward screen, stream, x, y, ymax, color, background-color
  return ycurr
}

# draw a single-line stream vertically from x, y to ymax
# return the next 'y' coordinate
# if there isn't enough space, truncate
fn draw-stream-downward screen: (addr screen), stream: (addr stream byte), x: int, y: int, ymax: int, color: int, background-color: int -> _/eax: int {
  var ycurr/ecx: int <- copy y
  {
    var g/eax: grapheme <- read-grapheme stream
    compare g, 0xffffffff/end-of-file
    break-if-=
    draw-grapheme screen, g, x, ycurr, color, background-color
    ycurr <- increment
    loop
  }
  set-cursor-position screen, x, ycurr
  return ycurr
}

fn draw-text-downward-from-cursor screen: (addr screen), text: (addr array byte), ymax: int, color: int, background-color: int {
  var cursor-x/eax: int <- copy 0
  var cursor-y/ecx: int <- copy 0
  cursor-x, cursor-y <- cursor-position screen
  var result/eax: int <- draw-text-downward screen, text, cursor-x, cursor-y, ymax, color, background-color
}

# draw text down and right in the rectangle from (xmin, ymin) to (xmax, ymax), starting from (x, y), wrapping as necessary
# return the next (x, y) coordinate in raster order where drawing stopped
# that way the caller can draw more if given the same min and max bounding-box.
# if there isn't enough space, truncate
fn draw-text-wrapping-down-then-right screen: (addr screen), text: (addr array byte), xmin: int, ymin: int, xmax: int, ymax: int, _x: int, _y: int, color: int, background-color: int -> _/eax: int, _/ecx: int {
  var stream-storage: (stream byte 0x100)
  var stream/esi: (addr stream byte) <- address stream-storage
  write stream, text
  var x/eax: int <- copy _x
  var y/ecx: int <- copy _y
  x, y <- draw-stream-wrapping-down-then-right screen, stream, xmin, ymin, xmax, ymax, x, y, color, background-color
  return x, y
}

# draw a stream down and right in the rectangle from (xmin, ymin) to (xmax, ymax), starting from (x, y), wrapping as necessary
# return the next (x, y) coordinate in raster order where drawing stopped
# that way the caller can draw more if given the same min and max bounding-box.
# if there isn't enough space, truncate
fn draw-stream-wrapping-down-then-right screen: (addr screen), stream: (addr stream byte), xmin: int, ymin: int, xmax: int, ymax: int, x: int, y: int, color: int, background-color: int -> _/eax: int, _/ecx: int {
  var xcurr/edx: int <- copy x
  var ycurr/ecx: int <- copy y
  {
    var g/eax: grapheme <- read-grapheme stream
    compare g, 0xffffffff/end-of-file
    break-if-=
    draw-grapheme screen, g, xcurr, ycurr, color, background-color
    ycurr <- increment
    compare ycurr, ymax
    {
      break-if-<
      xcurr <- increment
      ycurr <- copy ymin
    }
    loop
  }
  set-cursor-position screen, xcurr, ycurr
  return xcurr, ycurr
}

fn draw-text-wrapping-down-then-right-over-full-screen screen: (addr screen), text: (addr array byte), x: int, y: int, color: int, background-color: int -> _/eax: int, _/ecx: int {
  var x2/eax: int <- copy 0
  var y2/ecx: int <- copy 0
  x2, y2 <- screen-size screen  # width, height
  x2, y2 <- draw-text-wrapping-down-then-right screen, text, 0/xmin, 0/ymin, x2, y2, x, y, color, background-color
  return x2, y2  # cursor-x, cursor-y
}

fn draw-text-wrapping-down-then-right-from-cursor screen: (addr screen), text: (addr array byte), xmin: int, ymin: int, xmax: int, ymax: int, color: int, background-color: int {
  var cursor-x/eax: int <- copy 0
  var cursor-y/ecx: int <- copy 0
  cursor-x, cursor-y <- cursor-position screen
  var end-y/edx: int <- copy cursor-y
  end-y <- increment
  compare end-y, ymax
  {
    break-if-<
    cursor-x <- increment
    cursor-y <- copy ymin
  }
  cursor-x, cursor-y <- draw-text-wrapping-down-then-right screen, text, xmin, ymin, xmax, ymax, cursor-x, cursor-y, color, background-color
}

fn draw-text-wrapping-down-then-right-from-cursor-over-full-screen screen: (addr screen), text: (addr array byte), color: int, background-color: int {
  var width/eax: int <- copy 0
  var height/ecx: int <- copy 0
  width, height <- screen-size screen
  draw-text-wrapping-down-then-right-from-cursor screen, text, 0/xmin, 0/ymin, width, height, color, background-color
}
