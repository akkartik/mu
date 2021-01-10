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
    # TODO: print error message to stderr
    compare c, 0x1fffff
    {
      break-if->
      return 0
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

# TODO: bring in tests once we have check-ints-equal

# read the next grapheme from a stream of bytes
fn read-grapheme in: (addr stream byte) -> _/eax: grapheme {
  # if at eof, return EOF
  {
    var eof?/eax: boolean <- stream-empty? in
    compare eof?, 0  # false
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
    # TODO: print error message
    return 0
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
