# Helpers for Unicode "code points".
# https://en.wikipedia.org/wiki/Code_point
#
# Mu has no characters, only code points and graphemes.
# Code points are the indivisible atoms of text streams.
# Graphemes are the smallest self-contained unit of text.
# Graphemes may consist of multiple code points.
#
# Mu graphemes are always represented in utf-8, and they are required to fit
# in 4 bytes.
#
# Mu doesn't currently support combining code points, or graphemes made of
# multiple code points.

# transliterated from tb_utf8_unicode_to_char in https://github.com/nsf/termbox
# https://wiki.tcl-lang.org/page/UTF%2D8+bit+by+bit explains the algorithm
fn to-grapheme in: code-point -> out/eax: grapheme {
$to-grapheme:body: {
  var c/eax: int <- copy in
  var num-trailers/ecx: int <- copy 0
  var first/edx: int <- copy 0
  $to-grapheme:compute-length: {
    # single byte: just return it
    compare c, 0x7f
    {
      break-if->
      out <- copy c
      break $to-grapheme:body
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
  var byte-shifts/ebx: int <- copy 0
  var result/edi: int <- copy 0
  {
    compare num-trailers, 0
    break-if-<=
    var tmp/esi: int <- copy c
    tmp <- and 0x3f
    tmp <- or 0x80
    tmp <- shift-left-bytes tmp, byte-shifts
    result <- or tmp
    # update loop state
    c <- shift-right 6
    byte-shifts <- increment
    num-trailers <- decrement
    loop
  }
  # emit engine
  var tmp/esi: int <- copy c
  tmp <- or first
  tmp <- shift-left-bytes tmp, byte-shifts
  result <- or tmp
  #
  out <- copy result
}
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

# smallest 2-byte utf-8
fn test-to-grapheme-two-bytes-min {
  var in/eax: code-point <- copy 0x80       #        10     000000
  var out/eax: grapheme <- to-grapheme in
  var out-int/eax: int <- copy out
  check-ints-equal out-int, 0xc280, "F 2gr" # 110 00010  10 000000
}

# largest 2-byte utf-8
fn test-to-grapheme-two-bytes-max {
  var in/eax: code-point <- copy 0x7ff      #     11111     111111
  var out/eax: grapheme <- to-grapheme in
  var out-int/eax: int <- copy out
  check-ints-equal out-int, 0xdfbf, "F 2gr" # 110 11111  10 111111
}

# smallest 3-byte utf-8
fn test-to-grapheme-three-bytes-min {
  var in/eax: code-point <- copy 0x800      #               100000     000000
  var out/eax: grapheme <- to-grapheme in
  var out-int/eax: int <- copy out
  check-ints-equal out-int, 0xc280, "F 2gr" # 1110 0000  10 100000  10 000000
}

# needed because available primitives only shift by a literal/constant number of bits
fn shift-left-bytes n: int, k: int -> result/esi: int {
  var i/eax: int <- copy 0
  result <- copy n
  {
    compare i, k
    break-if->=
    compare i, 4  # only 4 bytes in 32 bits
    break-if->=
    result <- shift-left 8
    i <- increment
    loop
  }
}

fn test-shift-left-bytes-0 {
  var result/esi: int <- shift-left-bytes 1, 0
  check-ints-equal result, 1, "F - shift-left-bytes 0"
}

fn test-shift-left-bytes-1 {
  var result/esi: int <- shift-left-bytes 1, 1
  check-ints-equal result, 0x100, "F - shift-left-bytes 1"
}

fn test-shift-left-bytes-2 {
  var result/esi: int <- shift-left-bytes 1, 2
  check-ints-equal result, 0x10000, "F - shift-left-bytes 2"
}

fn test-shift-left-bytes-3 {
  var result/esi: int <- shift-left-bytes 1, 3
  check-ints-equal result, 0x1000000, "F - shift-left-bytes 3"
}

fn test-shift-left-bytes-4 {
  var result/esi: int <- shift-left-bytes 1, 4
  check-ints-equal result, 0, "F - shift-left-bytes 4"
}

fn test-shift-left-bytes-5 {
  var result/esi: int <- shift-left-bytes 1, 5
  check-ints-equal result, 0, "F - shift-left-bytes >4"
}

#? fn main {
#?   run-tests
#? }
