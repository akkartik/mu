# compute the factorial of 5, and return the result in the exit code
#
# To run:
#   $ ./translate_mu apps/factorial.mu
#   $ ./a.elf
#   $ echo $?
#   120
#
# You can also run the automated test suite:
#   $ ./a.elf test
#
# Compare apps/factorial4.subx

fn factorial n: int -> result/eax: int {
  compare n 1
  {
    break-if->
    result <- copy 1
  }
  {
    break-if-<=
    var tmp/ecx: int <- copy n
    tmp <- decrement
    result <- factorial tmp
    result <- multiply n
  }
}

fn test-factorial {
  var result/eax: int <- factorial 5
  check-ints-equal result 0x78 "F - test-factorial"
}

fn main args-on-stack: (addr array (addr array byte)) -> exit-status/ebx: int {
  var args/eax: (addr array (addr array byte)) <- copy args-on-stack
  var tmp/ecx: int <- length args
  $main-body: {
    # if (len(args) <= 1) factorial(5)
    compare tmp, 1
    {
      break-if->
      var tmp/eax: int <- factorial 5
      exit-status <- copy tmp
      break $main-body
    }
    # if (args[1] == "test") run-tests()
    var tmp2/ecx: (addr addr array byte) <- index args, 1
    var tmp3/eax: boolean <- string-equal? *tmp2, "test"
    compare tmp3, 0
    {
      break-if-=
      run-tests
      exit-status <- copy 0  # TODO: get at Num-test-failures somehow
    }
  }
}
