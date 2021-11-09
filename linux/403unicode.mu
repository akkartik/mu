# Helpers for Unicode.
#
# Mu has no characters, only code points and code-point-utf8s.
# Code points are the indivisible atoms of text streams.
#   https://en.wikipedia.org/wiki/Code_point
# Graphemes are the smallest self-contained unit of text.
# Graphemes may consist of multiple code points.
#
# Mu code-point-utf8s are always represented in utf-8, and they are required to fit
# in 4 bytes.
#
# Mu doesn't currently support combining code points, or code-point-utf8s made of
# multiple code points. One day we will.
# On Linux, we also don't currently support code points that translate into
# multiple or wide code-point-utf8s. (In particular, Tab will never be supported.)

# transliterated from tb_utf8_unicode_to_char in https://github.com/nsf/termbox
# https://wiki.tcl-lang.org/page/UTF%2D8+bit+by+bit explains the algorithm
fn to-utf8 in: code-point -> _/eax: code-point-utf8 {
  var c/eax: int <- copy in
  var num-trailers/ecx: int <- copy 0
  var first/edx: int <- copy 0
  $to-utf8:compute-length: {
    # single byte: just return it
    compare c, 0x7f
    {
      break-if->
      var g/eax: code-point-utf8 <- copy c
      return g
    }
    # 2 bytes
    compare c, 0x7ff
    {
      break-if->
      num-trailers <- copy 1
      first <- copy 0xc0
      break $to-utf8:compute-length
    }
    # 3 bytes
    compare c, 0xffff
    {
      break-if->
      num-trailers <- copy 2
      first <- copy 0xe0
      break $to-utf8:compute-length
    }
    # 4 bytes
    compare c, 0x1fffff
    {
      break-if->
      num-trailers <- copy 3
      first <- copy 0xf0
      break $to-utf8:compute-length
    }
    # more than 4 bytes: unsupported
    # TODO: print to stderr
    compare c, 0x1fffff
    {
      break-if->
      print-string-to-real-screen "unsupported code point "
      print-int32-hex-to-real-screen c
      print-string-to-real-screen "\n"
      var exit-status/ebx: int <- copy 1
      syscall_exit
    }
  }
  # emit trailer bytes, 6 bits from 'in', first two bits '10'
  var result/edi: code-point-utf8 <- copy 0
  {
    compare num-trailers, 0
    break-if-<=
    var tmp/esi: int <- copy c
    tmp <- and 0x3f
    tmp <- or 0x80
    result <- shift-left 8
    result <- or tmp
    # update loop state
    c <- shift-right 6
    num-trailers <- decrement
    loop
  }
  # emit engine
  result <- shift-left 8
  result <- or c
  result <- or first
  #
  return result
}

# single-byte code point have identical code-point-utf8s
fn test-to-utf8-single-byte {
  var in-int/ecx: int <- copy 0
  {
    compare in-int, 0x7f
    break-if->
    var in/eax: code-point <- copy in-int
    var out/eax: code-point-utf8 <- to-utf8 in
    var out-int/eax: int <- copy out
    check-ints-equal out-int, in-int, "F - test-to-utf8-single-byte"
    in-int <- increment
    loop
  }
}

                                                              # byte       | byte      | byte      | byte
# smallest 2-byte utf-8
fn test-to-utf8-two-bytes-min {
  var in/eax: code-point <- copy 0x80                         #                                 10     00-0000
  var out/eax: code-point-utf8 <- to-utf8 in
  var out-int/eax: int <- copy out
  check-ints-equal out-int, 0x80c2, "F - to-utf8/2a"      #                         110 0-0010  10 00-0000
}

# largest 2-byte utf-8
fn test-to-utf8-two-bytes-max {
  var in/eax: code-point <- copy 0x7ff                        #                             1-1111     11-1111
  var out/eax: code-point-utf8 <- to-utf8 in
  var out-int/eax: int <- copy out
  check-ints-equal out-int, 0xbfdf, "F - to-utf8/2b"      #                         110 1-1111  10 11-1111
}

# smallest 3-byte utf-8
fn test-to-utf8-three-bytes-min {
  var in/eax: code-point <- copy 0x800                        #                            10-0000     00-0000
  var out/eax: code-point-utf8 <- to-utf8 in
  var out-int/eax: int <- copy out
  check-ints-equal out-int, 0x80a0e0, "F - to-utf8/3a"    #              1110 0000  10 10-0000  10 00-0000
}

