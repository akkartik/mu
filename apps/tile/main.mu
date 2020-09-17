fn main args-on-stack: (addr array addr array byte) -> exit-status/ebx: int {
  var args/eax: (addr array addr array byte) <- copy args-on-stack
  var len/ecx: int <- length args
  $main-body: {
    # if no args, run in interactive mode
    compare len, 1
    {
      break-if->
      exit-status <- interactive args-on-stack
      break $main-body
    }
    # else if single arg is 'test', run tests
    compare len, 2
    {
      break-if-!=
      var tmp/ecx: (addr addr array byte) <- index args, 1
      var tmp2/eax: boolean <- string-equal? *tmp, "test"
      compare tmp2, 0  # false
      {
        break-if-=
        run-tests
        exit-status <- copy 0  # TODO: get at Num-test-failures somehow
        break $main-body
      }
    }
    # otherwise error message
    print-string-to-real-screen "usage: tile\n"
    print-string-to-real-screen "    or tile test\n"
    exit-status <- copy 1
  }
}

fn interactive args: (addr array addr array byte) -> exit-status/ebx: int {
  enable-screen-grid-mode
  enable-keyboard-immediate-mode
  var env-storage: environment
  var env/esi: (addr environment) <- address env-storage
  initialize-environment env
  render-loop env
  enable-keyboard-type-mode
  enable-screen-type-mode
  exit-status <- copy 0
}

fn real-grapheme? g: grapheme -> result/eax: boolean {
  result <- copy 1  # true
}
