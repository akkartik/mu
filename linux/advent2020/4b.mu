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
    compare done?, 0/false
    break-if-!=
    print-stream-to-real-screen line
    # if line has just a newline, process passport
    skip-chars-matching-whitespace line
    var new-passport?/eax: boolean <- stream-empty? line
    {
      compare new-passport?, 0/false
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
      compare done?, 0/false
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
      compare cid?, 0/false
      loop-if-!=
      # increment field count
      curr-passport-field-count <- increment
      # - validate fields one by one, setting curr-passport-field-count to impossibly high value to signal invalid
      # byr
      {
        var byr?/eax: boolean <- slice-equal? key-slice, "byr"
        compare byr?, 0/false
        break-if-=
        # 1920 <= byr <= 2002
        var byr/eax: int <- parse-decimal-int-from-slice val-slice
        compare byr, 0x780  # 1920
        {
          break-if->=
          print-string 0, "invalid\n"
          curr-passport-field-count <- copy 8
        }
        compare byr, 0x7d2  # 2002
        {
          break-if-<=
          print-string 0, "invalid\n"
          curr-passport-field-count <- copy 8
        }
      }
      # iyr
      {
        var iyr?/eax: boolean <- slice-equal? key-slice, "iyr"
        compare iyr?, 0/false
        break-if-=
        # 2010 <= iyr <= 2020
        var iyr/eax: int <- parse-decimal-int-from-slice val-slice
        compare iyr, 0x7da  # 2010
        {
          break-if->=
          print-string 0, "invalid\n"
          curr-passport-field-count <- copy 8
        }
        compare iyr, 0x7e4  # 2020
        {
          break-if-<=
          print-string 0, "invalid\n"
          curr-passport-field-count <- copy 8
        }
      }
      # eyr
      {
        var eyr?/eax: boolean <- slice-equal? key-slice, "eyr"
        compare eyr?, 0/false
        break-if-=
        # 2020 <= eyr <= 2030
        var eyr/eax: int <- parse-decimal-int-from-slice val-slice
        compare eyr, 0x7e4  # 2020
        {
          break-if->=
          print-string 0, "invalid\n"
          curr-passport-field-count <- copy 8
        }
        compare eyr, 0x7ee  # 2030
        {
          break-if-<=
          print-string 0, "invalid\n"
          curr-passport-field-count <- copy 8
        }
      }
      # hgt
      {
        var hgt?/eax: boolean <- slice-equal? key-slice, "hgt"
        compare hgt?, 0/false
        break-if-=
        # convert val
        var s: (handle array byte)
        var s2/eax: (addr handle array byte) <- address s
        _slice-to-string val-slice, s2
        var s3/eax: (addr array byte) <- lookup *s2
        var s4/ebx: (addr array byte) <- copy s3
        # check suffix
        var start/edx: int <- length s4
        start <- subtract 2  # luckily both 'in' and 'cm' have the same length
        {
          var suffix-h: (handle array byte)
          var suffix-ah/ecx: (addr handle array byte) <- address suffix-h
          substring s4, start, 2, suffix-ah
          var suffix/eax: (addr array byte) <- lookup *suffix-ah
          {
            var match?/eax: boolean <- string-equal? suffix, "in"
            compare match?, 0/false
            break-if-=
            # if suffix is "in", 59 <= val <= 96
            var num-h: (handle array byte)
            var num-ah/ecx: (addr handle array byte) <- address num-h
            substring s4, 0, start, num-ah
            var num/eax: (addr array byte) <- lookup *num-ah
            var val/eax: int <- parse-decimal-int num
            compare val, 0x3b  # 59
            {
              break-if->=
          print-string 0, "invalid\n"
              curr-passport-field-count <- copy 8
            }
            compare val, 0x60  # 96
            {
              break-if-<=
          print-string 0, "invalid\n"
              curr-passport-field-count <- copy 8
            }
            loop $main:word-loop
          }
          {
            var match?/eax: boolean <- string-equal? suffix, "cm"
            compare match?, 0/false
            break-if-=
            # if suffix is "cm", 150 <= val <= 193
            var num-h: (handle array byte)
            var num-ah/ecx: (addr handle array byte) <- address num-h
            substring s4, 0, start, num-ah
            var num/eax: (addr array byte) <- lookup *num-ah
            var val/eax: int <- parse-decimal-int num
            compare val, 0x96  # 150
            {
              break-if->=
          print-string 0, "invalid\n"
              curr-passport-field-count <- copy 8
            }
            compare val, 0xc1  # 193
            {
              break-if-<=
          print-string 0, "invalid\n"
              curr-passport-field-count <- copy 8
            }
            loop $main:word-loop
          }
          print-string 0, "invalid\n"
          curr-passport-field-count <- copy 8
          loop $main:word-loop
        }
      }
      # hcl
      {
        var hcl?/eax: boolean <- slice-equal? key-slice, "hcl"
        compare hcl?, 0/false
        break-if-=
        # convert val
        var s: (handle array byte)
        var s2/eax: (addr handle array byte) <- address s
        _slice-to-string val-slice, s2
        var s3/eax: (addr array byte) <- lookup *s2
        # check length
        var len/ebx: int <- length s3
        compare len, 7
        {
          break-if-=
          print-string 0, "invalid\n"
          curr-passport-field-count <- copy 8
          loop $main:word-loop
        }
        # check first byte
        {
          var c/eax: (addr byte) <- index s3, 0
          var c2/eax: byte <- copy-byte *c
          compare c2, 0x23/hash
          break-if-=
          print-string 0, "invalid2\n"
          curr-passport-field-count <- copy 8
          loop $main:word-loop
        }
        # check remaining bytes
        var i/ebx: int <- copy 1  # skip 0
        {
          compare i, 7
          break-if->=
          var c/eax: (addr byte) <- index s3, i
          {
            var c2/eax: byte <- copy-byte *c
            var valid?/eax: boolean <- is-hex-digit? c2
            compare valid?, 0
            loop-if-= $main:word-loop
          }
          i <- increment
          loop
        }
      }
      # ecl
      {
        var ecl?/eax: boolean <- slice-equal? key-slice, "ecl"
        compare ecl?, 0/false
        break-if-=
        var amb?/eax: boolean <- slice-equal? val-slice, "amb"
        compare amb?, 0/false
        loop-if-!= $main:word-loop
        var blu?/eax: boolean <- slice-equal? val-slice, "blu"
        compare blu?, 0/false
        loop-if-!= $main:word-loop
        var brn?/eax: boolean <- slice-equal? val-slice, "brn"
        compare brn?, 0/false
        loop-if-!= $main:word-loop
        var gry?/eax: boolean <- slice-equal? val-slice, "gry"
        compare gry?, 0/false
        loop-if-!= $main:word-loop
        var grn?/eax: boolean <- slice-equal? val-slice, "grn"
        compare grn?, 0/false
        loop-if-!= $main:word-loop
        var hzl?/eax: boolean <- slice-equal? val-slice, "hzl"
        compare hzl?, 0/false
        loop-if-!= $main:word-loop
        var oth?/eax: boolean <- slice-equal? val-slice, "oth"
        compare oth?, 0/false
        loop-if-!= $main:word-loop
        print-string 0, "invalid\n"
        curr-passport-field-count <- copy 8
      }
      # pid
      {
        var pid?/eax: boolean <- slice-equal? key-slice, "pid"
        compare pid?, 0/false
        break-if-=
        # convert val
        var s: (handle array byte)
        var s2/eax: (addr handle array byte) <- address s
        _slice-to-string val-slice, s2
        var s3/eax: (addr array byte) <- lookup *s2
        # check length
        var len/eax: int <- length s3
        compare len, 9
        {
          break-if-=
          print-string 0, "invalid\n"
          curr-passport-field-count <- copy 8
          loop $main:word-loop
        }
        # check valid decimal int
        # parse-decimal-int-from-slice currently returns 0 on invalid parse,
        # which isn't ideal but suffices for our purposes
        var val/eax: int <- parse-decimal-int-from-slice val-slice
        compare val, 0
        {
          break-if->
          print-string 0, "invalid\n"
          curr-passport-field-count <- copy 8
        }
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
