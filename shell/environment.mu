# The top-level data structure for the Mu shell.
#
# vim:textwidth&
# It would be nice for tests to use a narrower screen than the standard 0x80 of
# 1024 pixels with 8px-wide graphemes. But it complicates rendering logic to
# make width configurable, so we just use longer lines than usual.

type environment {
  globals: global-table
  sandbox: sandbox
  # some state for a modal dialog for navigating between functions
  partial-function-name: (handle gap-buffer)
  function-not-found?: boolean
  #
  cursor-in-globals?: boolean
  cursor-in-function-modal?: boolean
}

# Here's a sample usage session and what it will look like on the screen.
fn test-environment {
  var env-storage: environment
  var env/esi: (addr environment) <- address env-storage
  initialize-environment env
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width=72, 0x10/height, 0/no-pixel-graphics
  # type some code into sandbox
  type-in env, screen, "(+ 3 4)"  # we don't have any global definitions here, so no macros
  # run code in sandbox
  edit-environment env, 0x13/ctrl-s, 0/no-disk
  render-environment screen, env
  #                                                         | global function definitions                                                        | sandbox
  # top row blank for now
  check-screen-row                     screen,         0/y, "                                                                                                                                ", "F - test-environment/0"
  check-screen-row                     screen,         1/y, "                                                                                      screen:                                   ", "F - test-environment/1"
  # starting at the same screen row, render the fake screen that exists within the sandbox within env
  check-background-color-in-screen-row screen, 0/bg,   1/y, "                                                                                                ........                        ", "F - test-environment/1-2"
  check-background-color-in-screen-row screen, 0/bg,   2/y, "                                                                                                ........                        ", "F - test-environment/2"
  check-background-color-in-screen-row screen, 0/bg,   3/y, "                                                                                                ........                        ", "F - test-environment/3"
  check-screen-row                     screen,         4/y, "                                                                                                                                ", "F - test-environment/4"
  check-screen-row                     screen,         5/y, "                                                                                      keyboard:                                 ", "F - test-environment/5"
  check-background-color-in-screen-row screen, 0/bg,   5/y, "                                                                                                ................                ", "F - test-environment/5-2"
  check-screen-row                     screen,         6/y, "                                                                                                                                ", "F - test-environment/6"
  check-screen-row                     screen,         7/y, "                                                                                      (+ 3 4)                                   ", "F - test-environment/7"
  check-screen-row                     screen,         8/y, "                                                                                      ...                       trace depth: 4  ", "F - test-environment/8"
  check-screen-row                     screen,         9/y, "                                                                                      => 7                                      ", "F - test-environment/9"
  check-screen-row                     screen,       0xa/y, "                                                                                                                                ", "F - test-environment/10"
  check-screen-row                     screen,       0xb/y, "                                                                                                                                ", "F - test-environment/11"
  check-screen-row                     screen,       0xc/y, "                                                                                                                                ", "F - test-environment/12"
  check-screen-row                     screen,       0xd/y, "                                                                                                                                ", "F - test-environment/13"
  check-screen-row                     screen,       0xe/y, "                                                                                                                                ", "F - test-environment/14"
  # bottom row is for a wordstar-style menu
  check-screen-row                     screen,       0xf/y, " ^r  run main   ^s  run sandbox   ^g  go to   ^m  to trace   ^a  <<   ^b  <word   ^f  word>   ^e  >>                            ", "F - test-environment/15"
}

fn test-definition-in-environment {
  var env-storage: environment
  var env/esi: (addr environment) <- address env-storage
  initialize-environment env
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width=72, 0x10/height, 0/no-pixel-graphics
  # define a function on the right (sandbox) side
  type-in env, screen, "(define fn1 (fn() 42))"  # we don't have any global definitions here, so no macros
  edit-environment env, 0x13/ctrl-s, 0/no-disk
  render-environment screen, env
  #                                                         | global function definitions                                                        | sandbox
  check-screen-row                     screen,         0/y, "                                                                                                                                ", "F - test-definition-in-environment/0"
  # function definition is now on the left side
  check-screen-row                     screen,         1/y, "                                           (define fn1 (fn() 42))                     screen:                                   ", "F - test-definition-in-environment/1"
  check-background-color-in-screen-row screen, 0/bg,   1/y, "                                                                                                ........                        ", "F - test-definition-in-environment/1-2"
  check-background-color-in-screen-row screen, 0/bg,   2/y, "                                                                                                ........                        ", "F - test-definition-in-environment/2"
  check-background-color-in-screen-row screen, 0/bg,   3/y, "                                                                                                ........                        ", "F - test-definition-in-environment/3"
  check-screen-row                     screen,         4/y, "                                                                                                                                ", "F - test-definition-in-environment/4"
  check-screen-row                     screen,         5/y, "                                                                                      keyboard:                                 ", "F - test-definition-in-environment/5"
  check-background-color-in-screen-row screen, 0/bg,   5/y, "                                                                                                ................                ", "F - test-definition-in-environment/5-2"
  check-screen-row                     screen,         6/y, "                                                                                                                                ", "F - test-definition-in-environment/6"
  check-screen-row                     screen,         7/y, "                                                                                                                                ", "F - test-definition-in-environment/7"
  # you can still see the trace on the right for what you just added to the left
  check-screen-row                     screen,         8/y, "                                                                                      ...                       trace depth: 4  ", "F - test-definition-in-environment/8"
}

