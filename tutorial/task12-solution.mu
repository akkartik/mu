# Here's one way to draw a rectangle from the top-left corner of screen.
# Lots of other solutions are possible.
fn main screen: (addr screen) {
  draw-line screen, 1/x1     1/y1,     0x300/x2 1/y2,     3/color=green
  draw-line screen, 1/x1     0x200/y1, 0x300/x2 0x200/y2, 3/color=green
  draw-line screen, 1/x1     1/y1,     1/x2     0x200/y2, 3/color=green
  draw-line screen, 0x300/x1 1/y1,     0x300/x2 0x200/y2, 3/color=green
}
