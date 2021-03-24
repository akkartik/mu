# Demo of reading and writing to disk.
#
# Steps for trying it out:
#   1. Translate this example into a disk image disk.img.
#       ./translate ex9.mu
#   2. Build a second disk image data.img containing some text.
#       dd if=/dev/zero of=data.img count=20160
#       echo 'abc def ghi' |dd of=data.img conv=notrunc
#   3. Familiarize yourself with how the data disk looks within xxd:
#       xxd data.img |head
#   4. Run in an emulator, either Qemu or Bochs.
#       qemu-system-i386 -hda disk.img -hdb data.img
#       bochs -f bochsrc.2disks
#   5. Exit the emulator.
#   6. Notice that the data disk now contains the word count of the original text.
#       xxd data.img |head

fn main {
  var text-storage: (stream byte 0x200)
  var text/esi: (addr stream byte) <- address text-storage
  load-first-sector-from-primary-bus-secondary-drive text

  var word-count/eax: int <- word-count text

  var result-storage: (stream byte 0x10)
  var result/edi: (addr stream byte) <- address result-storage
  write-int32-decimal result, word-count
  store-first-sector-to-primary-bus-secondary-drive result
}

fn word-count in: (addr stream byte) -> _/eax: int {
  var result/edi: int <- copy 0
  {
    var done?/eax: boolean <- stream-empty? in
    compare done?, 0/false
    break-if-!=
    var g/eax: grapheme <- read-grapheme in
    {
      compare g, 0x20/space
      break-if-!=
      result <- increment
    }
    {
      compare g, 0xa/newline
      break-if-!=
      result <- increment
    }
    loop
  }
  return result
}