# helper for testing
fn type-in self: (addr environment), screen: (addr screen), keys: (addr array byte) {
  # clear the buffer
  edit-environment self, 0x15/ctrl-u, 0/no-disk
  render-environment screen, self
  # type in all the keys
  var input-stream-storage: (stream byte 0x40/capacity)
  var input-stream/ecx: (addr stream byte) <- address input-stream-storage
  write input-stream, keys
  {
    var done?/eax: boolean <- stream-empty? input-stream
    compare done?, 0/false
    break-if-!=
    var key/eax: grapheme <- read-grapheme input-stream
    edit-environment self, key, 0/no-disk
    render-environment screen, self
    loop
  }
}

fn initialize-environment _self: (addr environment) {
  var self/esi: (addr environment) <- copy _self
  var globals/eax: (addr global-table) <- get self, globals
  initialize-globals globals
  var sandbox/eax: (addr sandbox) <- get self, sandbox
  initialize-sandbox sandbox, 1/with-screen
  var partial-function-name-ah/eax: (addr handle gap-buffer) <- get self, partial-function-name
  allocate partial-function-name-ah
  var partial-function-name/eax: (addr gap-buffer) <- lookup *partial-function-name-ah
  initialize-gap-buffer partial-function-name, 0x40/function-name-capacity
}

fn render-environment screen: (addr screen), _self: (addr environment) {
  # globals layout: 1 char padding, 41 code, 1 padding, 41 code, 1 padding =  85
  # sandbox layout: 1 padding, 41 code, 1 padding                          =  43
  #                                                                  total = 128 chars
  var self/esi: (addr environment) <- copy _self
  var cursor-in-globals-a/eax: (addr boolean) <- get self, cursor-in-globals?
  var cursor-in-globals?/eax: boolean <- copy *cursor-in-globals-a
  var globals/ecx: (addr global-table) <- get self, globals
  render-globals screen, globals, cursor-in-globals?
  var sandbox/edx: (addr sandbox) <- get self, sandbox
  var cursor-in-sandbox?/ebx: boolean <- copy 1/true
  cursor-in-sandbox? <- subtract cursor-in-globals?
  render-sandbox screen, sandbox, 0x55/sandbox-left-margin, 0/sandbox-top-margin, 0x80/screen-width, 0x2f/screen-height-without-menu, cursor-in-sandbox?
  # modal if necessary
  {
    var cursor-in-function-modal-a/eax: (addr boolean) <- get self, cursor-in-function-modal?
    compare *cursor-in-function-modal-a, 0/false
    break-if-=
    render-function-modal screen, self
    render-function-modal-menu screen, self
    return
  }
  # render menu
  {
    var cursor-in-globals?/eax: (addr boolean) <- get self, cursor-in-globals?
    compare *cursor-in-globals?, 0/false
    break-if-=
    render-globals-menu screen, globals
    return
  }
  render-sandbox-menu screen, sandbox
}

