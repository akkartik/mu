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
# multiple code points. One day we will.

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
  var result/edi: int <- copy 0
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

# To run all tests, uncomment this and run:
#   $ ./translate_mu ''  &&  ./a.elf
#? fn main -> r/ebx: int {
#?   run-tests
#?   r <- copy 0
#? }
