fn main args-on-stack: (addr array addr array byte) -> exit-status/ebx: int {
  var args/eax: (addr array addr array byte) <- copy args-on-stack
  var len/ecx: int <- length args
  $main-body: {
    compare len, 2
    {
      break-if-!=
      # if single arg is 'test', run tests
      var tmp/ecx: (addr addr array byte) <- index args, 1
      var tmp2/eax: boolean <- string-equal? *tmp, "test"
      compare tmp2, 0  # false
      {
        break-if-=
        run-tests
        exit-status <- copy 0  # TODO: get at Num-test-failures somehow
        break $main-body
      }
      # if single arg is 'screen', run in full-screen mode
      tmp2 <- string-equal? *tmp, "screen"
      compare tmp2, 0  # false
      {
        break-if-=
        interactive
        exit-status <- copy 0
        break $main-body
      }
      # if single arg is 'type', run in typewriter mode
      tmp2 <- string-equal? *tmp, "type"
      compare tmp2, 0  # false
      {
        break-if-=
        repl
        exit-status <- copy 0
        break $main-body
      }
    }
    # otherwise error message
    print-string-to-real-screen "usage:\n"
    print-string-to-real-screen "  to run tests: tile test\n"
    print-string-to-real-screen "  full-screen mode: tile screen\n"
    print-string-to-real-screen "  regular REPL: tile type\n"
    exit-status <- copy 1
  }
}

fn interactive {
  enable-screen-grid-mode
  enable-keyboard-immediate-mode
  var env-storage: environment
  var env/esi: (addr environment) <- address env-storage
  initialize-environment env
  draw-screen env
  {
    var key/eax: grapheme <- read-key-from-real-keyboard
    compare key, 0x71  # 'q'
    break-if-=
    process env, key
    render env
    loop
  }
  enable-keyboard-type-mode
  enable-screen-type-mode
}

fn repl {
  enable-keyboard-immediate-mode
  var env-storage: environment
  var env/esi: (addr environment) <- address env-storage
  initialize-environment env
  var stack-storage: value-stack
  var stack/edi: (addr value-stack) <- address stack-storage
  initialize-value-stack stack, 0x10
  print-string-to-real-screen "> "
  $repl:loop: {
    var key/eax: grapheme <- read-key-from-real-keyboard
    print-grapheme-to-real-screen key
    compare key, 4  # ctrl-d
    break-if-=
    compare key, 0xa  # newline
    {
      break-if-!=
      evaluate-environment env, stack
      var empty?/eax: boolean <- value-stack-empty? stack
      {
        compare empty?, 0  # false
        break-if-!=
        var result/eax: int <- pop-int-from-value-stack stack
        print-int32-decimal-to-real-screen result
        print-string-to-real-screen "\n"
      }
      # clear line
      var program-ah/eax: (addr handle program) <- get env, program
      var program/eax: (addr program) <- lookup *program-ah
      var sandbox-ah/eax: (addr handle sandbox) <- get program, sandboxes
      var _sandbox/eax: (addr sandbox) <- lookup *sandbox-ah
      var sandbox/esi: (addr sandbox) <- copy _sandbox
      var line-ah/eax: (addr handle line) <- get sandbox, data
      var line/eax: (addr line) <- lookup *line-ah
      var cursor-word-ah/esi: (addr handle word) <- get sandbox, cursor-word
      initialize-line line, cursor-word-ah
      print-string-to-real-screen "> "
      loop $repl:loop
    }
    process env, key
    loop
  }
  enable-keyboard-type-mode
}