fn edit-environment _self: (addr environment), key: grapheme, data-disk: (addr disk) {
  var self/esi: (addr environment) <- copy _self
  var globals/edi: (addr global-table) <- get self, globals
  var sandbox/ecx: (addr sandbox) <- get self, sandbox
  # ctrl-r
  # Assumption: 'real-screen' and 'real-keyboard' are 0
  {
    compare key, 0x12/ctrl-r
    break-if-!=
    var tmp/eax: (addr handle cell) <- copy 0
    var nil: (handle cell)
    tmp <- address nil
    allocate-pair tmp
    # (main real-screen real-keyboard)
    var real-keyboard: (handle cell)
    tmp <- address real-keyboard
    allocate-keyboard tmp
    # args = cons(real-keyboard, nil)
    var args: (handle cell)
    tmp <- address args
    new-pair tmp, real-keyboard, nil
    #
    var real-screen: (handle cell)
    tmp <- address real-screen
    allocate-screen tmp
    #  args = cons(real-screen, args)
    tmp <- address args
    new-pair tmp, real-screen, *tmp
    #
    var main: (handle cell)
    tmp <- address main
    new-symbol tmp, "main"
    # args = cons(main, args)
    tmp <- address args
    new-pair tmp, main, *tmp
    # clear real screen
    clear-screen 0/screen
    set-cursor-position 0/screen, 0, 0
    # run
    var out: (handle cell)
    var out-ah/ecx: (addr handle cell) <- address out
    var trace-storage: trace
    var trace/ebx: (addr trace) <- address trace-storage
    initialize-trace trace, 1/only-errors, 0x10/capacity, 0/visible
    evaluate tmp, out-ah, nil, globals, trace, 0/no-fake-screen, 0/no-fake-keyboard, 0/call-number
    # wait for a keypress
    {
      var tmp/eax: byte <- read-key 0/keyboard
      compare tmp, 0
      loop-if-=
    }
    #
    return
  }
  # ctrl-s: send multiple places
  {
    compare key, 0x13/ctrl-s
    break-if-!=
    {
      # cursor in function modal? do nothing
      var cursor-in-function-modal-a/eax: (addr boolean) <- get self, cursor-in-function-modal?
      compare *cursor-in-function-modal-a, 0/false
      break-if-!=
      {
        # cursor in globals? update current definition
        var cursor-in-globals-a/edx: (addr boolean) <- get self, cursor-in-globals?
        compare *cursor-in-globals-a, 0/false
        break-if-=
        edit-globals globals, key
      }
      # update sandbox whether the cursor is in globals or sandbox
      edit-sandbox sandbox, key, globals, data-disk
    }
    return
  }
  # ctrl-g: go to a function (or the repl)
  {
    compare key, 7/ctrl-g
    break-if-!=
    var cursor-in-function-modal-a/eax: (addr boolean) <- get self, cursor-in-function-modal?
    compare *cursor-in-function-modal-a, 0/false
    break-if-!=
    # look for a word to prepopulate the modal
    var current-word-storage: (stream byte 0x40)
    var current-word/edi: (addr stream byte) <- address current-word-storage
    word-at-cursor self, current-word
    var partial-function-name-ah/eax: (addr handle gap-buffer) <- get self, partial-function-name
    var partial-function-name/eax: (addr gap-buffer) <- lookup *partial-function-name-ah
    clear-gap-buffer partial-function-name
    load-gap-buffer-from-stream partial-function-name, current-word
    # enable the modal
    var cursor-in-function-modal-a/eax: (addr boolean) <- get self, cursor-in-function-modal?
    copy-to *cursor-in-function-modal-a, 1/true
    return
  }
  # dispatch to function modal if necessary
  {
    var cursor-in-function-modal-a/eax: (addr boolean) <- get self, cursor-in-function-modal?
    compare *cursor-in-function-modal-a, 0/false
    break-if-=
    # nested events for modal dialog
    # ignore spaces
    {
      compare key, 0x20/space
      break-if-!=
      return
    }
    # esc = exit modal dialog
    {
      compare key, 0x1b/escape
      break-if-!=
      var cursor-in-function-modal-a/eax: (addr boolean) <- get self, cursor-in-function-modal?
      copy-to *cursor-in-function-modal-a, 0/false
      var function-not-found?/eax: (addr boolean) <- get self, function-not-found?
      copy-to *function-not-found? 0/false
      return
    }
    # enter = switch to function name and exit modal dialog
    {
      compare key, 0xa/newline
      break-if-!=
      # if no function name typed in, switch to sandbox
      var partial-function-name-ah/eax: (addr handle gap-buffer) <- get self, partial-function-name
      var partial-function-name/eax: (addr gap-buffer) <- lookup *partial-function-name-ah
      {
        var empty?/eax: boolean <- gap-buffer-empty? partial-function-name
        compare empty?, 0/false
        break-if-=
        var cursor-in-globals-a/eax: (addr boolean) <- get self, cursor-in-globals?
        copy-to *cursor-in-globals-a, 0/false
        # reset error state
        var function-not-found?/eax: (addr boolean) <- get self, function-not-found?
        copy-to *function-not-found? 0/false
        # done with function modal
        var cursor-in-function-modal-a/eax: (addr boolean) <- get self, cursor-in-function-modal?
        copy-to *cursor-in-function-modal-a, 0/false
        return
      }
      # turn function name into a stream
      var name-storage: (stream byte 0x40)
      var name/ecx: (addr stream byte) <- address name-storage
      emit-gap-buffer partial-function-name, name
      # compute function index
      var index/ecx: int <- find-symbol-in-globals globals, name
      # if function not found, set error and return
      {
        compare index, 0
        break-if->=
        var function-not-found?/eax: (addr boolean) <- get self, function-not-found?
        copy-to *function-not-found? 1/true
        return
      }
      # otherwise clear modal state
      clear-gap-buffer partial-function-name
      var function-not-found?/eax: (addr boolean) <- get self, function-not-found?
      copy-to *function-not-found? 0/false
      # switch focus to function at index
      var globals-cursor-index/eax: (addr int) <- get globals, cursor-index
      copy-to *globals-cursor-index, index
      var cursor-in-globals-a/ecx: (addr boolean) <- get self, cursor-in-globals?
      copy-to *cursor-in-globals-a, 1/true
      # done with function modal
      var cursor-in-function-modal-a/eax: (addr boolean) <- get self, cursor-in-function-modal?
      copy-to *cursor-in-function-modal-a, 0/false
      return
    }
    # otherwise process like a regular gap-buffer
    var partial-function-name-ah/eax: (addr handle gap-buffer) <- get self, partial-function-name
    var partial-function-name/eax: (addr gap-buffer) <- lookup *partial-function-name-ah
    edit-gap-buffer partial-function-name, key
    return
  }
  # dispatch the key to either sandbox or globals
  {
    var cursor-in-globals-a/eax: (addr boolean) <- get self, cursor-in-globals?
    compare *cursor-in-globals-a, 0/false
    break-if-=
    edit-globals globals, key
    return
  }
  edit-sandbox sandbox, key, globals, data-disk
}

fn test-function-modal {
  var env-storage: environment
  var env/esi: (addr environment) <- address env-storage
  initialize-environment env
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width=72, 0x10/height, 0/no-pixel-graphics
  # hit ctrl-g
  edit-environment env, 7/ctrl-g, 0/no-disk
  render-environment screen, env
  #
  check-background-color-in-screen-row screen, 0xf/bg=modal,   0/y, "                                                                                                                                ", "F - test-function-modal/0"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   1/y, "                                                                                                                                ", "F - test-function-modal/1"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   2/y, "                                                                                                                                ", "F - test-function-modal/2"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   3/y, "                                                                                                                                ", "F - test-function-modal/3"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   4/y, "                                                                                                                                ", "F - test-function-modal/4"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   5/y, "                                                                                                                                ", "F - test-function-modal/5"
  check-screen-row                     screen,                 6/y, "                                    go to function (or leave blank to go to REPL)                                               ", "F - test-function-modal/6-text"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   6/y, "                                ................................................................                                ", "F - test-function-modal/6"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   7/y, "                                ................................................................                                ", "F - test-function-modal/7"
  # cursor is in the modal
  check-background-color-in-screen-row screen,   0/bg=cursor,  8/y, "                                |                                                                                               ", "F - test-function-modal/8-cursor"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   8/y, "                                 ...............................................................                                ", "F - test-function-modal/8"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   9/y, "                                                                                                                                ", "F - test-function-modal/9"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xa/y, "                                                                                                                                ", "F - test-function-modal/10"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xb/y, "                                                                                                                                ", "F - test-function-modal/11"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xc/y, "                                                                                                                                ", "F - test-function-modal/12"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xd/y, "                                                                                                                                ", "F - test-function-modal/13"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xe/y, "                                                                                                                                ", "F - test-function-modal/14"
  # menu at bottom is correct in context
  check-screen-row                     screen,               0xf/y, " ^r  run main   enter  submit   esc  cancel   ^a  <<   ^b  <word   ^f  word>   ^e  >>                                           ", "F - test-function-modal/15-text"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xf/y, "                                                                                                                                ", "F - test-function-modal/15"
}

