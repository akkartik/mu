# Guess the result of mixing two colors.

fn main screen: (addr screen), keyboard: (addr keyboard), data-disk: (addr disk) {
  var second-buffer: screen
  var second-screen/edi: (addr screen) <- address second-buffer
  initialize-screen second-screen, 0x80, 0x30, 1/include-pixels
  var leftx/edx: int <- copy 0x80
  var rightx/ebx: int <- copy 0x380
  {
    compare leftx, rightx
    break-if->=
    clear-screen second-screen
    # interesting value: 9/blue with 0xe/yellow
    color-field second-screen, leftx 0x40/y, 0x40/width 0x40/height, 1/blue
    color-field second-screen, rightx 0x41/y, 0x40/width 0x40/height, 2/green
    copy-pixels second-screen, screen
    # on the first iteration, give everyone a chance to make their guess
    {
      compare leftx, 0x80
      break-if->
      var x/eax: byte <- read-key keyboard
      compare x, 0
      loop-if-=
    }
    leftx <- add 2
    rightx <- subtract 2
    loop
  }
}

fn color-field screen: (addr screen), xmin: int, ymin: int, width: int, height: int, color: int {
  var xmax/esi: int <- copy xmin
  xmax <- add width
  var ymax/edi: int <- copy ymin
  ymax <- add height
  var y/eax: int <- copy ymin
  {
    compare y, ymax
    break-if->=
    var x/ecx: int <- copy xmin
    {
      compare x, xmax
      break-if->=
      pixel screen, x, y, color
      x <- add 2
      loop
    }
    y <- increment
    compare y, ymax
    break-if->=
    var x/ecx: int <- copy xmin
    x <- increment
    {
      compare x, xmax
      break-if->=
      pixel screen, x, y, color
      x <- add 2
      loop
    }
    y <- increment
    loop
  }
}

fn linger {
  var i/ecx: int <- copy 0
  {
    compare i, 0x40000000  # Kartik's Linux with -accel kvm
#?     compare i, 0x8000000  # Kartik's Mac with -accel tcg
    break-if->=
    i <- increment
    loop
  }
}
