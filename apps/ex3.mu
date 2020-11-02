# Add the first 10 numbers, and return the result in the exit code.
#
# To run:
#   $ ./translate_mu apps/browse.mu
#   $ ./a.elf
# Expected result:
#   $ echo $?
#   55

fn main -> _/ebx: int {
  var result/ebx: int <- copy 0
  var i/eax: int <- copy 1
  {
    compare i, 0xa
    break-if->
    result <- add i
    i <- increment
    loop
  }
  return result
}
