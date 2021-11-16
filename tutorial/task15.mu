fn main screen: (addr screen) {
  var y/eax: int <- copy 0
  {
    compare y, 0x300/screen-height=768
    break-if->=
    var x/edx: int <- copy 0
    {
      compare x, 0x400/screen-width=1024
      break-if->=
      var color/ecx: int <- copy x
      pixel screen x, y, color
      x <- increment
      loop
    }
    y <- increment
    loop
  }
}
