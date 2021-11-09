# Temperature Converter app
#   https://eugenkiss.github.io/7guis/tasks/#temp
#
# To build:
#   $ ./translate converter.mu
# To run:
#   $ qemu-system-i386 code.img

# todo:
#   less duplication
#   error checking for input without hard-aborting

fn main screen: (addr screen), keyboard: (addr keyboard), data-disk: (addr disk) {
  # celsius numeric representation
  var zero: float
  var celsius/xmm1: float <- fahrenheit-to-celsius zero
  # celsius string representation
  var s-storage: (stream byte 0x10)
  var s/ecx: (addr stream byte) <- address s-storage
  write-float-decimal-approximate s, celsius, 2/decimal-places
  # celsius input/display
  var celsius-input-storage: gap-buffer
  var celsius-input/esi: (addr gap-buffer) <- address celsius-input-storage
  initialize-gap-buffer celsius-input, 8/capacity
  load-gap-buffer-from-stream celsius-input, s
  var cursor-in-celsius?/edx: boolean <- copy 0xffffffff/true
  # fahrenheit numeric representation
  var fahrenheit/xmm2: float <- celsius-to-fahrenheit celsius
  # fahrenheit string representation
  clear-stream s
  write-float-decimal-approximate s, fahrenheit, 2/decimal-places
  # fahrenheit input/display
  var fahrenheit-input-storage: gap-buffer
  var fahrenheit-input/edi: (addr gap-buffer) <- address fahrenheit-input-storage
  initialize-gap-buffer fahrenheit-input, 8/capacity
  load-gap-buffer-from-stream fahrenheit-input, s
  var cursor-in-fahrenheit?/ebx: boolean <- copy 0/false  # exactly one cursor boolean must be true at any time
  # widget title
  set-cursor-position screen, 0x1f/x 0xe/y
  draw-text-rightward-from-cursor-over-full-screen screen, " Converter                            ", 0xf/fg 0x16/bg
  # event loop
  {
    # draw current state to screen
    clear-rect screen, 0x1f/xmin 0xf/ymin, 0x45/xmax 0x14/ymax, 0xc5/color
    var x/eax: int <- render-gap-buffer screen, celsius-input, 0x20/x 0x10/y, cursor-in-celsius?, 7/fg 0/bg
    x <- draw-text-rightward screen, " celsius = ", x, 0x45/xmax, 0x10/y, 7/fg 0xc5/bg
    x <- render-gap-buffer screen, fahrenheit-input, x 0x10/y, cursor-in-fahrenheit?, 7/fg 0/bg
    x <- draw-text-rightward screen, " fahrenheit", x, 0x45/xmax, 0x10/y, 7/fg 0xc5/bg
    # render a menu bar
    set-cursor-position screen, 0x21/x 0x12/y
    draw-text-rightward-from-cursor-over-full-screen screen, " tab ", 0/fg 0x5c/bg=highlight
    draw-text-rightward-from-cursor-over-full-screen screen, " switch sides ", 7/fg 0xc5/bg
    draw-text-rightward-from-cursor-over-full-screen screen, " enter ", 0/fg 0x5c/bg=highlight
    draw-text-rightward-from-cursor-over-full-screen screen, " convert ", 7/fg 0xc5/bg
    # process a single keystroke
    $main:input: {
      var key/eax: byte <- read-key keyboard
      var key/eax: code-point-utf8 <- copy key
      compare key, 0
      loop-if-=
      # tab = switch cursor between input areas
      compare key, 9/tab
      {
        break-if-!=
        cursor-in-celsius? <- not
        cursor-in-fahrenheit? <- not
        break $main:input
      }
      # enter = convert in appropriate direction
      compare key, 0xa/newline
      {
        break-if-!=
        {
          compare cursor-in-celsius?, 0/false
          break-if-=
          clear-stream s
          emit-gap-buffer celsius-input, s
          celsius <- parse-float-decimal s
          fahrenheit <- celsius-to-fahrenheit celsius
          clear-stream s
          write-float-decimal-approximate s, fahrenheit, 2/decimal-places
          clear-gap-buffer fahrenheit-input
          load-gap-buffer-from-stream fahrenheit-input, s
        }
        {
          compare cursor-in-fahrenheit?, 0/false
          break-if-=
          clear-stream s
          emit-gap-buffer fahrenheit-input, s
          {
            var tmp/xmm1: float <- parse-float-decimal s
            fahrenheit <- copy tmp
          }
          celsius <- fahrenheit-to-celsius fahrenheit
          clear-stream s
          write-float-decimal-approximate s, celsius, 2/decimal-places
          clear-gap-buffer celsius-input
          load-gap-buffer-from-stream celsius-input, s
        }
        break $main:input
      }
      # otherwise pass key to appropriate input area
      compare cursor-in-celsius?, 0/false
      {
        break-if-=
        edit-gap-buffer celsius-input, key
        break $main:input
      }
      compare cursor-in-fahrenheit?, 0/false
      {
        break-if-=
        edit-gap-buffer fahrenheit-input, key
        break $main:input
      }
    }
    loop
  }
}

fn fahrenheit-to-celsius f: float -> _/xmm1: float {
  var result/xmm1: float <- copy f
  var thirty-two/eax: int <- copy 0x20
  var thirty-two-f/xmm0: float <- convert thirty-two
  result <- subtract thirty-two-f
  var factor/xmm0: float <- rational 5, 9
  result <- multiply factor
  return result
}

fn celsius-to-fahrenheit c: float -> _/xmm2: float {
  var result/xmm1: float <- copy c
  var factor/xmm0: float <- rational 9, 5
  result <- multiply factor
  var thirty-two/eax: int <- copy 0x20
  var thirty-two-f/xmm0: float <- convert thirty-two
  result <- add thirty-two-f
  return result
}
