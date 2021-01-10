# Draw an ASCII string using the built-in font (GNU unifont)
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
  draw-text-rightward 0, "hello from baremetal Mu!", 0x10, 0x10, 0xa
}
