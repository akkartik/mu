# print 'n' with enough leading spaces to be right-justified in 'width'
fn print-int32-decimal-right-justified screen: (addr screen), n: int, _width: int {
  # tweak things for negative numbers
  var n-width/eax: int <- decimal-size n
  var width/ecx: int <- copy _width
  {
    compare n-width, width
    break-if->=
    print-grapheme screen, 0x20/space
    width <- decrement
    loop
  }
  print-int32-decimal screen, n
}
