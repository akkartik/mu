# Screen primitives for character-oriented output.
#
# Unlike the top-level, this text mode has no scrolling.

fn draw-grapheme screen: (addr screen), g: grapheme, x: int, y: int, color: int {
  {
    compare screen, 0
    break-if-!=
    draw-grapheme-on-real-screen g, x, y, color
    return
  }
  # TODO: fake screen
}

fn cursor-position screen: (addr screen) -> _/eax: int, _/ecx: int {
  {
    compare screen, 0
    break-if-!=
    var x/eax: int <- copy 0
    var y/ecx: int <- copy 0
    x, y <- cursor-position-on-real-screen
    return x, y
  }
  # TODO: fake screen
  return 0, 0
}

fn set-cursor-position screen: (addr screen), x: int, y: int {
  {
    compare screen, 0
    break-if-!=
    set-cursor-position-on-real-screen x, y
    return
  }
  # TODO: fake screen
}

fn clear-screen screen: (addr screen) {
  {
    compare screen, 0
    break-if-!=
    clear-real-screen
    return
  }
  # TODO: fake screen
}

fn clear-real-screen {
  var y/eax: int <- copy 0
  {
    compare y, 0x300  # 768
    break-if->=
    var x/edx: int <- copy 0
    {
      compare x, 0x400  # 1024
      break-if->=
      pixel-on-real-screen x, y, 0  # black
      x <- increment
      loop
    }
    y <- increment
    loop
  }
}
