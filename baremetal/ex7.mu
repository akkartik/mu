# Cursor-based motions.
#
# To build a disk image:
#   ./translate_mu_baremetal baremetal/ex7.mu     # emits disk.img
# To run:
#   qemu-system-i386 disk.img
# Or:
#   bochs -f baremetal/boot.bochsrc               # boot.bochsrc loads disk.img
#
# Expected output: an interactive game a bit like "snakes". Try pressing h, j,
# k, l.

fn main {
  var space/eax: grapheme <- copy 0x20
  set-cursor-position 0, 0, 0, space
  {
    var key/eax: byte <- read-key 0
    {
      compare key, 0x68  # 'h'
      break-if-!=
      var g/eax: grapheme <- copy 0x2d  # '-'
      draw-grapheme-at-cursor 0, g, 0x31
      cursor-left 0
    }
    {
      compare key, 0x6a  # 'j'
      break-if-!=
      var g/eax: grapheme <- copy 0x7c  # '|'
      draw-grapheme-at-cursor 0, g, 0x31
      cursor-down 0
    }
    {
      compare key, 0x6b  # 'k'
      break-if-!=
      var g/eax: grapheme <- copy 0x7c  # '|'
      draw-grapheme-at-cursor 0, g, 0x31
      cursor-up 0
    }
    {
      compare key, 0x6c  # 'l'
      break-if-!=
      var g/eax: grapheme <- copy 0x2d  # '-'
      draw-grapheme-at-cursor 0, g, 0x31
      cursor-right 0
    }
    loop
  }
}
