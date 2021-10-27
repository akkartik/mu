fn main screen: (addr screen) {
  draw-line screen, 0x100/x1 0x100/y1, 0x300/x2 0x100/y2, 3/color=green
  draw-line screen, 0x100/x1 0x200/y1, 0x300/x2 0x200/y2, 3/color=green
  draw-line screen, 0x100/x1 0x100/y1, 0x100/x2 0x200/y2, 3/color=green
  draw-line screen, 0x300/x1 0x100/y1, 0x300/x2 0x200/y2, 3/color=green
}
