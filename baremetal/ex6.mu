# Draw ASCII text within a bounding box, while wrapping.
#
# To build a disk image:
#   ./translate_mu_baremetal baremetal/ex6.mu     # emits disk.img
# To run:
#   qemu-system-i386 disk.img
# Or:
#   bochs -f baremetal/boot.bochsrc               # boot.bochsrc loads disk.img
#
# Expected output: a box and text that doesn't overflow it

fn main {
  draw-box 0, 0xf, 0xf, 0x61, 0x41, 0x4
  var x/eax: int <- copy 0
  var y/ecx: int <- copy 0
  x, y <- draw-text-rightward-wrapped 0, "hello from baremetal Mu!", 0x10, 0x10, 0x60, 0x40, 0xa  # xmax = 0x60, ymax = 0x40
}
