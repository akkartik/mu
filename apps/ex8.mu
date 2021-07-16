# Demo of floating-point support.
#
# To build a disk image:
#   ./translate apps/ex8.mu        # emits code.img
# To run:
#   bochs -f bochsrc               # bochsrc loads code.img
# Set a breakpoint at 0x7c00 and start stepping.

fn main screen: (addr screen), keyboard: (addr keyboard), data-disk: (addr disk) {
  var n/eax: int <- copy 0
  var result/xmm0: float <- convert n
}
