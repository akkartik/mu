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
      compare done?, 0  # false
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
  # phase 2: construct table of 2-sums
  var two-sums-storage: (array int 0x10000)  # 256 * 256 ints
  var two-sums/edi: (addr array int) <- address two-sums-storage
  var i/eax: int <- copy 0
  {
    compare i, numbers-index
    break-if->=
    # for j from i+1 to end
    var j/edx: int <- copy i
    j <- increment
    {
      compare j, numbers-index
      break-if->=
      {
        compare i, j
        break-if-=
        var result-index/ebx: int <- copy 0x100
        result-index <- multiply i
        result-index <- add j
        var dest/ebx: (addr int) <- index two-sums, result-index
        var src/eax: (addr int) <- index numbers, i
        var result/eax: int <- copy *src
        var src2/edx: (addr int) <- index numbers, j
        result <- add *src2
        copy-to *dest, result
      }
      j <- increment
      loop
    }
    i <- increment
    loop
  }
  # phase 3: for each number in two-sums, check if 2020-it is in the rest of
  # the array
  return 1  # not found
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
      return 1  # true
    }
    i <- increment
    loop
  }
  return 0  # false
}
