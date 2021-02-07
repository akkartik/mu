# Helpers for Unicode.
#
# Mu has no characters, only code points and graphemes.
# Code points are the indivisible atoms of text streams.
#   https://en.wikipedia.org/wiki/Code_point
# Graphemes are the smallest self-contained unit of text.
# Graphemes may consist of multiple code points.
#
# Mu graphemes are always represented in utf-8, and they are required to fit
# in 4 bytes.
#
# Mu doesn't currently support combining code points, or graphemes made of
# multiple code points. One day we will.
# We also don't currently support code points that translate into multiple
# or wide graphemes. (In particular, Tab will never be supported.)

# transliterated from tb_utf8_unicode_to_char in https://github.com/nsf/termbox
# https://wiki.tcl-lang.org/page/UTF%2D8+bit+by+bit explains the algorithm
#
# The day we want to support combining characters, this function will need to
# take multiple code points. Or something.
fn to-grapheme in: code-point -> _/eax: grapheme {
  var c/eax: int <- copy in
  var num-trailers/ecx: int <- copy 0
  var first/edx: int <- copy 0
  $to-grapheme:compute-length: {
    # single byte: just return it
    compare c, 0x7f
    {
      break-if->
      var g/eax: grapheme <- copy c
      return g
    }
    # 2 bytes
    compare c, 0x7ff
    {
      break-if->
      num-trailers <- copy 1
      first <- copy 0xc0
      break $to-grapheme:compute-length
    }
    # 3 bytes
    compare c, 0xffff
    {
      break-if->
      num-trailers <- copy 2
      first <- copy 0xe0
      break $to-grapheme:compute-length
    }
    # 4 bytes
    compare c, 0x1fffff
    {
      break-if->
      num-trailers <- copy 3
      first <- copy 0xf0
      break $to-grapheme:compute-length
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
  var result/edi: grapheme <- copy 0
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

# single-byte code point have identical graphemes
fn test-to-grapheme-single-byte {
  var in-int/ecx: int <- copy 0
  {
    compare in-int, 0x7f
    break-if->
    var in/eax: code-point <- copy in-int
    var out/eax: grapheme <- to-grapheme in
    var out-int/eax: int <- copy out
    check-ints-equal out-int, in-int, "F - test-to-grapheme-single-byte"
    in-int <- increment
    loop
  }
}

                                                              # byte       | byte      | byte      | byte
# smallest 2-byte utf-8
fn test-to-grapheme-two-bytes-min {
  var in/eax: code-point <- copy 0x80                         #                                 10     00-0000
  var out/eax: grapheme <- to-grapheme in
  var out-int/eax: int <- copy out
  check-ints-equal out-int, 0x80c2, "F - to-grapheme/2a"      #                         110 0-0010  10 00-0000
}

# largest 2-byte utf-8
fn test-to-grapheme-two-bytes-max {
  var in/eax: code-point <- copy 0x7ff                        #                             1-1111     11-1111
  var out/eax: grapheme <- to-grapheme in
  var out-int/eax: int <- copy out
  check-ints-equal out-int, 0xbfdf, "F - to-grapheme/2b"      #                         110 1-1111  10 11-1111
}

# smallest 3-byte utf-8
fn test-to-grapheme-three-bytes-min {
  var in/eax: code-point <- copy 0x800                        #                            10-0000     00-0000
  var out/eax: grapheme <- to-grapheme in
  var out-int/eax: int <- copy out
  check-ints-equal out-int, 0x80a0e0, "F - to-grapheme/3a"    #              1110 0000  10 10-0000  10 00-0000
}

# largest 3-byte utf-8
fn test-to-grapheme-three-bytes-max {
  var in/eax: code-point <- copy 0xffff                       #                   1111     11-1111     11-1111
  var out/eax: grapheme <- to-grapheme in
  var out-int/eax: int <- copy out
  check-ints-equal out-int, 0xbfbfef, "F - to-grapheme/3b"    #              1110 1111  10 11-1111  10 11-1111
}

# smallest 4-byte utf-8
fn test-to-grapheme-four-bytes-min {
  var in/eax: code-point <- copy 0x10000                      #                 1-0000     00-0000     00-0000
  var out/eax: grapheme <- to-grapheme in
  var out-int/eax: int <- copy out
  check-ints-equal out-int, 0x808090f0, "F - to-grapheme/4a"  # 1111-0 000  10 01-0000  10 00-0000  10 00-0000
}

# largest 4-byte utf-8
fn test-to-grapheme-four-bytes-max {
  var in/eax: code-point <- copy 0x1fffff                     #        111     11-1111     11-1111     11-1111
  var out/eax: grapheme <- to-grapheme in
  var out-int/eax: int <- copy out
  check-ints-equal out-int, 0xbfbfbff7, "F - to-grapheme/4b"  # 1111-0 111  10 11-1111  10 11-1111  10 11-1111
}

# read the next grapheme from a stream of bytes
fn read-grapheme in: (addr stream byte) -> _/eax: grapheme {
  # if at eof, return EOF
  {
    var eof?/eax: boolean <- stream-empty? in
    compare eof?, 0/false
    break-if-=
    return 0xffffffff
  }
  var c/eax: byte <- read-byte in
  var num-trailers/ecx: int <- copy 0
  $read-grapheme:compute-length: {
    # single byte: just return it
    compare c, 0xc0
    {
      break-if->=
      var g/eax: grapheme <- copy c
      return g
    }
    compare c, 0xfe
    {
      break-if-<
      var g/eax: grapheme <- copy c
      return g
    }
    # 2 bytes
    compare c, 0xe0
    {
      break-if->=
      num-trailers <- copy 1
      break $read-grapheme:compute-length
    }
    # 3 bytes
    compare c, 0xf0
    {
      break-if->=
      num-trailers <- copy 2
      break $read-grapheme:compute-length
    }
    # 4 bytes
    compare c, 0xf8
    {
      break-if->=
      num-trailers <- copy 3
      break $read-grapheme:compute-length
    }
$read-grapheme:abort: {
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
  var result/edi: grapheme <- copy c
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

fn test-read-grapheme {
  var s: (stream byte 0x30)
  var s2/ecx: (addr stream byte) <- address s
  write s2, "aΒc世d界e"
  var c/eax: grapheme <- read-grapheme s2
  var n/eax: int <- copy c
  check-ints-equal n, 0x61, "F - test grapheme/0"
  var c/eax: grapheme <- read-grapheme s2
  var n/eax: int <- copy c
  check-ints-equal n, 0x92ce/greek-capital-letter-beta, "F - test grapheme/1"
  var c/eax: grapheme <- read-grapheme s2
  var n/eax: int <- copy c
  check-ints-equal n, 0x63, "F - test grapheme/2"
  var c/eax: grapheme <- read-grapheme s2
  var n/eax: int <- copy c
  check-ints-equal n, 0x96b8e4, "F - test grapheme/3"
  var c/eax: grapheme <- read-grapheme s2
  var n/eax: int <- copy c
  check-ints-equal n, 0x64, "F - test grapheme/4"
  var c/eax: grapheme <- read-grapheme s2
  var n/eax: int <- copy c
  check-ints-equal n, 0x8c95e7, "F - test grapheme/5"
  var c/eax: grapheme <- read-grapheme s2
  var n/eax: int <- copy c
  check-ints-equal n, 0x65, "F - test grapheme/6"
}

fn read-grapheme-buffered in: (addr buffered-file) -> _/eax: grapheme {
  var c/eax: byte <- read-byte-buffered in
  var num-trailers/ecx: int <- copy 0
  $read-grapheme-buffered:compute-length: {
    # single byte: just return it
    compare c, 0xc0
    {
      break-if->=
      var g/eax: grapheme <- copy c
      return g
    }
    compare c, 0xfe
    {
      break-if-<
      var g/eax: grapheme <- copy c
      return g
    }
    # 2 bytes
    compare c, 0xe0
    {
      break-if->=
      num-trailers <- copy 1
      break $read-grapheme-buffered:compute-length
    }
    # 3 bytes
    compare c, 0xf0
    {
      break-if->=
      num-trailers <- copy 2
      break $read-grapheme-buffered:compute-length
    }
    # 4 bytes
    compare c, 0xf8
    {
      break-if->=
      num-trailers <- copy 3
      break $read-grapheme-buffered:compute-length
    }
$read-grapheme-buffered:abort: {
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
  var result/edi: grapheme <- copy c
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

# To run all tests, uncomment this and run:
#   $ ./translate_mu  &&  ./a.elf
#? fn main -> _/ebx: int {
#?   run-tests
#?   r <- copy 0
#? }

# write a grapheme to a stream of bytes
# this is like write-to-stream, except we skip leading 0 bytes
fn write-grapheme out: (addr stream byte), g: grapheme {
$write-grapheme:body: {
  var c/eax: int <- copy g
  append-byte out, c  # first byte is always written
  c <- shift-right 8
  compare c, 0
  break-if-= $write-grapheme:body
  append-byte out, c
  c <- shift-right 8
  compare c, 0
  break-if-= $write-grapheme:body
  append-byte out, c
  c <- shift-right 8
  compare c, 0
  break-if-= $write-grapheme:body
  append-byte out, c
}
}
