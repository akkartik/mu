# Draw a single line of ASCII text using the built-in font (GNU unifont)
# Also demonstrates bounds-checking _before_ drawing.
#
# To build a disk image:
#   ./translate_mu_baremetal baremetal/ex5.mu     # emits disk.img
# To run:
#   qemu-system-i386 disk.img
# Or:
#   bochs -f baremetal/boot.bochsrc               # boot.bochsrc loads disk.img
#
# Expected output: text in green near the top-left corner of screen

fn main {
  var dummy/eax: int <- draw-text-rightward 0, "hello from baremetal Mu!", 0x10, 0x400, 0x10, 0xa  # xmax = end of screen, plenty of space
  dummy <- draw-text-rightward 0, "you shouldn't see this", 0x10, 0xa0, 0x30, 0x3  # xmax = 0xa0, which is too narrow
}
