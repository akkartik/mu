# parse a decimal int at the commandline
#
# To run:
#   $ ./translate apps/parse-int.mu
#   $ ./a.elf 123
#   $ echo $?
#   123

fn main _args: (addr array addr array byte) -> _/ebx: int {
  # if no args, print a message and exit
  var args/esi: (addr array addr array byte) <- copy _args
  var n/ecx: int <- length args
  compare n, 1
  {
    break-if->
    print-string 0/screen, "usage: parse-int <integer>\n"
    return 1
  }
  # otherwise parse the first arg as an integer
  var in/ecx: (addr addr array byte) <- index args, 1
  var out/eax: int <- parse-int *in
  return out
}

fn parse-int _in: (addr array byte) -> _/eax: int {
  var in/esi: (addr array byte) <- copy _in
  var len/edx: int <- length in
  var i/ecx: int <- copy 0
  var result/edi: int <- copy 0
  {
    compare i, len
    break-if->=
    # result *= 10
    var ten/eax: int <- copy 0xa
    result <- multiply ten
    # c = in[i]
    var tmp/ebx: (addr byte) <- index in, i
    var c/eax: byte <- copy-byte *tmp
    #
    var g/eax: grapheme <- copy c
    var digit/eax: int <- to-decimal-digit g
    result <- add digit
    i <- increment
    loop
  }
  return result
}
