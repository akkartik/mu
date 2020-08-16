# Meaningless conventional example.
#
# To run:
#   $ ./translate_mu apps/hello.mu
#   $ ./a.elf

fn main -> exit-status/ebx: int {
  print-string 0, "Hello world!\n"
  exit-status <- copy 0
}
