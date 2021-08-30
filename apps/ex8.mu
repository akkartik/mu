# Demo of floating-point support.
#
# To build a disk image:
#   ./translate apps/ex8.mu        # emits code.img
# To run:
#   qemu-system-i386 code.img
# You shouldn't see any exceptions.

fn main screen: (addr screen), keyboard: (addr keyboard), data-disk: (addr disk) {
  var n/eax: int <- copy 0
  var result/xmm0: float <- convert n
}
