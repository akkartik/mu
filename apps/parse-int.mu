# parse a decimal int at the commandline
#
# To run:
#   $ ./translate_mu apps/parse-int.mu
#   $ ./a.elf 123
#   $ echo $?
#   123

fn main _args: (addr array addr array byte) -> exit-status/ebx: int {
$main-body: {
  # if no args, print a message and exit
  var args/esi: (addr array addr array byte) <- copy _args
  var n/ecx: int <- length args
  compare n, 1
  {
    break-if->
    print-string 0, "usage: parse-int <integer>\n"
    exit-status <- copy 1
    break $main-body
  }
  # otherwise parse the first arg as an integer
  var in/ecx: (addr addr array byte) <- index args, 1
  var out/eax: int <- parse-int *in
  exit-status <- copy out
}
}

fn parse-int _in: (addr array byte) -> result/eax: int {
  var in/esi: (addr array byte) <- copy _in
  var len/edx: int <- length in
  var i/ecx: int <- copy 0
  var out/edi: int <- copy 0
  {
    compare i, len
    break-if->=
    # out *= 10
    var ten/eax: int <- copy 0xa
    out <- multiply ten
    # c = in[i]
    var tmp/ebx: (addr byte) <- index in, i
    var c/eax: byte <- copy 0
    c <- copy-byte *tmp
    #
    var digit/eax: int <- to-decimal-digit c
    out <- add digit
    i <- increment
    loop
  }
  result <- copy out
}
