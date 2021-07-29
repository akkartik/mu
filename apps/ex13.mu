# Load an image from disk and display it on screen.
#
# Build the code disk:
#   $ ./translate apps/ex13.mu                       # generates code.img
# Load a pbm, pgm or ppm image (no more than 255 levels) in the data disk
#   $ dd if=/dev/zero of=data.img count=20160
#   $ dd if=___ of=data.img conv=notrunc
# Run:
#   $ qemu-system-i386 -hda code.img -hdb data.img

fn main screen: (addr screen), keyboard: (addr keyboard), data-disk: (addr disk) {
  var img-storage: image
  var img/esi: (addr image) <- address img-storage
  load-image img, data-disk
  render-image screen, img, 0/x, 0/y, 0x300/width, 0x300/height
}

fn load-image self: (addr image), data-disk: (addr disk) {
  var s-storage: (stream byte 0x200000)  # 512 * 0x1000 sectors
  var s/ebx: (addr stream byte) <- address s-storage
  load-sectors data-disk, 0/lba, 0x1000/sectors, s
  initialize-image self, s
}
