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
      var cid?/eax: boolean <- slice-equal? key-slice, "cid"
      compare cid?, 0  # false
      loop-if-!=
      # increment field count
      curr-passport-field-count <- increment
      # - validate fields one by one, setting curr-passport-field-count to impossibly high value to signal invalid
      # byr
      {
        var byr?/eax: boolean <- slice-equal? key-slice, "byr"
        compare byr?, 0  # false
        break-if-=
        var byr/eax: int <- parse-decimal-int-from-slice val-slice
        compare byr, 0x780  # 1920
        {
          break-if->=
          curr-passport-field-count <- copy 8
        }
        compare byr, 0x7d2  # 2002
        {
          break-if-<=
          curr-passport-field-count <- copy 8
        }
      }
      # iyr
      {
        var iyr?/eax: boolean <- slice-equal? key-slice, "iyr"
        compare iyr?, 0  # false
        break-if-=
        var iyr/eax: int <- parse-decimal-int-from-slice val-slice
        compare iyr, 0x7da  # 2010
        {
          break-if->=
          curr-passport-field-count <- copy 8
        }
        compare iyr, 0x7e4  # 2020
        {
          break-if-<=
          curr-passport-field-count <- copy 8
        }
      }
      # eyr
      {
        var eyr?/eax: boolean <- slice-equal? key-slice, "eyr"
        compare eyr?, 0  # false
        break-if-=
        compare iyr, 0x7e4  # 2020
        {
          break-if->=
          curr-passport-field-count <- copy 8
        }
        compare iyr, 0x7ee  # 2030
        {
          break-if-<=
          curr-passport-field-count <- copy 8
        }
      }
      # hgt
      {
        var hgt?/eax: boolean <- slice-equal? key-slice, "hgt"
        compare hgt?, 0  # false
        break-if-=
      }
      # hcl
      {
        var hcl?/eax: boolean <- slice-equal? key-slice, "hcl"
        compare hcl?, 0  # false
        break-if-=
      }
      # ecl
      {
        var ecl?/eax: boolean <- slice-equal? key-slice, "ecl"
        compare ecl?, 0  # false
        break-if-=
        var amb?/eax: boolean <- slice-equal? val-slice, "amb"
        compare amb?, 0  # false
        loop-if-!= $main:word-loop
        var blu?/eax: boolean <- slice-equal? val-slice, "blu"
        compare blu?, 0  # false
        loop-if-!= $main:word-loop
        var brn?/eax: boolean <- slice-equal? val-slice, "brn"
        compare brn?, 0  # false
        loop-if-!= $main:word-loop
        var gry?/eax: boolean <- slice-equal? val-slice, "gry"
        compare gry?, 0  # false
        loop-if-!= $main:word-loop
        var grn?/eax: boolean <- slice-equal? val-slice, "grn"
        compare grn?, 0  # false
        loop-if-!= $main:word-loop
        var hzl?/eax: boolean <- slice-equal? val-slice, "hzl"
        compare hzl?, 0  # false
        loop-if-!= $main:word-loop
        var oth?/eax: boolean <- slice-equal? val-slice, "oth"
        compare oth?, 0  # false
        loop-if-!= $main:word-loop
        curr-passport-field-count <- copy 8
      }
      # pid
      {
        var pid?/eax: boolean <- slice-equal? key-slice, "pid"
        compare pid?, 0  # false
        break-if-=
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
