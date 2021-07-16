# First example: return the answer to the Ultimate Question of Life, the
# Universe, and Everything.
#
# Same as https://www.muppetlabs.com/~breadbox/software/tiny/teensy.html
#
# To run:
#   $ ./translate apps/ex1.mu
#   $ ./a.elf
# Expected result:
#   $ echo $?
#   42

fn main -> _/ebx: int {
  return 0x2a  # Mu requires hexadecimal
}
