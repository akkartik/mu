# Tests for Mu's stream primitives.

fn test-stream {
  # - write an int to a stream, then read it back
  # step 1: initialize
  var s: (stream int 4)
  var s2/ecx: (addr stream int) <- address s
  var tmp/eax: boolean <- stream-empty? s2
  check tmp, "F - test-stream/empty?/0"
  tmp <- stream-full? s2
  check-not tmp, "F - test-stream/full?/0"
  # step 2: write to stream
  var x: int
  copy-to x, 0x34
  var x2/edx: (addr int) <- address x
  write-to-stream s2, x2
  tmp <- stream-empty? s2
  check-not tmp, "F - test-stream/empty?/1"
  tmp <- stream-full? s2
  check-not tmp, "F - test-stream/full?/1"
  # step 3: modify the value written (should make no difference)
  copy-to x, 0
  # step 4: read back
  var y: int
  var y2/ebx: (addr int) <- address y
  read-from-stream s2, y2
  tmp <- stream-empty? s2
  check tmp, "F - test-stream/empty?/2"
  tmp <- stream-full? s2
  check-not tmp, "F - test-stream/full?/2"
  # we read back what was written
  check-ints-equal y, 0x34, "F - test-stream"
}

fn test-stream-full {
  # write an int to a stream of capacity 1
  var s: (stream int 1)
  var s2/ecx: (addr stream int) <- address s
  var tmp/eax: boolean <- stream-full? s2
  check-not tmp, "F - test-stream-full?/pre"
  var x: int
  var x2/edx: (addr int) <- address x
  write-to-stream s2, x2
  tmp <- stream-full? s2
  check tmp, "F - test-stream-full?"
}

fn test-fake-input-buffered-file {
  var foo: (handle buffered-file)
  var foo-ah/eax: (addr handle buffered-file) <- address foo
  populate-buffered-file-containing "abc", foo-ah
  var foo-addr/eax: (addr buffered-file) <- lookup foo
  var s: (stream byte 0x100)
  var result/ecx: (addr stream byte) <- address s
  read-line-buffered foo-addr, result
  check-stream-equal result, "abc", "F - test-fake-input-buffered-file"
}

fn test-fake-output-buffered-file {
  var foo: (handle buffered-file)
  var foo-ah/eax: (addr handle buffered-file) <- address foo
  new-buffered-file foo-ah
  var foo-addr/eax: (addr buffered-file) <- lookup foo
  write-buffered foo-addr, "abc"
  var s: (stream byte 0x100)
  var result/ecx: (addr stream byte) <- address s
  read-line-buffered foo-addr, result
  check-stream-equal result, "abc", "F - test-fake-output-buffered-file"
}
