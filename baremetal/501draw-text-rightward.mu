fn draw-text-rightward screen: (addr screen), text: (addr array byte), x: int, y: int, color: int {
  var stream-storage: (stream byte 0x100)
  var stream/esi: (addr stream byte) <- address stream-storage
  write stream, text
  {
    var g/eax: grapheme <- read-grapheme stream
    compare g, 0xffffffff  # end-of-file
    break-if-=
    draw-grapheme screen, g, x, y, color
    add-to x, 8  # font-width
    loop
  }
}
