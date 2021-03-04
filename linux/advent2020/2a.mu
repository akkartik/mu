# https://adventofcode.com/2020/day/2
#
# To run (on Linux):
#   $ git clone https://github.com/akkartik/mu
#   $ cd mu
#   $ ./translate advent2020/2a.mu
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
    # start = parse-int(slice)
    var _start/eax: int <- parse-decimal-int-from-slice slice
    var start/ebx: int <- copy _start
    var dash/eax: byte <- read-byte line  # skip '-'
    # slice = next-token(line, ' ')
    next-token line, 0x20, slice
    var _end/eax: int <- parse-decimal-int-from-slice slice
    var end/esi: int <- copy _end
    print-int32-decimal 0, start
    print-string 0, " "
    print-int32-decimal 0, end
    print-string 0, "\n"
    # letter = next non-space
    skip-chars-matching-whitespace line
    var letter/eax: byte <- read-byte line
    # skip some stuff
    {
      var colon/eax: byte <- read-byte line  # skip ':'
    }
    skip-chars-matching-whitespace line
    # now check the rest of the line
    var is-valid?/eax: boolean <- is-valid? start, end, letter, line
    compare is-valid?, 0/false
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

fn is-valid? start: int, end: int, letter: byte, password: (addr stream byte) -> _/eax: boolean {
  var letter-count/edi: int <- copy 0
  # for every c in password
  #   if (c == letter)
  #     ++letter-count
  {
    var done?/eax: boolean <- stream-empty? password
    compare done?, 0/false
    break-if-!=
    var c/eax: byte <- read-byte password
    compare c, letter
    {
      break-if-!=
      letter-count <- increment
    }
    loop
  }
  # return (start <= letter-count <= end)
  compare letter-count, start
  {
    break-if->=
    return 0/false
  }
  compare letter-count, end
  {
    break-if-<=
    return 0/false
  }
  return 1/true
}
