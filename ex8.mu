# Demo of floating-point
#
# To build a disk image:
#   ./translate ex8.mu             # emits disk.img
# To run:
#   bochs -f bochsrc               # bochsrc loads disk.img
# Set a breakpoint at 0x7c00 and start stepping.

fn main screen: (addr screen), keyboard: (addr keyboard) {
  var n/eax: int <- copy 0
  var result/xmm0: float <- convert n
}
