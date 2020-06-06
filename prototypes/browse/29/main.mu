fn main args: (addr array (addr array byte)) -> exit-status/ebx: int {
  # initialize fs from args[1]
  var filename/eax: (addr array byte) <- first-arg args
  var file-state-storage: file-state
  var fs/esi: (addr file-state) <- address file-state-storage
  init-file-state fs, filename
  #
  enable-screen-grid-mode
  enable-keyboard-immediate-mode
  # initialize screen state from screen size
  var screen-position-state-storage: screen-position-state
  var screen-position-state/eax: (addr screen-position-state) <- address screen-position-state-storage
  init-screen-position-state screen-position-state
  normal-text
  {
    render fs, screen-position-state
    var key/eax: byte <- read-key
    compare key, 0x71  # 'q'
    loop-if-!=
  }
  enable-keyboard-type-mode
  enable-screen-type-mode
  exit-status <- copy 0
}

fn render fs: (addr file-state), state: (addr screen-position-state) {
  start-drawing state
  render-normal fs, state
}

fn render-normal fs: (addr file-state), state: (addr screen-position-state) {
    var newline-seen?/esi: boolean <- copy 0  # false
    var start-of-paragraph?/edi: boolean <- copy 1  # true
    var previous-char/ebx: byte <- copy 0
$render-normal:loop: {
      # if done-drawing?(state) break
      var done?/eax: boolean <- done-drawing? state
      compare done?, 0  # false
      break-if-!=
      var c/eax: byte <- next-char fs
$render-normal:loop-body: {
        # if (c == EOF) break
        compare c, 0xffffffff  # EOF marker
        break-if-= $render-normal:loop

        ## if (c == newline) perform some fairly sophisticated parsing for soft newlines
        compare c, 0xa  # newline
        {
          break-if-!=
          # if it's the first newline, buffer it
          compare newline-seen?, 0
          {
            break-if-!=
            newline-seen? <- copy 1  # true
            break $render-normal:loop-body
          }
          # otherwise render two newlines
          {
            break-if-=
            add-char state, 0xa  # newline
            add-char state, 0xa  # newline
            newline-seen? <- copy 0  # false
            start-of-paragraph? <- copy 1  # true
            break $render-normal:loop-body
          }
        }
        # if start of paragraph and c == '#', switch to header
        compare start-of-paragraph?, 0
        {
          break-if-=
          compare c, 0x23  # '#'
          {
            break-if-!=
            render-header-line fs, state
            newline-seen? <- copy 1  # true
            break $render-normal:loop-body
          }
        }
        # c is not a newline
        start-of-paragraph? <- copy 0  # false
        # if c is unprintable (particularly a '\r' CR), skip it
        compare c, 0x20
        loop-if-<
        # If there's a newline buffered and c is a space, print the buffered
        # newline (hard newline).
        # If there's a newline buffered and c is not a newline or space, print a
        # space (soft newline).
        compare newline-seen?, 0  # false
$render-normal:flush-buffered-newline: {
          break-if-=
          newline-seen? <- copy 0  # false
          {
            compare c, 0x20
            break-if-!=
            add-char state, 0xa  # newline
            break $render-normal:flush-buffered-newline
          }
          add-char state, 0x20  # space
          # fall through to print c
        }
        ## end soft newline support

$render-normal:whitespace-separated-regions: {
          # if previous-char wasn't whitespace, skip this block
          {
            compare previous-char, 0x20  # space
            break-if-=
            compare previous-char, 0xa  # newline
            break-if-=
            break $render-normal:whitespace-separated-regions
          }
          # if (c == '*') switch to bold
          compare c, 0x2a  # '*'
          {
            break-if-!=
            start-bold
              render-until-asterisk fs, state
            normal-text
            break $render-normal:loop-body
          }
          # if (c == '_') switch to bold
          compare c, 0x5f  # '_'
          {
            break-if-!=
            start-color 0xec, 7  # 236 = darkish gray
            start-bold
              render-until-underscore fs, state
            reset-formatting
            start-color 0xec, 7  # 236 = darkish gray
            break $render-normal:loop-body
          }
        }
        #
        add-char state, c
      }
      previous-char <- copy c
      loop
    }
}

fn render-header-line fs: (addr file-state), state: (addr screen-position-state) {
$render-header-line:body: {
  # compute color based on number of '#'s
  var header-level/esi: int <- copy 1  # caller already grabbed one
  var c/eax: byte <- copy 0
  {
    # if done-drawing?(state) return
    var done?/eax: boolean <- done-drawing? state
    compare done?, 0  # false
    break-if-!= $render-header-line:body
    #
    c <- next-char fs
    # if (c != '#') break
    compare c, 0x23  # '#'
    break-if-!=
    #
    header-level <- increment
    #
    loop
  }
  start-heading header-level
  {
    # if done-drawing?(state) break
    var done?/eax: boolean <- done-drawing? state
    compare done?, 0  # false
    break-if-!=
    #
    c <- next-char fs
    # if (c == EOF) break
    compare c, 0xffffffff  # EOF marker
    break-if-=
    # if (c == newline) break
    compare c, 0xa  # newline
    break-if-=
    #
    add-char state, c
    #
    loop
  }
  normal-text
}
}

# colors for a light background, going from bright to dark (meeting up with bold-text)
fn start-heading header-level: int {
$start-heading:body: {
  start-bold
  compare header-level, 1
  {
    break-if-!=
    start-color 0xa0, 7
    break $start-heading:body
  }
  compare header-level, 2
  {
    break-if-!=
    start-color 0x7c, 7
    break $start-heading:body
  }
  compare header-level, 3
  {
    break-if-!=
    start-color 0x58, 7
    break $start-heading:body
  }
  compare header-level, 4
  {
    break-if-!=
    start-color 0x34, 7
    break $start-heading:body
  }
  start-color 0xe8, 7
}
}

fn render-until-asterisk fs: (addr file-state), state: (addr screen-position-state) {
  {
    # if done-drawing?(state) break
    var done?/eax: boolean <- done-drawing? state
    compare done?, 0  # false
    break-if-!=
    #
    var c/eax: byte <- next-char fs
    # if (c == EOF) break
    compare c, 0xffffffff  # EOF marker
    break-if-=
    # if (c == '*') break
    compare c, 0x2a  # '*'
    break-if-=
    #
    add-char state, c
    #
    loop
  }
}

fn render-until-underscore fs: (addr file-state), state: (addr screen-position-state) {
  {
    # if done-drawing?(state) break
    var done?/eax: boolean <- done-drawing? state
    compare done?, 0  # false
    break-if-!=
    #
    var c/eax: byte <- next-char fs
    # if (c == EOF) break
    compare c, 0xffffffff  # EOF marker
    break-if-=
    # if (c == '_') break
    compare c, 0x5f  # '_'
    break-if-=
    #
    add-char state, c
    #
    loop
  }
}

fn first-arg args-on-stack: (addr array (addr array byte)) -> out/eax: (addr array byte) {
  var args/eax: (addr array (addr array byte)) <- copy args-on-stack
  var result/eax: (addr addr array byte) <- index args, 1
  out <- copy *result
}

fn normal-text {
  reset-formatting
  start-color 0xec, 7  # 236 = darkish gray
}
