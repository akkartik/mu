# usage:
#   ./translate_mu apps/factorial.mu
#   ./a.elf test  # to run tests
#   ./a.elf       # to run factorial(5)
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

fn main args: (addr array kernel-string) -> exit-status/ebx: int {
  var a/eax: (addr array kernel-string) <- copy args
  var tmp/ecx: int <- length a
  $main-body: {
    compare tmp, 1
    # if (len(args) == 1) factorial(5)
    {
      break-if-!=
      var tmp/eax: int <- factorial 5
      exit-status <- copy tmp
      break $main-body
    }
    # if (args[1] == "test") run-tests()
    var tmp2/ecx: (addr kernel-string) <- index a, 1
    var tmp3/eax: boolean <- kernel-string-equal? *tmp2, "test"
    compare tmp3, 0
    {
      break-if-=
      run-tests
      exit-status <- copy 0  # TODO: get at Num-test-failures somehow
    }
  }
}
