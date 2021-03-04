# Unnecessarily use an array to sum 1..10
#
# To run:
#   $ ./translate ex3.2.mu
#   $ ./a.elf
#   $ echo $?
#   55

fn main -> _/ebx: int {
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
  var result/edx: int <- copy 0
  i <- copy 1
  {
    compare i, 0xb
    break-if->=
    var x/eax: (addr int) <- index a, i
    result <- add *x
    i <- increment
    loop
  }
  return result
}
