# https://adventofcode.com/2020/day/5
#
# To run (on Linux):
#   $ git clone https://github.com/akkartik/mu
#   $ cd mu
#   $ ./translate apps/advent2020/5b.mu
#   $ ./a.elf < input
#
# You'll need to register to download the 'input' file for yourself.

fn main -> _/ebx: int {
  var pass-storage: (array int 0x400)  # 1k ints
  var pass/esi: (addr array int) <- address pass-storage
  # phase 1: populate pass array
  var line-storage: (stream byte 0x10)  # 16 bytes is enough
  var line/edx: (addr stream byte) <- address line-storage
  {
    # read line from stdin
    clear-stream line
    read-line-from-real-keyboard line
    # if line is empty (not even a newline), quit
    var done?/eax: boolean <- stream-empty? line
    compare done?, 0/false
    break-if-!=
    # process line
    var seat-id/eax: int <- convert-from-binary line
    var dest/eax: (addr int) <- index pass, seat-id
    copy-to *dest, 1
    loop
  }
  # phase 2: skip empty seats
  var i/eax: int <- copy 0
  {
    compare i, 0x400
    break-if->=
    var src/ecx: (addr int) <- index pass, i
    compare *src, 0
    break-if-!=
    i <- increment
    loop
  }
  # phase 3: skip non-empty seats
  {
    compare i, 0x400
    break-if->=
    var src/ecx: (addr int) <- index pass, i
    compare *src, 0
    break-if-=
    i <- increment
    loop
  }
  print-int32-decimal 0, i
  print-string 0, "\n"
  return 0
}

fn convert-from-binary in: (addr stream byte) -> _/eax: int {
  var result/edi: int <- copy 0
  var i/ecx: int <- copy 9  # loop counter and also exponent
  {
    compare i, 0
    break-if-<
    var c/eax: byte <- read-byte in
    var bit/edx: int <- copy 0
    {
      compare c, 0x42/B
      break-if-!=
      bit <- copy 1
    }
    {
      compare c, 0x52/R
      break-if-!=
      bit <- copy 1
    }
    var bit-value/eax: int <- repeated-shift-left bit, i
    result <- add bit-value
    i <- decrement
    loop
  }
  return result
}
