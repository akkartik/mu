# https://adventofcode.com/2020/day/2
#
# To run (on Linux):
#   $ git clone https://github.com/akkartik/mu
#   $ cd mu
#   $ ./translate apps/advent2020/2b.mu
#   $ ./a.elf < input
#
# You'll need to register to download the 'input' file for yourself.

fn main -> _/ebx: int {
  var valid-password-count/edi: int <- copy 0
  var line-storage: (stream byte 0x100)  # 256 bytes
  var line/edx: (addr stream byte) <- address line-storage
  var slice-storage: slice
  var slice/ecx: (addr slice) <- address slice-storage
  {
    # read line from stdin
    clear-stream line
    read-line-from-real-keyboard line
    # if line is empty (not even a newline), quit
    var done?/eax: boolean <- stream-empty? line
    compare done?, 0/false
    break-if-!=
    print-stream-to-real-screen line
    # slice = next-token(line, '-')
    next-token line, 0x2d, slice
    # pos1 = parse-int(slice)
    var _pos1/eax: int <- parse-decimal-int-from-slice slice
    var pos1/ebx: int <- copy _pos1
    var dash/eax: byte <- read-byte line  # skip '-'
    # slice = next-token(line, ' ')
    next-token line, 0x20, slice
    var _pos2/eax: int <- parse-decimal-int-from-slice slice
    var pos2/esi: int <- copy _pos2
    print-int32-decimal 0, pos1
    print-string 0, " "
    print-int32-decimal 0, pos2
    print-string 0, "\n"
    compare pos1, pos2
    {
      break-if-<=
      print-string 0, "out of order!\n"
      return 1
    }
    # letter = next non-space
    skip-chars-matching-whitespace line
    var letter/eax: byte <- read-byte line
    # skip some stuff
    {
      var colon/eax: byte <- read-byte line  # skip ':'
    }
    skip-chars-matching-whitespace line
    # now check the rest of the line
    var valid?/eax: boolean <- valid? pos1, pos2, letter, line
    compare valid?, 0/false
    {
      break-if-=
      print-string 0, "valid!\n"
      valid-password-count <- increment
    }
    loop
  }
  print-int32-decimal 0, valid-password-count
  print-string 0, "\n"
  return 0
}

# ideally password would be a random-access array
# we'll just track an index
# one benefit: we can easily start at 1
fn valid? pos1: int, pos2: int, letter: byte, password: (addr stream byte) -> _/eax: boolean {
  var i/esi: int <- copy 1
  var letter-count/edi: int <- copy 0
  # while password stream isn't empty
  #   c = read byte from password
  #   if (c == letter)
  #     if (i == pos1)
  #       ++letter-count
  #     if (i == pos2)
  #       ++letter-count
  #     ++i
  {
#?     print-string 0, "  "
#?     print-int32-decimal 0, i
#?     print-string 0, "\n"
    var done?/eax: boolean <- stream-empty? password
    compare done?, 0/false
    break-if-!=
    var c/eax: byte <- read-byte password
#?     {
#?       var c2/eax: int <- copy c
#?       print-int32-decimal 0, c2
#?       print-string 0, "\n"
#?     }
    compare c, letter
    {
      break-if-!=
      compare i, pos1
      {
        break-if-!=
        letter-count <- increment
#?         print-string 0, "  hit\n"
      }
      compare i, pos2
      {
        break-if-!=
        letter-count <- increment
#?         print-string 0, "  hit\n"
      }
    }
    i <- increment
    loop
  }
  # return (letter-count == 1)
  compare letter-count, 1
  {
    break-if-!=
    return 1/true
  }
  return 0/false
}
