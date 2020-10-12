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
      # if single arg is 'test' ...
      tmp2 <- string-equal? *tmp, "test2"
      compare tmp2, 0  # false
      {
        break-if-=
        test
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
    compare key, 0x11  # 'ctrl-q'
    break-if-=
    process env, key
    render env
    loop
  }
  enable-keyboard-type-mode
  enable-screen-type-mode
}

fn test {
  var env-storage: environment
  var env/esi: (addr environment) <- address env-storage
  initialize-environment-with-fake-screen env, 0x30, 0xa0  # 48 rows, 160 columns
  var g/eax: grapheme <- copy 0x73  # 's'
  process env, g
  render env
}

fn repl {
  {
    # prompt
    var line-storage: (stream byte 0x100)
    var line/ecx: (addr stream byte) <- address line-storage
    print-string-to-real-screen "> "
    # read
    clear-stream line
    read-line-from-real-keyboard line
    var done?/eax: boolean <- stream-empty? line
    compare done?, 0  # false
    break-if-!=
    # parse
    var env-storage: environment
    var env/esi: (addr environment) <- address env-storage
    initialize-environment env
    {
      var done?/eax: boolean <- stream-empty? line
      compare done?, 0  # false
      break-if-!=
      var g/eax: grapheme <- read-grapheme line
      process env, g
      loop
    }
    # eval
    var stack-storage: value-stack
    var stack/edi: (addr value-stack) <- address stack-storage
    initialize-value-stack stack, 0x10
    evaluate-environment env, stack
    # print
    var empty?/eax: boolean <- value-stack-empty? stack
    {
      compare empty?, 0  # false
      break-if-!=
      var result/eax: int <- pop-int-from-value-stack stack
      print-int32-decimal-to-real-screen result
      print-string-to-real-screen "\n"
    }
    #
    loop
  }
}
