# https://adventofcode.com/2020/day/1
#
# To run (on Linux):
#   $ git clone https://github.com/akkartik/mu
#   $ cd mu
#   $ ./translate_mu apps/advent2020/1a.mu
#   $ ./a.elf < input
#   found
#   1353 667
#   902451
#
# You'll need to register to download the 'input' file for yourself.

fn main -> _/ebx: int {
  # data structure
  var numbers-storage: (array int 0x100)  # 256 ints
  var numbers/esi: (addr array int) <- address numbers-storage
  var numbers-index/ecx: int <- copy 0
  # phase 1: parse each line from stdin and add it to numbers
  {
    var line-storage: (stream byte 0x100)  # 256 bytes
    var line/edx: (addr stream byte) <- address line-storage
    {
#?       print-string 0, "== iter\n"
      # read line from stdin
      clear-stream line
      read-line-from-real-keyboard line
      # if line is empty (not even a newline), quit
      var done?/eax: boolean <- stream-empty? line
      compare done?, 0/false
      break-if-!=
#?       print-stream-to-real-screen line
      # convert line to int and append it to numbers
      var n/eax: int <- parse-decimal-int-from-stream line
#?       print-int32-decimal 0, n
#?       print-string 0, "\n"
      var dest/ebx: (addr int) <- index numbers, numbers-index
      copy-to *dest, n
      numbers-index <- increment
#?       print-string 0, "== "
#?       print-int32-decimal 0, numbers-index
#?       print-string 0, "\n"
      loop
    }
  }
  # phase 2: for each number in the array, check if 2020-it is in the rest of
  # the array
  var i/eax: int <- copy 0
  {
    compare i, numbers-index
    break-if->=
    var src/ebx: (addr int) <- index numbers, i
#?     print-int32-decimal 0, *src
#?     print-string 0, "\n"
    var target/ecx: int <- copy 0x7e4  # 2020
    target <- subtract *src
    {
      var found?/eax: boolean <- find-after numbers, i, target
      compare found?, 0/false
      break-if-=
      print-string 0, "found\n"
      print-int32-decimal 0, *src
      print-string 0, " "
      print-int32-decimal 0, target
      print-string 0, "\n"
      target <- multiply *src
      print-int32-decimal 0, target
      print-string 0, "\n"
      return 0/success
    }
    i <- increment
    loop
  }
  return 1/not-found
}

fn find-after _numbers: (addr array int), start: int, _target: int -> _/eax: boolean {
  var numbers/esi: (addr array int) <- copy _numbers
  var target/edi: int <- copy _target
  var len/ecx: int <- length numbers
  var i/eax: int <- copy start
  i <- increment
  {
    compare i, len
    break-if->=
    var src/edx: (addr int) <- index numbers, i
    # if *src == target, return true
    compare *src, target
    {
      break-if-!=
      return 1/true
    }
    i <- increment
    loop
  }
  return 0/false
}
