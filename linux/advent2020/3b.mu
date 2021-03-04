# https://adventofcode.com/2020/day/3
#
# To run (on Linux):
#   $ git clone https://github.com/akkartik/mu
#   $ cd mu
#   $ ./translate advent2020/3a.mu
#   $ ./a.elf < input
#
# You'll need to register to download the 'input' file for yourself.

fn main -> _/ebx: int {
  # represent trees in a 2D array of ints
  # wasteful since each tree is just one bit
  var trees-storage: (array int 0x2800)  # 10k ints
  var trees/esi: (addr array int) <- address trees-storage
  var trees-length/ecx: int <- copy 0
  var num-rows: int
  var width: int
  # phase 1: parse each row of trees from stdin
  {
    var line-storage: (stream byte 0x40)  # 64 bytes
    var line/edx: (addr stream byte) <- address line-storage
    {
      # read line from stdin
      clear-stream line
      read-line-from-real-keyboard line
      # if line is empty (not even a newline), quit
      var done?/eax: boolean <- stream-empty? line
      compare done?, 0/false
      break-if-!=
      # wastefully recompute width on every line
      # zero error-checking; we assume input lines are all equally long
      copy-to width, 0
      # turn each byte into a tree and append it
      $main:line-loop: {
        var done?/eax: boolean <- stream-empty? line
        compare done?, 0/false
        break-if-!=
#?         print-int32-decimal 0, num-rows
#?         print-string 0, " "
#?         print-int32-decimal 0, width
#?         print-string 0, "\n"
        var dest/ebx: (addr int) <- index trees, trees-length
        var c/eax: byte <- read-byte line
        # newline comes only at end of line
        compare c, 0xa/newline
        break-if-=
        # '#' = tree
        compare c, 0x23/hash
        {
          break-if-!=
          copy-to *dest, 1
        }
        # anything else = no tree
        {
          break-if-=
          copy-to *dest, 0
        }
        increment width
        trees-length <- increment
        loop
      }
      increment num-rows
      loop
    }
  }
  # phase 2: compute
  var product/edi: int <- copy 1
  var result/eax: int <- num-trees-hit trees, width, num-rows, 1, 1
  print-int32-decimal 0, result
  print-string 0, " x "
  product <- multiply result
  var result/eax: int <- num-trees-hit trees, width, num-rows, 3, 1
  print-int32-decimal 0, result
  print-string 0, " x "
  product <- multiply result
  var result/eax: int <- num-trees-hit trees, width, num-rows, 5, 1
  print-int32-decimal 0, result
  print-string 0, " x "
  product <- multiply result
  var result/eax: int <- num-trees-hit trees, width, num-rows, 7, 1
  print-int32-decimal 0, result
  print-string 0, " x "
  product <- multiply result
  var result/eax: int <- num-trees-hit trees, width, num-rows, 1, 2
  print-int32-decimal 0, result
  print-string 0, " = "
  product <- multiply result
  print-int32-hex 0, product
  print-string 0, "\n"
  return 0
}

fn num-trees-hit trees: (addr array int), width: int, num-rows: int, right: int, down: int -> _/eax: int {
#?   print-string 0, "== "
#?   print-int32-decimal 0, right
#?   print-string 0, " "
#?   print-int32-decimal 0, down
#?   print-string 0, "\n"
  var row/ecx: int <- copy 0
  var col/edx: int <- copy 0
  var num-trees-hit/edi: int <- copy 0
  {
    compare row, num-rows
    break-if->=
#?     print-int32-decimal 0, col
#?     print-string 0, "\n"
    var curr/eax: int <- index2d trees, row, col, width
    compare curr, 0
    {
      break-if-=
      num-trees-hit <- increment
    }
    col <- add right
    row <- add down
    loop
  }
  return num-trees-hit
}

fn index2d _arr: (addr array int), _row: int, _col: int, width: int -> _/eax: int {
  # handle repeating columns of trees
  var dummy/eax: int <- copy 0
  var col/edx: int <- copy 0
  dummy, col <- integer-divide _col, width
#?   print-string 0, "  "
#?   print-int32-decimal 0, col
#?   print-string 0, "\n"
  # compute index
  var index/eax: int <- copy _row
  index <- multiply width
  index <- add col
  # look up array
  var arr/esi: (addr array int) <- copy _arr
  var src/eax: (addr int) <- index arr, index
  return *src
}
