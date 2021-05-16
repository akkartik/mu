fn main screen: (addr screen), keyboard: (addr keyboard), data-disk: (addr disk) {
  draw-line             screen,         1 1,   0x80 0x100,               7/color
  draw-line             screen,  0x80 0x100,  0x200 0x140,               7/color
  draw-monotonic-bezier screen,         1 1,   0x80 0x100,  0x200 0x140, 0xc/color
  draw-disc             screen,         1 1,            3,               7/color 0xf/border
  draw-disc             screen,  0x80 0x100,            3,               7/color 0xf/border
  draw-disc             screen, 0x200 0x140,            3,               7/color 0xf/border
}