fn test-leave-function-modal {
  var env-storage: environment
  var env/esi: (addr environment) <- address env-storage
  initialize-environment env
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width=72, 0x10/height, 0/no-pixel-graphics
  # hit ctrl-g
  edit-environment env, 7/ctrl-g, 0/no-disk
  render-environment screen, env
  # cancel
  edit-environment env, 0x1b/escape, 0/no-disk
  render-environment screen, env
  # no modal
  check-background-color-in-screen-row screen, 0xf/bg=modal,   0/y, "                                                                                                                                ", "F - test-leave-function-modal/0"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   1/y, "                                                                                                                                ", "F - test-leave-function-modal/1"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   2/y, "                                                                                                                                ", "F - test-leave-function-modal/2"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   3/y, "                                                                                                                                ", "F - test-leave-function-modal/3"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   4/y, "                                                                                                                                ", "F - test-leave-function-modal/4"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   5/y, "                                                                                                                                ", "F - test-leave-function-modal/5"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   6/y, "                                                                                                                                ", "F - test-leave-function-modal/6"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   7/y, "                                                                                                                                ", "F - test-leave-function-modal/7"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   8/y, "                                                                                                                                ", "F - test-leave-function-modal/8"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   9/y, "                                                                                                                                ", "F - test-leave-function-modal/9"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xa/y, "                                                                                                                                ", "F - test-leave-function-modal/10"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xb/y, "                                                                                                                                ", "F - test-leave-function-modal/11"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xc/y, "                                                                                                                                ", "F - test-leave-function-modal/12"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xd/y, "                                                                                                                                ", "F - test-leave-function-modal/13"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xe/y, "                                                                                                                                ", "F - test-leave-function-modal/14"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xf/y, "                                                                                                                                ", "F - test-leave-function-modal/15"
}

fn test-jump-to-function {
  var env-storage: environment
  var env/esi: (addr environment) <- address env-storage
  initialize-environment env
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width=72, 0x10/height, 0/no-pixel-graphics
  # define a function
  type-in env, screen, "(define fn1 (fn() 42))"  # we don't have any global definitions here, so no macros
  edit-environment env, 0x13/ctrl-s, 0/no-disk
  render-environment screen, env
  # hit ctrl-g
  edit-environment env, 7/ctrl-g, 0/no-disk
  render-environment screen, env
  # type function name
  type-in env, screen, "fn1"
  # submit
  edit-environment env, 0xa/newline, 0/no-disk
  render-environment screen, env
  #                                                                 | global function definitions                                                        | sandbox
  # cursor now in function definition
  check-screen-row                     screen,                 1/y, "                                           (define fn1 (fn() 42))                     screen:                                   ", "F - test-jump-to-function/1"
  check-background-color-in-screen-row screen,   7/bg=cursor,  1/y, "                                                                 |                                                              ", "F - test-jump-to-function/1-cursor"
  # no modal
  check-background-color-in-screen-row screen, 0xf/bg=modal,   0/y, "                                                                                                                                ", "F - test-jump-to-function/bg0"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   1/y, "                                                                                                                                ", "F - test-jump-to-function/bg1"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   2/y, "                                                                                                                                ", "F - test-jump-to-function/bg2"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   3/y, "                                                                                                                                ", "F - test-jump-to-function/bg3"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   4/y, "                                                                                                                                ", "F - test-jump-to-function/bg4"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   5/y, "                                                                                                                                ", "F - test-jump-to-function/bg5"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   6/y, "                                                                                                                                ", "F - test-jump-to-function/bg6"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   7/y, "                                                                                                                                ", "F - test-jump-to-function/bg7"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   8/y, "                                                                                                                                ", "F - test-jump-to-function/bg8"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   9/y, "                                                                                                                                ", "F - test-jump-to-function/bg9"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xa/y, "                                                                                                                                ", "F - test-jump-to-function/bg10"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xb/y, "                                                                                                                                ", "F - test-jump-to-function/bg11"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xc/y, "                                                                                                                                ", "F - test-jump-to-function/bg12"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xd/y, "                                                                                                                                ", "F - test-jump-to-function/bg13"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xe/y, "                                                                                                                                ", "F - test-jump-to-function/bg14"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xf/y, "                                                                                                                                ", "F - test-jump-to-function/bg15"
}

