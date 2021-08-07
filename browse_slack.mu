fn main screen: (addr screen), keyboard: (addr keyboard), data-disk: (addr disk) {
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, "loading data disk..", 3/fg 0/bg
  # too large for stack
  var s-h: (handle stream byte)
  var s-ah/ebx: (addr handle stream byte) <- address s-h
  populate-stream s-ah, 0x4000000
  var s/eax: (addr stream byte) <- lookup *s-ah
  load-sectors data-disk, 0/lba, 0x20000/sectors, s
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, "done", 3/fg 0/bg
}
