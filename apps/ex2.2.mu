# Increment a number, and return the result in the exit code.
#
# To run:
#   $ ./translate_mu apps/ex2.2.mu
#   $ ./a.elf
# Expected result:
#   $ echo $?
#   7

fn main -> result/ebx: int {
  result <- foo
}

fn foo -> result/ebx: int {
  var n: int
  copy-to n, 3
  increment n
  result <- copy n
}