fn test-function-modal-prepopulates-word-at-cursor {
  var env-storage: environment
  var env/esi: (addr environment) <- address env-storage
  initialize-environment env
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width=72, 0x10/height, 0/no-pixel-graphics
  # type a word at the cursor
  type-in env, screen, "fn1"
  # hit ctrl-g
  edit-environment env, 7/ctrl-g, 0/no-disk
  render-environment screen, env
  # modal prepopulates word at cursor
  check-background-color-in-screen-row screen, 0xf/bg=modal,   0/y, "                                                                                                                                ", "F - test-function-modal-prepopulates-word-at-cursor/0"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   1/y, "                                                                                                                                ", "F - test-function-modal-prepopulates-word-at-cursor/1"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   2/y, "                                                                                                                                ", "F - test-function-modal-prepopulates-word-at-cursor/2"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   3/y, "                                                                                                                                ", "F - test-function-modal-prepopulates-word-at-cursor/3"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   4/y, "                                                                                                                                ", "F - test-function-modal-prepopulates-word-at-cursor/4"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   5/y, "                                                                                                                                ", "F - test-function-modal-prepopulates-word-at-cursor/5"
  check-screen-row                     screen,                 6/y, "                                    go to function (or leave blank to go to REPL)                                               ", "F - test-function-modal-prepopulates-word-at-cursor/6-text"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   6/y, "                                ................................................................                                ", "F - test-function-modal-prepopulates-word-at-cursor/6"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   7/y, "                                ................................................................                                ", "F - test-function-modal-prepopulates-word-at-cursor/7"
  # word at cursor
  check-screen-row                     screen,                 8/y, "                                fn1                                                                                             ", "F - test-function-modal-prepopulates-word-at-cursor/8-text"
  # new cursor position
  check-background-color-in-screen-row screen,   0/bg=cursor,  8/y, "                                   |                                                                                            ", "F - test-function-modal-prepopulates-word-at-cursor/8-cursor"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   8/y, "                                ... ............................................................                                ", "F - test-function-modal-prepopulates-word-at-cursor/8"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   9/y, "                                                                                                                                ", "F - test-function-modal-prepopulates-word-at-cursor/9"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xa/y, "                                                                                                                                ", "F - test-function-modal-prepopulates-word-at-cursor/10"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xb/y, "                                                                                                                                ", "F - test-function-modal-prepopulates-word-at-cursor/11"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xc/y, "                                                                                                                                ", "F - test-function-modal-prepopulates-word-at-cursor/12"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xd/y, "                                                                                                                                ", "F - test-function-modal-prepopulates-word-at-cursor/13"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xe/y, "                                                                                                                                ", "F - test-function-modal-prepopulates-word-at-cursor/14"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xf/y, "                                                                                                                                ", "F - test-function-modal-prepopulates-word-at-cursor/15"
  # cancel
  edit-environment env, 0x1b/escape, 0/no-disk
  render-environment screen, env
  # type one more space
  edit-environment env, 0x20/space, 0/no-disk
  render-environment screen, env
  # hit ctrl-g again
  edit-environment env, 7/ctrl-g, 0/no-disk
  render-environment screen, env
  # no word prepopulated since cursor is not on the word
  check-background-color-in-screen-row screen, 0xf/bg=modal,   0/y, "                                                                                                                                ", "F - test-function-modal-prepopulates-word-at-cursor/test2-0"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   1/y, "                                                                                                                                ", "F - test-function-modal-prepopulates-word-at-cursor/test2-1"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   2/y, "                                                                                                                                ", "F - test-function-modal-prepopulates-word-at-cursor/test2-2"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   3/y, "                                                                                                                                ", "F - test-function-modal-prepopulates-word-at-cursor/test2-3"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   4/y, "                                                                                                                                ", "F - test-function-modal-prepopulates-word-at-cursor/test2-4"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   5/y, "                                                                                                                                ", "F - test-function-modal-prepopulates-word-at-cursor/test2-5"
  check-screen-row                     screen,                 6/y, "                                    go to function (or leave blank to go to REPL)                                               ", "F - test-function-modal-prepopulates-word-at-cursor/test2-6-text"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   6/y, "                                ................................................................                                ", "F - test-function-modal-prepopulates-word-at-cursor/test2-6"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   7/y, "                                ................................................................                                ", "F - test-function-modal-prepopulates-word-at-cursor/test2-7"
  # no word at cursor
  check-screen-row                     screen,                 8/y, "                                                                                                                                ", "F - test-function-modal-prepopulates-word-at-cursor/test2-8-text"
  # new cursor position
  check-background-color-in-screen-row screen,   0/bg=cursor,  8/y, "                                |                                                                                               ", "F - test-function-modal-prepopulates-word-at-cursor/test2-8-cursor"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   8/y, "                                 ...............................................................                                ", "F - test-function-modal-prepopulates-word-at-cursor/test2-8"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   9/y, "                                                                                                                                ", "F - test-function-modal-prepopulates-word-at-cursor/test2-9"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xa/y, "                                                                                                                                ", "F - test-function-modal-prepopulates-word-at-cursor/test2-10"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xb/y, "                                                                                                                                ", "F - test-function-modal-prepopulates-word-at-cursor/test2-11"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xc/y, "                                                                                                                                ", "F - test-function-modal-prepopulates-word-at-cursor/test2-12"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xd/y, "                                                                                                                                ", "F - test-function-modal-prepopulates-word-at-cursor/test2-13"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xe/y, "                                                                                                                                ", "F - test-function-modal-prepopulates-word-at-cursor/test2-14"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xf/y, "                                                                                                                                ", "F - test-function-modal-prepopulates-word-at-cursor/test2-15"
  # cancel
  edit-environment env, 0x1b/escape, 0/no-disk
  render-environment screen, env
  # move cursor to the left until it's on the word again
  edit-environment env, 0x80/left-arrow, 0/no-disk
  render-environment screen, env
  edit-environment env, 0x80/left-arrow, 0/no-disk
  render-environment screen, env
  # hit ctrl-g again
  edit-environment env, 7/ctrl-g, 0/no-disk
  render-environment screen, env
  # word prepopulated like before
  check-background-color-in-screen-row screen, 0xf/bg=modal,   0/y, "                                                                                                                                ", "F - test-function-modal-prepopulates-word-at-cursor/test3-0"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   1/y, "                                                                                                                                ", "F - test-function-modal-prepopulates-word-at-cursor/test3-1"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   2/y, "                                                                                                                                ", "F - test-function-modal-prepopulates-word-at-cursor/test3-2"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   3/y, "                                                                                                                                ", "F - test-function-modal-prepopulates-word-at-cursor/test3-3"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   4/y, "                                                                                                                                ", "F - test-function-modal-prepopulates-word-at-cursor/test3-4"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   5/y, "                                                                                                                                ", "F - test-function-modal-prepopulates-word-at-cursor/test3-5"
  check-screen-row                     screen,                 6/y, "                                    go to function (or leave blank to go to REPL)                                               ", "F - test-function-modal-prepopulates-word-at-cursor/test3-6-text"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   6/y, "                                ................................................................                                ", "F - test-function-modal-prepopulates-word-at-cursor/test3-6"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   7/y, "                                ................................................................                                ", "F - test-function-modal-prepopulates-word-at-cursor/test3-7"
  # word at cursor
  check-screen-row                     screen,                 8/y, "                                fn1                                                                                             ", "F - test-function-modal-prepopulates-word-at-cursor/test3-8-text"
  # new cursor position
  check-background-color-in-screen-row screen,   0/bg=cursor,  8/y, "                                   |                                                                                            ", "F - test-function-modal-prepopulates-word-at-cursor/test3-8-cursor"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   8/y, "                                ... ............................................................                                ", "F - test-function-modal-prepopulates-word-at-cursor/test3-8"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   9/y, "                                                                                                                                ", "F - test-function-modal-prepopulates-word-at-cursor/test3-9"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xa/y, "                                                                                                                                ", "F - test-function-modal-prepopulates-word-at-cursor/test3-10"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xb/y, "                                                                                                                                ", "F - test-function-modal-prepopulates-word-at-cursor/test3-11"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xc/y, "                                                                                                                                ", "F - test-function-modal-prepopulates-word-at-cursor/test3-12"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xd/y, "                                                                                                                                ", "F - test-function-modal-prepopulates-word-at-cursor/test3-13"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xe/y, "                                                                                                                                ", "F - test-function-modal-prepopulates-word-at-cursor/test3-14"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xf/y, "                                                                                                                                ", "F - test-function-modal-prepopulates-word-at-cursor/test3-15"
}

