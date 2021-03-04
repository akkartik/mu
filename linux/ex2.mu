# Add 3 and 4, and return the result in the exit code.
#
# To run:
#   $ ./translate ex2.mu
#   $ ./a.elf
# Expected result:
#   $ echo $?
#   7

fn main -> _/ebx: int {
  var result/eax: int <- do-add 3 4
  return result
}

fn do-add a: int, b: int -> _/eax: int {
  var result/ecx: int <- copy a
  result <- add b
  return result
}
