# usage:
#   ./translate_mu apps/factorial.mu
#   ./a.elf test  # to run tests
#   ./a.elf       # to run factorial(5)
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
    var tmp2/ecx: int <- copy 1  # we need this just because we don't yet support `index` on literals; requires some translation-time computation
    var tmp3/ecx: (addr kernel-string) <- index a, tmp2
    var tmp4/eax: boolean <- kernel-string-equal? *tmp3, "test"
    compare tmp4, 0
    {
      break-if-=
      run-tests
      exit-status <- copy 0  # TODO: get at Num-test-failures somehow
    }
  }
}

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
