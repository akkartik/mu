# https://adventofcode.com/2020/day/4
#
# To run (on Linux):
#   $ git clone https://github.com/akkartik/mu
#   $ cd mu
#   $ ./translate_mu apps/advent2020/4b.mu
#   $ ./a.elf < input
#
# You'll need to register to download the 'input' file for yourself.

fn main -> _/ebx: int {
  var curr-passport-field-count/esi: int <- copy 0
  var valid-passport-count/edi: int <- copy 0
  var line-storage: (stream byte 0x100)  # 256 bytes
  var line/ecx: (addr stream byte) <- address line-storage
  var key-slice-storage: slice
  var key-slice/edx: (addr slice) <- address key-slice-storage
  var val-slice-storage: slice
  var val-slice/ebx: (addr slice) <- address val-slice-storage
  $main:line-loop: {
    # read line from stdin
    clear-stream line
    read-line-from-real-keyboard line
    # if line is empty (not even a newline), quit
    var done?/eax: boolean <- stream-empty? line
    compare done?, 0  # false
    break-if-!=
    print-stream-to-real-screen line
    # if line has just a newline, process passport
    skip-chars-matching-whitespace line
    var new-passport?/eax: boolean <- stream-empty? line
    {
      compare new-passport?, 0  # false
      break-if-=
      compare curr-passport-field-count, 7
      {
        break-if-!=
        valid-passport-count <- increment
        print-string 0, "=> "
        print-int32-decimal 0, valid-passport-count
        print-string 0, "\n"
      }
      curr-passport-field-count <- copy 0
      loop $main:line-loop
    }
    $main:word-loop: {
      skip-chars-matching-whitespace line
      var done?/eax: boolean <- stream-empty? line
      compare done?, 0  # false
      break-if-!=
      next-token line, 0x3a, key-slice  # ':'
      var dummy/eax: byte <- read-byte line  # skip ':'
      next-raw-word line, val-slice
      print-slice-to-real-screen key-slice
      print-string 0, " : "
      print-slice-to-real-screen val-slice
      print-string 0, "\n"
      # treat cid as optional
      var optional?/eax: boolean <- slice-equal? key-slice, "cid"
      compare optional?, 0  # false
      {
        break-if-!=
        # otherwise assume there are no invalid fields and no duplicate fields
        curr-passport-field-count <- increment
        print-string 0, "-> "
        print-int32-decimal 0, curr-passport-field-count
        print-string 0, "\n"
      }
      loop
    }
    loop
  }
  # process final passport
  compare curr-passport-field-count, 7
  {
    break-if-!=
    valid-passport-count <- increment
  }
  print-int32-decimal 0, valid-passport-count
  print-string 0, "\n"
  return 0
}