fn test-jump-to-nonexistent-function {
  var env-storage: environment
  var env/esi: (addr environment) <- address env-storage
  initialize-environment env
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width=72, 0x10/height, 0/no-pixel-graphics
  # type in any (nonexistent) function name
  type-in env, screen, "f"
  # hit ctrl-g
  edit-environment env, 7/ctrl-g, 0/no-disk
  render-environment screen, env
  # submit
  edit-environment env, 0xa/newline, 0/no-disk
  render-environment screen, env
  # modal now shows an error
  #                                                                 | global function definitions                                                        | sandbox
  check-background-color-in-screen-row screen, 0xf/bg=modal,   0/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-function/0"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   1/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-function/1"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   2/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-function/2"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   3/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-function/3"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   4/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-function/4"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   5/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-function/5"
  check-screen-row                     screen,                 6/y, "                                    go to function (or leave blank to go to REPL)                                               ", "F - test-jump-to-nonexistent-function/6-text"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   6/y, "                                ................................................................                                ", "F - test-jump-to-nonexistent-function/6"
  check-screen-row-in-color            screen, 4/fg=error,     7/y, "                                no such function                                                                                ", "F - test-jump-to-nonexistent-function/7-text"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   7/y, "                                ................................................................                                ", "F - test-jump-to-nonexistent-function/7"
  check-screen-row                     screen,                 8/y, "                                f                                                                                               ", "F - test-jump-to-nonexistent-function/8-text"
  check-background-color-in-screen-row screen,   0/bg=cursor,  8/y, "                                 |                                                                                              ", "F - test-jump-to-nonexistent-function/8-cursor"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   8/y, "                                . ..............................................................                                ", "F - test-jump-to-nonexistent-function/8"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   9/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-function/9"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xa/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-function/10"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xb/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-function/11"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xc/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-function/12"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xd/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-function/13"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xe/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-function/14"
  # menu at bottom is correct in context
  check-screen-row                     screen,               0xf/y, " ^r  run main   enter  submit   esc  cancel   ^a  <<   ^b  <word   ^f  word>   ^e  >>                                           ", "F - test-jump-to-nonexistent-function/15-text"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xf/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-function/15"
  # cancel
  edit-environment env, 0x1b/escape, 0/no-disk
  render-environment screen, env
  # hit ctrl-g again
  edit-environment env, 7/ctrl-g, 0/no-disk
  render-environment screen, env
  # word prepopulated like before, but no error
  check-background-color-in-screen-row screen, 0xf/bg=modal,   0/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-function/test2-0"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   1/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-function/test2-1"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   2/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-function/test2-2"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   3/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-function/test2-3"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   4/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-function/test2-4"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   5/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-function/test2-5"
  check-screen-row                     screen,                 6/y, "                                    go to function (or leave blank to go to REPL)                                               ", "F - test-jump-to-nonexistent-function/test2-6-text"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   6/y, "                                ................................................................                                ", "F - test-jump-to-nonexistent-function/test2-6"
  check-screen-row-in-color            screen, 4/fg=error,     7/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-function/test2-7-text"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   7/y, "                                ................................................................                                ", "F - test-jump-to-nonexistent-function/test2-7"
  # same word at cursor
  check-screen-row                     screen,                 8/y, "                                f                                                                                               ", "F - test-jump-to-nonexistent-function/test2-8-text"
  # new cursor position
  check-background-color-in-screen-row screen,   0/bg=cursor,  8/y, "                                 |                                                                                              ", "F - test-jump-to-nonexistent-function/test2-8-cursor"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   8/y, "                                . ..............................................................                                ", "F - test-jump-to-nonexistent-function/test2-8"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   9/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-function/test2-9"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xa/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-function/test2-10"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xb/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-function/test2-11"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xc/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-function/test2-12"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xd/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-function/test2-13"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xe/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-function/test2-14"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xf/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-function/test2-15"
}

