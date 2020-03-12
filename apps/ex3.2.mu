# Unnecessarily use an array to sum 1..9
#
# To run:
#   $ ./translate_mu apps/ex3.2.mu
#   $ ./a.elf
#   $ echo $?
#   55

fn main -> result/ebx: int {
  # populate a
  var a: (array int 0xb)  # 11; we waste index 0
  var i/ecx: int <- copy 1
  {
    compare i, 0xb
    break-if->=
    var x/eax: (addr int) <- index a, i
    copy-to *x, i
    i <- increment
    loop
  }
  # sum
  result <- copy 0
  i <- copy 1
  {
    compare i, 0xb
    break-if->=
    var x/eax: (addr int) <- index a, i
    result <- add *x
    i <- increment
    loop
  }
}
