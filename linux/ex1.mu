# First example: return the answer to the Ultimate Question of Life, the
# Universe, and Everything.
#
# To run:
#   $ ./translate ex1.mu
#   $ ./a.elf
# Expected result:
#   $ echo $?
#   42

fn main -> _/ebx: int {
  return 0x2a  # Mu requires hexadecimal
}