fn render-function-modal screen: (addr screen), _self: (addr environment) {
  var self/esi: (addr environment) <- copy _self
  var width/eax: int <- copy 0
  var height/ecx: int <- copy 0
  width, height <- screen-size screen
  # xmin = max(0, width/2 - 0x20)
  var xmin: int
  var tmp/edx: int <- copy width
  tmp <- shift-right 1
  tmp <- subtract 0x20/half-function-name-capacity
  {
    compare tmp, 0
    break-if->=
    tmp <- copy 0
  }
  copy-to xmin, tmp
  # xmax = min(width, width/2 + 0x20)
  var xmax: int
  tmp <- copy width
  tmp <- shift-right 1
  tmp <- add 0x20/half-function-name-capacity
  {
    compare tmp, width
    break-if-<=
    tmp <- copy width
  }
  copy-to xmax, tmp
  # ymin = height/2 - 2
  var ymin: int
  tmp <- copy height
  tmp <- shift-right 1
  tmp <- subtract 2
  copy-to ymin, tmp
  # ymax = height/2 + 1
  var ymax: int
  tmp <- add 3
  copy-to ymax, tmp
  #
  clear-rect screen, xmin, ymin, xmax, ymax, 0xf/bg=modal
  add-to xmin, 4
  set-cursor-position screen, xmin, ymin
  draw-text-rightward-from-cursor screen, "go to function (or leave blank to go to REPL)", xmax, 8/fg=dark-grey, 0xf/bg=modal
  var partial-function-name-ah/eax: (addr handle gap-buffer) <- get self, partial-function-name
  var _partial-function-name/eax: (addr gap-buffer) <- lookup *partial-function-name-ah
  var partial-function-name/edx: (addr gap-buffer) <- copy _partial-function-name
  subtract-from xmin, 4
  increment ymin
  {
    var function-not-found?/eax: (addr boolean) <- get self, function-not-found?
    compare *function-not-found?, 0/false
    break-if-=
    var dummy/eax: int <- draw-text-rightward screen, "no such function", xmin, xmax, ymin, 4/fg=error, 0xf/bg=modal
  }
  increment ymin
  var dummy/eax: int <- copy 0
  var dummy2/ecx: int <- copy 0
  dummy, dummy2 <- render-gap-buffer-wrapping-right-then-down screen, partial-function-name, xmin, ymin, xmax, ymax, 1/always-render-cursor, 0/fg=black, 0xf/bg=modal
}

fn render-function-modal-menu screen: (addr screen), _self: (addr environment) {
  var self/esi: (addr environment) <- copy _self
  var _width/eax: int <- copy 0
  var height/ecx: int <- copy 0
  _width, height <- screen-size screen
  var width/edx: int <- copy _width
  var y/ecx: int <- copy height
  y <- decrement
  var height/ebx: int <- copy y
  height <- increment
  clear-rect screen, 0/x, y, width, height, 0xc5/bg=blue-bg
  set-cursor-position screen, 0/x, y
  draw-text-rightward-from-cursor screen, " ^r ", width, 0/fg, 0x5c/bg=menu-highlight
  draw-text-rightward-from-cursor screen, " run main  ", width, 7/fg, 0xc5/bg=blue-bg
  draw-text-rightward-from-cursor screen, " enter ", width, 0/fg, 0x5c/bg=menu-highlight
  draw-text-rightward-from-cursor screen, " submit  ", width, 7/fg, 0xc5/bg=blue-bg
  draw-text-rightward-from-cursor screen, " esc ", width, 0/fg, 0x5c/bg=menu-highlight
  draw-text-rightward-from-cursor screen, " cancel  ", width, 7/fg, 0xc5/bg=blue-bg
  draw-text-rightward-from-cursor screen, " ^a ", width, 0/fg, 0x5c/bg=menu-highlight
  draw-text-rightward-from-cursor screen, " <<  ", width, 7/fg, 0xc5/bg=blue-bg
  draw-text-rightward-from-cursor screen, " ^b ", width, 0/fg, 0x5c/bg=menu-highlight
  draw-text-rightward-from-cursor screen, " <word  ", width, 7/fg, 0xc5/bg=blue-bg
  draw-text-rightward-from-cursor screen, " ^f ", width, 0/fg, 0x5c/bg=menu-highlight
  draw-text-rightward-from-cursor screen, " word>  ", width, 7/fg, 0xc5/bg=blue-bg
  draw-text-rightward-from-cursor screen, " ^e ", width, 0/fg, 0x5c/bg=menu-highlight
  draw-text-rightward-from-cursor screen, " >>  ", width, 7/fg, 0xc5/bg=blue-bg
}

