# compute the factorial of 5, and return the result in the exit code
#
# To run:
#   $ ./translate factorial.mu
#   $ ./a.elf
#   $ echo $?
#   120
#
# You can also run the automated test suite:
#   $ ./a.elf test
# Expected output:
#   ........
# Every '.' indicates a passing test. Failing tests get a 'F'.
# There's only one test in this file, but you'll also see tests running from
# Mu's standard library.
#
# Compare factorial4.subx

fn factorial n: int -> _/eax: int {
  compare n, 1
  # if (n <= 1) return 1
  {
    break-if->
    return 1
  }
  # n > 1; return n * factorial(n-1)
  var tmp/ecx: int <- copy n
  tmp <- decrement
  var result/eax: int <- factorial tmp
  result <- multiply n
  return result
}

fn test-factorial {
  var result/eax: int <- factorial 5
  check-ints-equal result, 0x78, "F - test-factorial"
}

fn main args-on-stack: (addr array addr array byte) -> _/ebx: int {
  var args/eax: (addr array addr array byte) <- copy args-on-stack
  # len = length(args)
  var len/ecx: int <- length args
  # if (len <= 1) return factorial(5)
  compare len, 1
  {
    break-if->
    var exit-status/eax: int <- factorial 5
    return exit-status
  }
  # if (args[1] == "test") run-tests()
  var tmp2/ecx: (addr addr array byte) <- index args, 1
  var tmp3/eax: boolean <- string-equal? *tmp2, "test"
  compare tmp3, 0
  {
    break-if-=
    run-tests
    # TODO: get at Num-test-failures somehow
  }
  return 0
}
