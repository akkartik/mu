# Drawing ASCII text incrementally within a bounding box.
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
  draw-box 0, 0xf, 0x1f, 0x79, 0x51, 0x4
  var x/eax: int <- copy 0x20
  var y/ecx: int <- copy 0x20
  x, y <- draw-text-wrapping-right-then-down 0, "hello ",     0x10, 0x20, 0x78, 0x50, x, y, 0xa  # (0x10, 0x20) -> (0x78, 0x50)
  x, y <- draw-text-wrapping-right-then-down 0, "from ",      0x10, 0x20, 0x78, 0x50, x, y, 0xa
  x, y <- draw-text-wrapping-right-then-down 0, "baremetal ", 0x10, 0x20, 0x78, 0x50, x, y, 0xa
  x, y <- draw-text-wrapping-right-then-down 0, "Mu!",        0x10, 0x20, 0x78, 0x50, x, y, 0xa
}
