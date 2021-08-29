# Draw a character using the built-in font (GNU unifont)
#
# To build a disk image:
#   ./translate apps/ex4.mu        # emits code.img
# To run:
#   qemu-system-i386 code.img
# Or:
#   bochs -f bochsrc               # bochsrc loads code.img
#
# Expected output: letter 'A' in green near the top-left corner of screen

fn main screen: (addr screen), keyboard: (addr keyboard), data-disk: (addr disk) {
  var dummy/eax: int <- draw-code-point screen, 0x41/A, 2/row, 1/col, 0xa/fg, 0/bg
}