fn word-at-cursor _self: (addr environment), out: (addr stream byte) {
  var self/esi: (addr environment) <- copy _self
  var cursor-in-function-modal-a/eax: (addr boolean) <- get self, cursor-in-function-modal?
  compare *cursor-in-function-modal-a, 0/false
  {
    break-if-=
    # cursor in function modal
    return
  }
  var cursor-in-globals-a/edx: (addr boolean) <- get self, cursor-in-globals?
  compare *cursor-in-globals-a, 0/false
  {
    break-if-=
    # cursor in some function editor
    var globals/eax: (addr global-table) <- get self, globals
    var cursor-index-addr/ecx: (addr int) <- get globals, cursor-index
    var cursor-index/ecx: int <- copy *cursor-index-addr
    var globals-data-ah/eax: (addr handle array global) <- get globals, data
    var globals-data/eax: (addr array global) <- lookup *globals-data-ah
    var cursor-offset/ecx: (offset global) <- compute-offset globals-data, cursor-index
    var curr-global/eax: (addr global) <- index globals-data, cursor-offset
    var curr-global-data-ah/eax: (addr handle gap-buffer) <- get curr-global, input
    var curr-global-data/eax: (addr gap-buffer) <- lookup *curr-global-data-ah
    word-at-gap curr-global-data, out
    return
  }
  # cursor in sandbox
  var sandbox/ecx: (addr sandbox) <- get self, sandbox
  var sandbox-data-ah/eax: (addr handle gap-buffer) <- get sandbox, data
  var sandbox-data/eax: (addr gap-buffer) <- lookup *sandbox-data-ah
  word-at-gap sandbox-data, out
}

# Gotcha: some saved state may not load.
fn load-state _self: (addr environment), data-disk: (addr disk) {
  var self/esi: (addr environment) <- copy _self
  # data-disk -> stream
  var s-storage: (stream byte 0x2000)  # space for 16/sectors
  var s/ebx: (addr stream byte) <- address s-storage
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "loading sectors from data disk", 3/fg, 0/bg
  move-cursor-to-left-margin-of-next-line 0/screen
  load-sectors data-disk, 0/lba, 0x10/sectors, s
#?   draw-stream-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, s, 7/fg, 0xc5/bg=blue-bg
  # stream -> gap-buffer (HACK: we temporarily cannibalize the sandbox's gap-buffer)
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "parsing", 3/fg, 0/bg
  move-cursor-to-left-margin-of-next-line 0/screen
  var sandbox/eax: (addr sandbox) <- get self, sandbox
  var data-ah/eax: (addr handle gap-buffer) <- get sandbox, data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  load-gap-buffer-from-stream data, s
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "  into gap buffer", 3/fg, 0/bg
  move-cursor-to-left-margin-of-next-line 0/screen
  clear-stream s
  # read: gap-buffer -> cell
  var initial-root-storage: (handle cell)
  var initial-root/ecx: (addr handle cell) <- address initial-root-storage
  var trace-storage: trace
  var trace/edi: (addr trace) <- address trace-storage
  initialize-trace trace, 1/only-errors, 0x10/capacity, 0/visible
  read-cell data, initial-root, trace
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "  into s-expressions", 3/fg, 0/bg
  move-cursor-to-left-margin-of-next-line 0/screen
  clear-gap-buffer data
  #
  {
    var initial-root-addr/eax: (addr cell) <- lookup *initial-root
    compare initial-root-addr, 0
    break-if-!=
    return
  }
  # load globals from assoc(initial-root, 'globals)
  var globals-literal-storage: (handle cell)
  var globals-literal-ah/eax: (addr handle cell) <- address globals-literal-storage
  new-symbol globals-literal-ah, "globals"
  var globals-literal/eax: (addr cell) <- lookup *globals-literal-ah
  var globals-cell-storage: (handle cell)
  var globals-cell-ah/edx: (addr handle cell) <- address globals-cell-storage
  clear-trace trace
  lookup-symbol globals-literal, globals-cell-ah, *initial-root, 0/no-globals, trace, 0/no-screen, 0/no-keyboard
  var globals-cell/eax: (addr cell) <- lookup *globals-cell-ah
  {
    compare globals-cell, 0
    break-if-=
    var globals/eax: (addr global-table) <- get self, globals
    load-globals globals-cell-ah, globals
  }
  # sandbox = assoc(initial-root, 'sandbox)
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "loading sandbox", 3/fg, 0/bg
  var sandbox-literal-storage: (handle cell)
  var sandbox-literal-ah/eax: (addr handle cell) <- address sandbox-literal-storage
  new-symbol sandbox-literal-ah, "sandbox"
  var sandbox-literal/eax: (addr cell) <- lookup *sandbox-literal-ah
  var sandbox-cell-storage: (handle cell)
  var sandbox-cell-ah/edx: (addr handle cell) <- address sandbox-cell-storage
  clear-trace trace
  lookup-symbol sandbox-literal, sandbox-cell-ah, *initial-root, 0/no-globals, trace, 0/no-screen, 0/no-keyboard
  var sandbox-cell/eax: (addr cell) <- lookup *sandbox-cell-ah
  {
    compare sandbox-cell, 0
    break-if-=
    # print: cell -> stream
    clear-trace trace
    print-cell sandbox-cell-ah, s, trace
    # stream -> gap-buffer
    var sandbox/eax: (addr sandbox) <- get self, sandbox
    var data-ah/eax: (addr handle gap-buffer) <- get sandbox, data
    var data/eax: (addr gap-buffer) <- lookup *data-ah
    load-gap-buffer-from-stream data, s
  }
}

# Save state as an alist of alists:
#   ((globals . ((a . (fn ...))
#                ...))
#    (sandbox . ...))
fn store-state data-disk: (addr disk), sandbox: (addr sandbox), globals: (addr global-table) {
  compare data-disk, 0/no-disk
  {
    break-if-!=
    return
  }
  var stream-storage: (stream byte 0x2000)  # space enough for 16/sectors
  var stream/edi: (addr stream byte) <- address stream-storage
  write stream, "(\n"
  write-globals stream, globals
  write-sandbox stream, sandbox
  write stream, ")\n"
  store-sectors data-disk, 0/lba, 0x10/sectors, stream
}
