# Helpers for Unicode.
#
# Mu has no characters, only code points and graphemes.
# Code points are the indivisible atoms of text streams.
#   https://en.wikipedia.org/wiki/Code_point
# Graphemes are the smallest self-contained unit of text.
# Graphemes may consist of multiple code points.
#
# Mu graphemes are always represented in utf-8, and they are required to fit
# in 4 bytes. (This can be confusing if you focus just on ASCII, where Mu's
# graphemes and code-points are identical.)
#
# Mu doesn't currently support combining code points, or graphemes made of
# multiple code points. One day we will.
#   https://en.wikipedia.org/wiki/Combining_character

fn test-unicode-serialization-and-deserialization {
  var i/ebx: int <- copy 0
  var init?/esi: boolean <- copy 1/true
  {
    compare i, 0x10000  # 32 bits of utf-8 are sufficient for https://en.wikipedia.org/wiki/Plane_(Unicode)#Basic_Multilingual_Plane
                        # but not emoji
    break-if->=
    var c/eax: code-point <- copy i
    var _g/eax: grapheme <- to-grapheme c
    var g/ecx: grapheme <- copy _g
    var c2/eax: code-point <- to-code-point g
    compare i, c2
    {
      break-if-=
      {
        compare init?, 0/false
        break-if-=
        draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "F - test-unicode-serialization-and-deserialization: ", 3/fg 0/bg
      }
      init? <- copy 0/false
      draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, i, 3/fg 0/bg
      draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "/", 3/fg 0/bg
      {
        var x/eax: int <- copy g
        draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, x, 3/fg 0/bg
      }
      draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "/", 3/fg 0/bg
      {
        var x2/eax: int <- copy c2
        draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, x2, 3/fg 0/bg
      }
      draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, " ", 3/fg 0/bg
    }
    i <- add 0xf  # to speed things up; ensure increment is not a power of 2
    loop
  }
}

# transliterated from tb_utf8_char_to_unicode in https://github.com/nsf/termbox
fn to-code-point in: grapheme -> _/eax: code-point {
  var g/ebx: int <- copy in
  # if single byte, just return it
  {
    compare g, 0xff
    break-if->
    var result/eax: code-point <- copy g
    return result
  }
  #
  var len/edx: int <- grapheme-length in
  # extract bits from first byte
  var b/eax: byte <- copy-byte g
  var result/edi: code-point <- copy b
  {
    compare len, 2
    break-if-!=
    result <- and 0x1f
  }
  {
    compare len, 3
    break-if-!=
    result <- and 0x0f
  }
  {
    compare len, 4
    break-if-!=
    result <- and 0x07
  }
  # extract bits from remaining bytes
  g <- shift-right 8
  var i/ecx: int <- copy 1
  {
    compare i, len
    break-if->=
    var b/eax: byte <- copy-byte g
    b <- and 0x3f
    result <- shift-left 6
    result <- or b
    g <- shift-right 8
    i <- increment
    loop
  }
  return result
}

# transliterated from tb_utf8_unicode_to_char in https://github.com/nsf/termbox
# https://wiki.tcl-lang.org/page/UTF%2D8+bit+by+bit explains the algorithm
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

fn grapheme-length g: grapheme -> _/edx: int {
  {
    compare g, 0xff
    break-if->
    return 1
  }
  {
    compare g, 0xffff
    break-if->
    return 2
  }
  {
    compare g, 0xffffff
    break-if->
    return 3
  }
  return 4
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
