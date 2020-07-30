# Tests for Mu's stream primitives.

fn test-stream {
  # write an int to a stream, then read it back
  var s: (stream int 4)
  var s2/ecx: (addr stream int 4) <- address s
  var x: int
  copy-to x, 0x34
  var x2/edx: (addr int) <- address x
  write-to-stream s2, x2
  var y: int
  var y2/ebx: (addr int) <- address y
  read-from-stream s2, y2
  check-ints-equal y, 0x34, "F - test-stream"
}
