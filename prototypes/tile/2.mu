# load test: animate a whole lot of text
#
# Requires a large file called "x" containing just ascii characters. One way
# to generate it:
#   cat /dev/urandom |base64 - |head -n 1000 > x
# then merge pairs of lines.
#
# This prototype assumes it's in a window 185 characters wide.

fn main -> exit-status/ebx: int {
  var num-lines/ecx: int <- copy 0x10
  clear-screen 0
  # open a file
  var f: (addr buffered-file)
  {
    var f-handle: (handle buffered-file)
    var f-in/eax: (addr handle buffered-file) <- address f-handle
    open "x", 0, f-in  # for reading
    var f-out/eax: (addr buffered-file) <- lookup f-handle
    copy-to f, f-out
  }
  # main loop
  var row/eax: int <- copy 1
  {
    compare row, 0x10  # 16
    break-if->
    render f, row, num-lines
    row <- increment
#?     sleep 0 0x5f5e100  # 100ms
    loop
  }
  # wait for a key
  {
    enable-keyboard-immediate-mode
      var dummy/eax: byte <- read-key
    enable-keyboard-type-mode
  }
  # clean up
  clear-screen 0
  exit-status <- copy 0
}

fn render f: (addr buffered-file), start-row: int, num-rows: int {
  var num-cols/ecx: int <- copy 0xb9  # 185
  # if necessary, clear the row above
$render:clear-loop: {
    compare start-row, 1
    break-if-<=
    decrement start-row
    var col/eax: int <- copy 1
    move-cursor 0, start-row, col
    {
      compare col, num-cols
      break-if->
      print-string 0, " "
      col <- increment
      loop
    }
    increment start-row
  }
  # render rest of screen below
  var row/edx: int <- copy start-row
  var col/ebx: int <- copy 1
  move-cursor 0, row, col
$render:render-loop: {
    compare row, num-rows
    break-if->=
    var c/eax: byte <- read-byte-buffered f
    compare c, 0xffffffff  # EOF marker
    break-if-=
    compare c, 0xa  # newline
    {
      break-if-!=
      row <- increment
      col <- copy 0
      move-cursor 0, row, col
      loop $render:render-loop
    }
    var g/eax: grapheme <- copy c
    print-grapheme 0, g
    col <- increment
    loop
  }
}
