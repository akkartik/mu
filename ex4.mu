# Draw a character using the built-in font (GNU unifont)
#
# To build a disk image:
#   ./translate ex4.mu             # emits disk.img
# To run:
#   qemu-system-i386 disk.img
# Or:
#   bochs -f bochsrc               # bochsrc loads disk.img
#
# Expected output: letter 'A' in green near the top-left corner of screen

fn main screen: (addr screen), keyboard: (addr keyboard) {
  draw-codepoint screen, 0x41/A, 2/row, 1/col, 0xa/fg, 0/bg
}
