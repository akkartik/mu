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
  return xcurr
}

# draw text from (x, y) to (xmax, ymax), wrapping as necessary
# return the next (x, y) coordinate in raster order where drawing stopped
# if there isn't enough space, return 0 without modifying the screen
fn draw-text-rightward-wrapped screen: (addr screen), text: (addr array byte), x: int, y: int, xmax: int, ymax: int, color: int -> _/eax: int, _/ecx: int {
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
      xcurr <- copy x
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
      xcurr <- copy x
      ycurr <- add 0x10  # font-height
    }
    loop
  }
  return xcurr, ycurr
}
