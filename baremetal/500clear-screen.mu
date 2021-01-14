fn clear-screen screen: (addr screen) {
  var y/eax: int <- copy 0
  {
    compare y, 0x300  # 768
    break-if->=
    var x/edx: int <- copy 0
    {
      compare x, 0x400  # 1024
      break-if->=
      pixel 0, x, y, 0  # black
      x <- increment
      loop
    }
    y <- increment
    loop
  }
}
