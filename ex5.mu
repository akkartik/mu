# Draw a single line of ASCII text using the built-in font (GNU unifont)
# Also demonstrates bounds-checking _before_ drawing.
#
# To build a disk image:
#   ./translate ex5.mu             # emits disk.img
# To run:
#   qemu-system-i386 disk.img
# Or:
#   bochs -f bochsrc               # bochsrc loads disk.img
#
# Expected output: text in green near the top-left corner of screen

fn main {
  var dummy/eax: int <- draw-text-rightward 0/screen, "hello from baremetal Mu!", 0x10/x, 0x400/xmax, 0x10/y, 0xa/color
  dummy <- draw-text-rightward 0/screen, "you shouldn't see this", 0x10/x, 0xa0/xmax, 0x30/y, 0x3/color  # xmax is too narrow
}
