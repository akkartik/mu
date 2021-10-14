# read line from keyboard into stream while also echoing to screen
# abort on stream overflow
fn read-line-from-keyboard keyboard: (addr keyboard), out: (addr stream byte), screen: (addr screen), fg: int, bg: int {
  clear-stream out
  $read-line-from-keyboard:loop: {
    draw-cursor screen, 0x20/space
    var key/eax: byte <- read-key keyboard
    compare key, 0xa/newline
    break-if-=
    compare key, 0
    loop-if-=
    compare key, 8/backspace
    {
      break-if-!=
      undo-append-byte out
      draw-code-point-at-cursor-over-full-screen screen, 0x20/space, fg 0/bg  # clear cursor
      move-cursor-left screen
      move-cursor-left screen
      draw-code-point-at-cursor-over-full-screen screen, 0x20/space, fg 0/bg  # clear old cursor
      move-cursor-left screen
      loop $read-line-from-keyboard:loop
    }
    var key2/eax: int <- copy key
    append-byte out, key2
    var c/eax: code-point <- copy key2
    draw-code-point-at-cursor-over-full-screen screen, c, fg bg
    loop
  }
  # clear cursor
  draw-code-point-at-cursor-over-full-screen screen, 0x20/space, fg bg
}
