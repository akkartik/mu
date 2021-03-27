# Draw pixels in response to keyboard events, starting from the top-left
# and in raster order.
#
# To build a disk image:
#   ./translate ex3.mu             # emits disk.img
# To run:
#   qemu-system-i386 disk.img
# Or:
#   bochs -f bochsrc               # bochsrc loads disk.img
#
# Expected output: a new green pixel starting from the top left corner of the
# screen every time you press a key (letter or digit)

fn main screen: (addr screen), keyboard: (addr keyboard) {
  var x/ecx: int <- copy 0
  var y/edx: int <- copy 0
  {
    var key/eax: byte <- read-key keyboard
    compare key, 0
    loop-if-=  # busy wait
    pixel-on-real-screen x, y, 0x31/green
    x <- increment
    compare x, 0x400/screen-width=1024
    {
      break-if-<
      y <- increment
      x <- copy 0
    }
    loop
  }
}
