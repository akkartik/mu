# Add 3 and 4, and return the result in the exit code.
#
# To run:
#   $ ./translate_mu apps/ex2.mu
#   $ ./a.elf
# Expected result:
#   $ echo $?
#   7

fn main -> result/ebx: int {
  result <- do-add 3 4
}

fn do-add a: int, b: int -> result/ebx: int {
  result <- copy a
  result <- add b
}
