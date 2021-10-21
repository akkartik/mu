fn main screen: (addr screen), keyboard: (addr keyboard), data-disk: (addr disk) {
  var dummy/eax: int <- draw-text-rightward screen, "hello from baremetal Mu!", 0x10/x, 0x400/xmax, 0x10/y, 0xa/fg, 0/bg
}
