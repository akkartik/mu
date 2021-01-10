fn draw-text-rightward screen: (addr screen), _text: (addr array byte), x: int, y: int, color: int {
  var text/esi: (addr array byte) <- copy _text
  var len/ecx: int <- length text
  var i/edx: int <- copy 0
  {
    compare i, len
    break-if->=
    var g/eax: (addr byte) <- index text, i
    var g2/eax: byte <- copy-byte *g
    var g3/eax: grapheme <- copy g2
    draw-grapheme screen, g3, x, y, color
    add-to x, 8  # font-width
    i <- increment
    loop
  }
}
