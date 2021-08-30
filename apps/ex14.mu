# Unicode demo
#
# Mu can't read Unicode from keyboard yet, so we'll read from disk and print
# to screen.
#
# Steps for trying it out:
#   1. Translate this example into a disk image code.img.
#       ./translate apps/ex14.mu
#   2. Build a second disk image data.img containing some Unicode text.
#       dd if=/dev/zero of=data.img count=20160
#       echo 'நட' |dd of=data.img conv=notrunc
#   3. Run:
#       qemu-system-i386 -hda code.img -hdb data.img
#
# Expected output: 'நட' in green near the top-left corner of screen
#
# Limitations:
#   - Utf-8 is the one true encoding.
#   - No keyboard support yet.
#   - Just single-code-point graphemes so far. No combiner characters, etc.

fn main screen: (addr screen), keyboard: (addr keyboard), data-disk: (addr disk) {
  var text-storage: (stream byte 0x200)
  var text/esi: (addr stream byte) <- address text-storage
  load-sectors data-disk, 0/lba, 1/num-sectors, text
  var dummy/eax: int <- draw-stream-rightward screen, text, 1/x 0x80/xmax 0/y, 0xa/fg, 0/bg
}
