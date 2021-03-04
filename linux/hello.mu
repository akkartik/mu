# Meaningless conventional example.
#
# To run:
#   $ ./translate hello.mu
#   $ ./a.elf

fn main -> _/ebx: int {
  print-string 0/screen, "Hello world!\n"
  return 0
}