# largest 3-byte utf-8
fn test-to-utf8-three-bytes-max {
  var in/eax: code-point <- copy 0xffff                       #                   1111     11-1111     11-1111
  var out/eax: code-point-utf8 <- to-utf8 in
  var out-int/eax: int <- copy out
  check-ints-equal out-int, 0xbfbfef, "F - to-utf8/3b"    #              1110 1111  10 11-1111  10 11-1111
}

# smallest 4-byte utf-8
fn test-to-utf8-four-bytes-min {
  var in/eax: code-point <- copy 0x10000                      #                 1-0000     00-0000     00-0000
  var out/eax: code-point-utf8 <- to-utf8 in
  var out-int/eax: int <- copy out
  check-ints-equal out-int, 0x808090f0, "F - to-utf8/4a"  # 1111-0 000  10 01-0000  10 00-0000  10 00-0000
}

# largest 4-byte utf-8
fn test-to-utf8-four-bytes-max {
  var in/eax: code-point <- copy 0x1fffff                     #        111     11-1111     11-1111     11-1111
  var out/eax: code-point-utf8 <- to-utf8 in
  var out-int/eax: int <- copy out
  check-ints-equal out-int, 0xbfbfbff7, "F - to-utf8/4b"  # 1111-0 111  10 11-1111  10 11-1111  10 11-1111
}

# read the next code-point-utf8 from a stream of bytes
fn read-code-point-utf8 in: (addr stream byte) -> _/eax: code-point-utf8 {
  # if at eof, return EOF
  {
    var eof?/eax: boolean <- stream-empty? in
    compare eof?, 0/false
    break-if-=
    return 0xffffffff
  }
  var c/eax: byte <- read-byte in
  var num-trailers/ecx: int <- copy 0
  $read-code-point-utf8:compute-length: {
    # single byte: just return it
    compare c, 0xc0
    {
      break-if->=
      var g/eax: code-point-utf8 <- copy c
      return g
    }
    compare c, 0xfe
    {
      break-if-<
      var g/eax: code-point-utf8 <- copy c
      return g
    }
    # 2 bytes
    compare c, 0xe0
    {
      break-if->=
      num-trailers <- copy 1
      break $read-code-point-utf8:compute-length
    }
    # 3 bytes
    compare c, 0xf0
    {
      break-if->=
      num-trailers <- copy 2
      break $read-code-point-utf8:compute-length
    }
    # 4 bytes
    compare c, 0xf8
    {
      break-if->=
      num-trailers <- copy 3
      break $read-code-point-utf8:compute-length
    }
$read-code-point-utf8:abort: {
      # TODO: print to stderr
      print-string-to-real-screen "utf-8 encodings larger than 4 bytes are not yet supported. First byte seen: "
      var n/eax: int <- copy c
      print-int32-hex-to-real-screen n
      print-string-to-real-screen "\n"
      var exit-status/ebx: int <- copy 1
      syscall_exit
    }
  }
  # prepend trailer bytes
  var result/edi: code-point-utf8 <- copy c
  var num-byte-shifts/edx: int <- copy 1
  {
    compare num-trailers, 0
    break-if-<=
    var tmp/eax: byte <- read-byte in
    var tmp2/eax: int <- copy tmp
    tmp2 <- shift-left-bytes tmp2, num-byte-shifts
    result <- or tmp2
    # update loop state
    num-byte-shifts <- increment
    num-trailers <- decrement
    loop
  }
  return result
}

fn test-read-code-point-utf8 {
  var s: (stream byte 0x30)
  var s2/ecx: (addr stream byte) <- address s
  write s2, "aΒc世d界e"
  var c/eax: code-point-utf8 <- read-code-point-utf8 s2
  var n/eax: int <- copy c
  check-ints-equal n, 0x61, "F - test code-point-utf8/0"
  var c/eax: code-point-utf8 <- read-code-point-utf8 s2
  var n/eax: int <- copy c
  check-ints-equal n, 0x92ce/greek-capital-letter-beta, "F - test code-point-utf8/1"
  var c/eax: code-point-utf8 <- read-code-point-utf8 s2
  var n/eax: int <- copy c
  check-ints-equal n, 0x63, "F - test code-point-utf8/2"
  var c/eax: code-point-utf8 <- read-code-point-utf8 s2
  var n/eax: int <- copy c
  check-ints-equal n, 0x96b8e4, "F - test code-point-utf8/3"
  var c/eax: code-point-utf8 <- read-code-point-utf8 s2
  var n/eax: int <- copy c
  check-ints-equal n, 0x64, "F - test code-point-utf8/4"
  var c/eax: code-point-utf8 <- read-code-point-utf8 s2
  var n/eax: int <- copy c
  check-ints-equal n, 0x8c95e7, "F - test code-point-utf8/5"
  var c/eax: code-point-utf8 <- read-code-point-utf8 s2
  var n/eax: int <- copy c
  check-ints-equal n, 0x65, "F - test code-point-utf8/6"
}

