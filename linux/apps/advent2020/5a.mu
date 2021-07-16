# https://adventofcode.com/2020/day/5
#
# To run (on Linux):
#   $ git clone https://github.com/akkartik/mu
#   $ cd mu
#   $ ./translate apps/advent2020/5a.mu
#   $ ./a.elf < input
#
# You'll need to register to download the 'input' file for yourself.

fn main -> _/ebx: int {
  var line-storage: (stream byte 0x10)  # 16 bytes is enough
  var line/edx: (addr stream byte) <- address line-storage
  var max-seat-id/edi: int <- copy 0
  {
    # read line from stdin
    clear-stream line
    read-line-from-real-keyboard line
    print-stream-to-real-screen line
    # if line is empty (not even a newline), quit
    var done?/eax: boolean <- stream-empty? line
    compare done?, 0/false
    break-if-!=
    # process line
    var seat-id/eax: int <- convert-from-binary line
    compare seat-id, max-seat-id
    {
      break-if-<=
      max-seat-id <- copy seat-id
    }
    loop
  }
  print-int32-decimal 0, max-seat-id
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
#?     print-string 0, "char: "
#?     {
#?       var c2/eax: int <- copy c
#?       print-int32-hex 0, c2
#?     }
#?     print-string 0, "\n"
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
#?     print-string 0, "bit: "
#?     print-int32-decimal 0, bit
#?     print-string 0, "\n"
    var bit-value/eax: int <- repeated-shift-left bit, i
#?     print-string 0, "bit value: "
#?     print-int32-decimal 0, bit-value
#?     print-string 0, "\n"
    result <- add bit-value
#?     print-string 0, "result: "
#?     print-int32-decimal 0, result
#?     print-string 0, "\n"
    i <- decrement
    loop
  }
  print-int32-decimal 0, result
  print-string 0, "\n"
  return result
}
