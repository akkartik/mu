# benchmark: how fast can we print characters to screen?
#
# Requires a large file called "x" containing just ascii characters. One way
# to generate it:
#   cat /dev/urandom |base64 - |head -n 10000 > x
# then merge pairs of lines.

fn main -> exit-status/ebx: int {
  var num-lines/ecx: int <- copy 0x64  # 100
  clear-screen
  # open a file
  var f: (addr buffered-file)
  {
    var f-handle: (handle buffered-file)
    var f-in/eax: (addr handle buffered-file) <- address f-handle
    open "x", 0, f-in  # for reading
    var f-out/eax: (addr buffered-file) <- lookup f-handle
    copy-to f, f-out
  }
  # initial time
  var t1_/eax: int <- time
  var t1/edx: int <- copy t1_
  # main loop
  var iter/eax: int <- copy 1
  {
    compare iter, 0x640  # 1600
    break-if->
    render f, num-lines
    iter <- increment
    loop
  }
  # final time
  var t2_/eax: int <- time
  var t2/ebx: int <- copy t2_
  # time taken
  var t3/esi: int <- copy t2
  t3 <- subtract t1
  # clean up
  clear-screen
  # results
  print-int32-hex-to-screen t1
  print-string-to-screen "\n"
  print-int32-hex-to-screen t2
  print-string-to-screen "\n"
  print-int32-hex-to-screen t3
  print-string-to-screen "\n"
  #
  exit-status <- copy 0
}

fn render f: (addr buffered-file), num-rows: int {
  var num-cols/ecx: int <- copy 0x64  # 100
  # render screen
  var row/edx: int <- copy 1
  var col/ebx: int <- copy 1
  move-cursor-on-screen row, col
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
      move-cursor-on-screen row, col
      loop $render:render-loop
    }
    print-byte-to-screen c
    col <- increment
    loop
  }
}