fn read-code-point-utf8-buffered in: (addr buffered-file) -> _/eax: code-point-utf8 {
  var c/eax: byte <- read-byte-buffered in
  var num-trailers/ecx: int <- copy 0
  $read-code-point-utf8-buffered:compute-length: {
    # single byte: just return it
    compare c, 0xc0
    {
      break-if->=
      var g/eax: code-point-utf8 <- copy c
      return g
    }
    compare c, 0xfe
    {
      break-if-<
      var g/eax: code-point-utf8 <- copy c
      return g
    }
    # 2 bytes
    compare c, 0xe0
    {
      break-if->=
      num-trailers <- copy 1
      break $read-code-point-utf8-buffered:compute-length
    }
    # 3 bytes
    compare c, 0xf0
    {
      break-if->=
      num-trailers <- copy 2
      break $read-code-point-utf8-buffered:compute-length
    }
    # 4 bytes
    compare c, 0xf8
    {
      break-if->=
      num-trailers <- copy 3
      break $read-code-point-utf8-buffered:compute-length
    }
$read-code-point-utf8-buffered:abort: {
      # TODO: print to stderr
      print-string-to-real-screen "utf-8 encodings larger than 4 bytes are not supported. First byte seen: "
      var n/eax: int <- copy c
      print-int32-hex-to-real-screen n
      print-string-to-real-screen "\n"
      var exit-status/ebx: int <- copy 1
      syscall_exit
    }
  }
  # prepend trailer bytes
  var result/edi: code-point-utf8 <- copy c
  var num-byte-shifts/edx: int <- copy 1
  {
    compare num-trailers, 0
    break-if-<=
    var tmp/eax: byte <- read-byte-buffered in
    var tmp2/eax: int <- copy tmp
    tmp2 <- shift-left-bytes tmp2, num-byte-shifts
    result <- or tmp2
    # update loop state
    num-byte-shifts <- increment
    num-trailers <- decrement
    loop
  }
  return result
}

# needed because available primitives only shift by a literal/constant number of bits
fn shift-left-bytes n: int, k: int -> _/eax: int {
  var i/ecx: int <- copy 0
  var result/eax: int <- copy n
  {
    compare i, k
    break-if->=
    compare i, 4  # only 4 bytes in 32 bits
    break-if->=
    result <- shift-left 8
    i <- increment
    loop
  }
  return result
}

fn test-shift-left-bytes-0 {
  var result/eax: int <- shift-left-bytes 1, 0
  check-ints-equal result, 1, "F - shift-left-bytes 0"
}

fn test-shift-left-bytes-1 {
  var result/eax: int <- shift-left-bytes 1, 1
  check-ints-equal result, 0x100, "F - shift-left-bytes 1"
}

fn test-shift-left-bytes-2 {
  var result/eax: int <- shift-left-bytes 1, 2
  check-ints-equal result, 0x10000, "F - shift-left-bytes 2"
}

fn test-shift-left-bytes-3 {
  var result/eax: int <- shift-left-bytes 1, 3
  check-ints-equal result, 0x1000000, "F - shift-left-bytes 3"
}

fn test-shift-left-bytes-4 {
  var result/eax: int <- shift-left-bytes 1, 4
  check-ints-equal result, 0, "F - shift-left-bytes 4"
}

fn test-shift-left-bytes-5 {
  var result/eax: int <- shift-left-bytes 1, 5
  check-ints-equal result, 0, "F - shift-left-bytes >4"
}

# write a code-point-utf8 to a stream of bytes
# this is like write-to-stream, except we skip leading 0 bytes
fn write-code-point-utf8 out: (addr stream byte), g: code-point-utf8 {
$write-code-point-utf8:body: {
  var c/eax: int <- copy g
  append-byte out, c  # first byte is always written
  c <- shift-right 8
  compare c, 0
  break-if-= $write-code-point-utf8:body
  append-byte out, c
  c <- shift-right 8
  compare c, 0
  break-if-= $write-code-point-utf8:body
  append-byte out, c
  c <- shift-right 8
  compare c, 0
  break-if-= $write-code-point-utf8:body
  append-byte out, c
}
}
