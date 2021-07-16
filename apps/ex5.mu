# Draw a single line of ASCII text using the built-in font (GNU unifont)
# Also demonstrates bounds-checking _before_ drawing.
#
# To build a disk image:
#   ./translate apps/ex5.mu        # emits code.img
# To run:
#   qemu-system-i386 code.img
# Or:
#   bochs -f bochsrc               # bochsrc loads code.img
#
# Expected output: text in green near the top-left corner of screen

fn main screen: (addr screen), keyboard: (addr keyboard), data-disk: (addr disk) {
  var dummy/eax: int <- draw-text-rightward screen, "hello from baremetal Mu!", 0x10/x, 0x400/xmax, 0x10/y, 0xa/fg, 0/bg
  dummy <- draw-text-rightward screen, "you shouldn't see this", 0x10/x, 0xa0/xmax, 0x30/y, 3/fg, 0/bg  # xmax is too narrow
}
