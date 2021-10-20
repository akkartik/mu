# Temperature Converter app
#   https://eugenkiss.github.io/7guis/tasks/#temp
#
# To build:
#   $ ./translate converter2.mu
# To run:
#   $ qemu-system-i386 code.img

# todo:
#   error checking for input without hard-aborting

fn main screen: (addr screen), keyboard: (addr keyboard), data-disk: (addr disk) {
  # imgui approach
  forever {
    number-input fahrenheit, cursor-in-fahrenheit?
    number-input celsius, cursor-in-celsius?
    if (menu-key 9/tab "Tab" "switch sides") {  # requires non-blocking input
      cursor-in-celsius? <- not
      cursor-in-fahrenheit? <- not
    }
    if (menu-key 0xa/newline "Enter" "convert") {
      if cursor-in-fahrenheit
        celsius = fahrenheit-to-celsius fahrenheit
      else
        fahrenheit = celsius-to-fahrenheit celsius
    }
  }
  # celsius numeric representation
  var zero: float
  var celsius/xmm1: float <- fahrenheit-to-celsius zero
  # celsius input/display
  var celsius-input-storage: gap-buffer
  var celsius-input/esi: (addr gap-buffer) <- address celsius-input-storage
  initialize-gap-buffer celsius-input, 8/capacity
  value-to-input celsius, celsius-input
  # fahrenheit numeric representation
  var fahrenheit/xmm2: float <- celsius-to-fahrenheit celsius
  # fahrenheit input/display
  var fahrenheit-input-storage: gap-buffer
  var fahrenheit-input/edi: (addr gap-buffer) <- address fahrenheit-input-storage
  initialize-gap-buffer fahrenheit-input, 8/capacity
  value-to-input fahrenheit, fahrenheit-input
  # cursor toggle
  var cursor-in-celsius?/edx: boolean <- copy 0xffffffff/true
  #
  render-title screen
  # event loop
  {
    # render
    render-state celsius-input, fahrenheit-input, cursor-in-celsius?
    render-menu-bar screen
    # process a single keystroke
    $main:input: {
      var key/eax: byte <- read-key keyboard
      var key/eax: grapheme <- copy key
      compare key, 0
      loop-if-=
      # tab = switch cursor between input areas
      compare key, 9/tab
      {
        break-if-!=
        cursor-in-celsius? <- not
        break $main:input
      }
      # enter = convert in appropriate direction
      compare key, 0xa/newline
      {
        break-if-!=
        {
          compare cursor-in-celsius?, 0/false
          break-if-=
          var tmp/xmm0: float <- input-to-value celsius-input
          celsius <- copy tmp
          fahrenheit <- celsius-to-fahrenheit celsius
          value-to-input fahrenheit, fahrenheit-input
          break $main:input
        }
        var tmp/xmm0: float <- input-to-value fahrenheit-input
        fahrenheit <- copy tmp
        celsius <- fahrenheit-to-celsius fahrenheit
        value-to-input celsius, celsius-input
        break $main:input
      }
      # otherwise pass key to appropriate input area
      compare cursor-in-celsius?, 0/false
      {
        break-if-=
        edit-gap-buffer celsius-input, key
        break $main:input
      }
      edit-gap-buffer fahrenheit-input, key
    }
    loop
  }
}

# business logic

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

# helpers for UI

fn input-to-value in: (addr gap-buffer) -> _/xmm0: float {
  var s-storage: (stream byte 0x10)
  var s/ecx: (addr stream byte) <- address s-storage
  emit-gap-buffer in, s
  var result/xmm1: float <- parse-float-decimal s
  return result
}

fn value-to-input in: float, out: (addr gap-buffer) {
  var s-storage: (stream byte 0x10)
  var s/ecx: (addr stream byte) <- address s-storage
  write-float-decimal-approximate s, in, 2/decimal-places
  clear-gap-buffer out
  load-gap-buffer-from-stream out, s
}

# helpers for rendering to screen
# magic constants here need to be consistent between functions

fn render-title screen: (addr screen) {
  set-cursor-position screen, 0x1f/x 0xe/y
  draw-text-rightward-from-cursor-over-full-screen screen, " Converter                            ", 0xf/fg 0x16/bg
}

fn render-state screen: (addr screen), c: (addr gap-buffer), f: (addr gap-buffer), cursor-in-c?: boolean {
  clear-rect screen, 0x1f/xmin 0xf/ymin, 0x45/xmax 0x14/ymax, 0xc5/color
  var x/eax: int <- render-gap-buffer screen, c, 0x20/x 0x10/y, cursor-in-c?, 7/fg 0/bg
  x <- draw-text-rightward screen, " celsius = ", x, 0x45/xmax, 0x10/y, 7/fg 0xc5/bg
  var cursor-in-f?/ecx: boolean <- copy cursor-in-c?
  cursor-in-f? <- not
  x <- render-gap-buffer screen, f, x 0x10/y, cursor-in-f?, 7/fg 0/bg
  x <- draw-text-rightward screen, " fahrenheit", x, 0x45/xmax, 0x10/y, 7/fg 0xc5/bg
}

fn render-menu-bar screen: (addr screen) {
  set-cursor-position screen, 0x21/x 0x12/y
  draw-text-rightward-from-cursor-over-full-screen screen, " tab ", 0/fg 0x5c/bg=highlight
  draw-text-rightward-from-cursor-over-full-screen screen, " switch sides ", 7/fg 0xc5/bg
  draw-text-rightward-from-cursor-over-full-screen screen, " enter ", 0/fg 0x5c/bg=highlight
  draw-text-rightward-from-cursor-over-full-screen screen, " convert ", 7/fg 0xc5/bg
}
