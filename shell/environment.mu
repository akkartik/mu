# The top-level data structure for the Mu shell.
#
# vim:textwidth&
# It would be nice for tests to use a narrower screen than the standard 0x80 of
# 1024 pixels with 8px-wide graphemes. But it complicates rendering logic to
# make width configurable, so we just use longer lines than usual.

type environment {
  globals: global-table
  sandbox: sandbox
  # some state for a modal dialog for navigating between globals
  partial-global-name: (handle gap-buffer)
  go-modal-error: (handle array byte)
  #
  cursor-in-globals?: boolean
  cursor-in-go-modal?: boolean
}

# Here's a sample usage session and what it will look like on the screen.
fn test-environment {
  var env-storage: environment
  var env/esi: (addr environment) <- address env-storage
  initialize-environment env, 8/fake-screen-width, 3/fake-screen-height
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width, 0x30/height, 0/no-pixel-graphics
  # type some code into sandbox
  type-in env, screen, "(+ 3 4)"  # we don't have any global definitions here, so no macros
  # run code in sandbox
  edit-environment env, 0x13/ctrl-s, 0/no-disk
  render-environment screen, env
  #                                                         | global definitions                                                                 | sandbox
  # top row blank for now
  check-screen-row                     screen,         0/y, "                                                                                                                                ", "F - test-environment/0"
  check-screen-row                     screen,         1/y, "                                                                                      screen:                                   ", "F - test-environment/1"
  check-background-color-in-screen-row screen, 0/bg,   2/y, "                                                                                        ........                                ", "F - test-environment/2"
  check-background-color-in-screen-row screen, 0/bg,   3/y, "                                                                                        ........                                ", "F - test-environment/3"
  check-background-color-in-screen-row screen, 0/bg,   4/y, "                                                                                        ........                                ", "F - test-environment/4"
  check-screen-row                     screen,         5/y, "                                                                                                                                ", "F - test-environment/5"
  check-screen-row                     screen,         6/y, "                                                                                      keyboard:                                 ", "F - test-environment/6"
  check-background-color-in-screen-row screen, 0/bg,   6/y, "                                                                                                ................                ", "F - test-environment/6-2"
  check-screen-row                     screen,         7/y, "                                                                                                                                ", "F - test-environment/7"
  check-screen-row                     screen,         8/y, "                                                                                      (+ 3 4)                                   ", "F - test-environment/8"
  check-screen-row                     screen,         9/y, "                                                                                      ...                       trace depth: 4  ", "F - test-environment/9"
  check-screen-row                     screen,       0xa/y, "                                                                                      => 7                                      ", "F - test-environment/10"
  check-screen-row                     screen,       0xb/y, "                                                                                                                                ", "F - test-environment/11"
  check-screen-row                     screen,       0xc/y, "                                                                                                                                ", "F - test-environment/12"
  check-screen-row                     screen,       0xd/y, "                                                                                                                                ", "F - test-environment/13"
  check-screen-row                     screen,       0xe/y, "                                                                                                                                ", "F - test-environment/14"
  # bottom row is for a wordstar-style menu
  check-screen-row                     screen,      0x2f/y, " ^r  run main   ^s  run sandbox   ^g  go to   ^m  to trace   ^a  <<   ^b  <word   ^f  word>   ^e  >>                            ", "F - test-environment/15"
}

fn test-definition-in-environment {
  var env-storage: environment
  var env/esi: (addr environment) <- address env-storage
  initialize-environment env, 8/fake-screen-width, 3/fake-screen-height
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width, 0x30/height, 0/no-pixel-graphics
  # define a global on the right (sandbox) side
  type-in env, screen, "(define f 42)"
  edit-environment env, 0x13/ctrl-s, 0/no-disk
  render-environment screen, env
  #                                                         | global definitions                                                                 | sandbox
  check-screen-row                     screen,         0/y, "                                                                                                                                ", "F - test-definition-in-environment/0"
  # global definition is now on the left side
  check-screen-row                     screen,         1/y, "                                           (define f 42)                              screen:                                   ", "F - test-definition-in-environment/1"
  check-background-color-in-screen-row screen, 0/bg,   2/y, "                                                                                        ........                                ", "F - test-definition-in-environment/2"
  check-background-color-in-screen-row screen, 0/bg,   3/y, "                                                                                        ........                                ", "F - test-definition-in-environment/3"
  check-background-color-in-screen-row screen, 0/bg,   4/y, "                                                                                        ........                                ", "F - test-definition-in-environment/4"
  check-screen-row                     screen,         5/y, "                                                                                                                                ", "F - test-definition-in-environment/4"
  check-screen-row                     screen,         6/y, "                                                                                      keyboard:                                 ", "F - test-definition-in-environment/5"
  check-background-color-in-screen-row screen, 0/bg,   6/y, "                                                                                                ................                ", "F - test-definition-in-environment/5-2"
  check-screen-row                     screen,         7/y, "                                                                                                                                ", "F - test-definition-in-environment/6"
  check-screen-row                     screen,         8/y, "                                                                                                                                ", "F - test-definition-in-environment/7"
  # you can still see the trace on the right for what you just added to the left
  check-screen-row                     screen,         9/y, "                                                                                      ...                       trace depth: 4  ", "F - test-definition-in-environment/8"
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

fn initialize-environment _self: (addr environment), fake-screen-width: int, fake-screen-height: int {
  var self/esi: (addr environment) <- copy _self
  var globals/eax: (addr global-table) <- get self, globals
  initialize-globals globals
  var sandbox/eax: (addr sandbox) <- get self, sandbox
  initialize-sandbox sandbox, fake-screen-width, fake-screen-height
  var partial-global-name-ah/eax: (addr handle gap-buffer) <- get self, partial-global-name
  allocate partial-global-name-ah
  var partial-global-name/eax: (addr gap-buffer) <- lookup *partial-global-name-ah
  initialize-gap-buffer partial-global-name, 0x40/global-name-capacity
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
    var cursor-in-go-modal-a/eax: (addr boolean) <- get self, cursor-in-go-modal?
    compare *cursor-in-go-modal-a, 0/false
    break-if-=
    render-go-modal screen, self
    render-go-modal-menu screen, self
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
    evaluate tmp, out-ah, nil, globals, trace, 0/no-fake-screen, 0/no-fake-keyboard, 0/definitions-created, 0/call-number
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
      # cursor in go modal? do nothing
      var cursor-in-go-modal-a/eax: (addr boolean) <- get self, cursor-in-go-modal?
      compare *cursor-in-go-modal-a, 0/false
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
  # dispatch to go modal if necessary
  {
    var cursor-in-go-modal-a/eax: (addr boolean) <- get self, cursor-in-go-modal?
    compare *cursor-in-go-modal-a, 0/false
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
      var cursor-in-go-modal-a/eax: (addr boolean) <- get self, cursor-in-go-modal?
      copy-to *cursor-in-go-modal-a, 0/false
      var go-modal-error-ah/eax: (addr handle array byte) <- get self, go-modal-error
      clear-object go-modal-error-ah
      return
    }
    # enter = switch to global name and exit modal dialog
    {
      compare key, 0xa/newline
      break-if-!=
      # if no global name typed in, switch to sandbox
      var partial-global-name-ah/eax: (addr handle gap-buffer) <- get self, partial-global-name
      var partial-global-name/eax: (addr gap-buffer) <- lookup *partial-global-name-ah
      {
        var empty?/eax: boolean <- gap-buffer-empty? partial-global-name
        compare empty?, 0/false
        break-if-=
        var cursor-in-globals-a/eax: (addr boolean) <- get self, cursor-in-globals?
        copy-to *cursor-in-globals-a, 0/false
        # reset error state
        var go-modal-error-ah/eax: (addr handle array byte) <- get self, go-modal-error
        clear-object go-modal-error-ah
        # done with go modal
        var cursor-in-go-modal-a/eax: (addr boolean) <- get self, cursor-in-go-modal?
        copy-to *cursor-in-go-modal-a, 0/false
        return
      }
      # turn global name into a stream
      var name-storage: (stream byte 0x40)
      var name/ecx: (addr stream byte) <- address name-storage
      emit-gap-buffer partial-global-name, name
      # compute global index
      var curr-index/ecx: int <- find-symbol-in-globals globals, name
      # if global not found, set error and return
      {
        compare curr-index, 0
        break-if->=
        var go-modal-error-ah/eax: (addr handle array byte) <- get self, go-modal-error
        copy-array-object "no such global", go-modal-error-ah
        return
      }
      # if global is a primitive, set error and return
      {
        var global-data-ah/eax: (addr handle array global) <- get globals, data
        var global-data/eax: (addr array global) <- lookup *global-data-ah
        var curr-offset/ebx: (offset global) <- compute-offset global-data, curr-index
        var curr/ebx: (addr global) <- index global-data, curr-offset
        var primitive?/eax: boolean <- primitive-global? curr
        compare primitive?, 0/false
        break-if-=
        var go-modal-error-ah/eax: (addr handle array byte) <- get self, go-modal-error
        copy-array-object "sorry, primitives can't be edited yet", go-modal-error-ah
        return
      }
      # otherwise clear modal state
      clear-gap-buffer partial-global-name
      var go-modal-error-ah/eax: (addr handle array byte) <- get self, go-modal-error
      clear-object go-modal-error-ah
      var cursor-in-go-modal-a/eax: (addr boolean) <- get self, cursor-in-go-modal?
      copy-to *cursor-in-go-modal-a, 0/false
      # switch focus to global at index
#?       set-cursor-position 0/screen, 0x20/x 0x20/y
#?       draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, curr-index, 7/fg 0/bg
      bump-global globals, curr-index
#?       var curr-index2/ecx: int <- cursor-global globals
#?       draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, curr-index2, 4/fg 0/bg
#?       abort "a"
      var cursor-in-globals-a/ecx: (addr boolean) <- get self, cursor-in-globals?
      copy-to *cursor-in-globals-a, 1/true
      return
    }
    # ctrl-m = create given global name and exit modal dialog
    {
      compare key, 0xd/ctrl-m
      break-if-!=
      # if no global name typed in, set error and return
      var partial-global-name-ah/eax: (addr handle gap-buffer) <- get self, partial-global-name
      var partial-global-name/eax: (addr gap-buffer) <- lookup *partial-global-name-ah
      {
        var empty?/eax: boolean <- gap-buffer-empty? partial-global-name
        compare empty?, 0/false
        break-if-=
        var go-modal-error-ah/eax: (addr handle array byte) <- get self, go-modal-error
        copy-array-object "create what?", go-modal-error-ah
        return
      }
      # turn global name into a stream
      var name-storage: (stream byte 0x40)
      var name/edx: (addr stream byte) <- address name-storage
      emit-gap-buffer partial-global-name, name
      # compute global curr-index
      var curr-index/ecx: int <- find-symbol-in-globals globals, name
      # if global found, set error and return
      {
        compare curr-index, 0
        break-if-<
        var go-modal-error-ah/eax: (addr handle array byte) <- get self, go-modal-error
        copy-array-object "already exists", go-modal-error-ah
        return
      }
      # otherwise clear modal state
      clear-gap-buffer partial-global-name
      var go-modal-error-ah/eax: (addr handle array byte) <- get self, go-modal-error
      clear-object go-modal-error-ah
      var cursor-in-go-modal-a/eax: (addr boolean) <- get self, cursor-in-go-modal?
      copy-to *cursor-in-go-modal-a, 0/false
      # create new global
      create-empty-global globals, name, 0x2000/default-gap-buffer-size=8KB
      var globals-final-index/eax: (addr int) <- get globals, final-index
      var new-index/ecx: int <- copy *globals-final-index
      bump-global globals, new-index
      var cursor-in-globals-a/ecx: (addr boolean) <- get self, cursor-in-globals?
      copy-to *cursor-in-globals-a, 1/true
      return
    }
    # otherwise process like a regular gap-buffer
    var partial-global-name-ah/eax: (addr handle gap-buffer) <- get self, partial-global-name
    var partial-global-name/eax: (addr gap-buffer) <- lookup *partial-global-name-ah
    edit-gap-buffer partial-global-name, key
    return
  }
  # ctrl-g: go to a global (or the repl)
  {
    compare key, 7/ctrl-g
    break-if-!=
    # look for a word to prepopulate the modal
    var current-word-storage: (stream byte 0x40)
    var current-word/edi: (addr stream byte) <- address current-word-storage
    word-at-cursor self, current-word
    var partial-global-name-ah/eax: (addr handle gap-buffer) <- get self, partial-global-name
    var partial-global-name/eax: (addr gap-buffer) <- lookup *partial-global-name-ah
    clear-gap-buffer partial-global-name
    load-gap-buffer-from-stream partial-global-name, current-word
    # enable the modal
    var cursor-in-go-modal-a/eax: (addr boolean) <- get self, cursor-in-go-modal?
    copy-to *cursor-in-go-modal-a, 1/true
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

fn read-and-evaluate-and-save-gap-buffer-to-globals _in-ah: (addr handle gap-buffer), result-ah: (addr handle cell), globals: (addr global-table), definitions-created: (addr stream int), trace: (addr trace), inner-screen-var: (addr handle cell), inner-keyboard-var: (addr handle cell) {
  var in-ah/eax: (addr handle gap-buffer) <- copy _in-ah
  var in/eax: (addr gap-buffer) <- lookup *in-ah
  var read-result-h: (handle cell)
  var read-result-ah/esi: (addr handle cell) <- address read-result-h
  read-cell in, read-result-ah, trace
  var error?/eax: boolean <- has-errors? trace
  {
    compare error?, 0/false
    break-if-=
    return
  }
  macroexpand read-result-ah, globals, trace
  var error?/eax: boolean <- has-errors? trace
  {
    compare error?, 0/false
    break-if-=
    return
  }
  var nil-h: (handle cell)
  var nil-ah/eax: (addr handle cell) <- address nil-h
  allocate-pair nil-ah
#?   set-cursor-position 0/screen, 0 0
#?   turn-on-debug-print
  var call-number-storage: int
  var call-number/edi: (addr int) <- address call-number-storage
  debug-print "^", 4/fg, 0/bg
  evaluate read-result-ah, result-ah, *nil-ah, globals, trace, inner-screen-var, inner-keyboard-var, definitions-created, call-number
  debug-print "$", 4/fg, 0/bg
  var error?/eax: boolean <- has-errors? trace
  {
    compare error?, 0/false
    break-if-=
    return
  }
  # refresh various rendering caches
  mark-lines-dirty trace
  # If any definitions were created or modified in the process, link this gap
  # buffer to them.
  # TODO: detect and create UI for conflicts.
  stash-gap-buffer-to-globals globals, definitions-created, _in-ah
}

fn test-go-modal {
  var env-storage: environment
  var env/esi: (addr environment) <- address env-storage
  initialize-environment env, 8/fake-screen-width, 3/fake-screen-height
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width, 0x10/height, 0/no-pixel-graphics
  # hit ctrl-g
  edit-environment env, 7/ctrl-g, 0/no-disk
  render-environment screen, env
  #
  check-background-color-in-screen-row screen, 0xf/bg=modal,   0/y, "                                                                                                                                ", "F - test-go-modal/0"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   1/y, "                                                                                                                                ", "F - test-go-modal/1"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   2/y, "                                                                                                                                ", "F - test-go-modal/2"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   3/y, "                                                                                                                                ", "F - test-go-modal/3"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   4/y, "                                                                                                                                ", "F - test-go-modal/4"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   5/y, "                                                                                                                                ", "F - test-go-modal/5"
  check-screen-row                     screen,                 6/y, "                                    go to global (or leave blank to go to REPL)                                                 ", "F - test-go-modal/6-text"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   6/y, "                                ................................................................                                ", "F - test-go-modal/6"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   7/y, "                                ................................................................                                ", "F - test-go-modal/7"
  # cursor is in the modal
  check-background-color-in-screen-row screen,   0/bg=cursor,  8/y, "                                |                                                                                               ", "F - test-go-modal/8-cursor"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   8/y, "                                 ...............................................................                                ", "F - test-go-modal/8"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   9/y, "                                                                                                                                ", "F - test-go-modal/9"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xa/y, "                                                                                                                                ", "F - test-go-modal/10"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xb/y, "                                                                                                                                ", "F - test-go-modal/11"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xc/y, "                                                                                                                                ", "F - test-go-modal/12"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xd/y, "                                                                                                                                ", "F - test-go-modal/13"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xe/y, "                                                                                                                                ", "F - test-go-modal/14"
  # menu at bottom is correct in context
  check-screen-row                     screen,               0xf/y, " ^r  run main   enter  go   ^m  create   esc  cancel   ^a  <<   ^b  <word   ^f  word>   ^e  >>                                  ", "F - test-go-modal/15-text"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xf/y, "                                                                                                                                ", "F - test-go-modal/15"
}

fn test-leave-go-modal {
  var env-storage: environment
  var env/esi: (addr environment) <- address env-storage
  initialize-environment env, 8/fake-screen-width, 3/fake-screen-height
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width, 0x10/height, 0/no-pixel-graphics
  # hit ctrl-g
  edit-environment env, 7/ctrl-g, 0/no-disk
  render-environment screen, env
  # cancel
  edit-environment env, 0x1b/escape, 0/no-disk
  render-environment screen, env
  # no modal
  check-background-color-in-screen-row screen, 0xf/bg=modal,   0/y, "                                                                                                                                ", "F - test-leave-go-modal/0"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   1/y, "                                                                                                                                ", "F - test-leave-go-modal/1"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   2/y, "                                                                                                                                ", "F - test-leave-go-modal/2"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   3/y, "                                                                                                                                ", "F - test-leave-go-modal/3"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   4/y, "                                                                                                                                ", "F - test-leave-go-modal/4"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   5/y, "                                                                                                                                ", "F - test-leave-go-modal/5"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   6/y, "                                                                                                                                ", "F - test-leave-go-modal/6"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   7/y, "                                                                                                                                ", "F - test-leave-go-modal/7"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   8/y, "                                                                                                                                ", "F - test-leave-go-modal/8"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   9/y, "                                                                                                                                ", "F - test-leave-go-modal/9"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xa/y, "                                                                                                                                ", "F - test-leave-go-modal/10"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xb/y, "                                                                                                                                ", "F - test-leave-go-modal/11"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xc/y, "                                                                                                                                ", "F - test-leave-go-modal/12"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xd/y, "                                                                                                                                ", "F - test-leave-go-modal/13"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xe/y, "                                                                                                                                ", "F - test-leave-go-modal/14"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xf/y, "                                                                                                                                ", "F - test-leave-go-modal/15"
}

fn test-jump-to-global {
  var env-storage: environment
  var env/esi: (addr environment) <- address env-storage
  initialize-environment env, 8/fake-screen-width, 3/fake-screen-height
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width, 0x30/height, 0/no-pixel-graphics
  # define a global
  type-in env, screen, "(define f 42)"
  edit-environment env, 0x13/ctrl-s, 0/no-disk
  render-environment screen, env
  # hit ctrl-g
  edit-environment env, 7/ctrl-g, 0/no-disk
  render-environment screen, env
  # type global name
  type-in env, screen, "f"
  # submit
  edit-environment env, 0xa/newline, 0/no-disk
  render-environment screen, env
  #                                                                 | global definitions                                                                 | sandbox
  # cursor now in global definition
  check-screen-row                     screen,                 1/y, "                                           (define f 42)                              screen:                                   ", "F - test-jump-to-global/1"
  check-background-color-in-screen-row screen,   7/bg=cursor,  1/y, "                                                        |                                                                       ", "F - test-jump-to-global/1-cursor"
  # no modal
  check-background-color-in-screen-row screen, 0xf/bg=modal,   0/y, "                                                                                                                                ", "F - test-jump-to-global/bg0"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   1/y, "                                                                                                                                ", "F - test-jump-to-global/bg1"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   2/y, "                                                                                                                                ", "F - test-jump-to-global/bg2"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   3/y, "                                                                                                                                ", "F - test-jump-to-global/bg3"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   4/y, "                                                                                                                                ", "F - test-jump-to-global/bg4"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   5/y, "                                                                                                                                ", "F - test-jump-to-global/bg5"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   6/y, "                                                                                                                                ", "F - test-jump-to-global/bg6"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   7/y, "                                                                                                                                ", "F - test-jump-to-global/bg7"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   8/y, "                                                                                                                                ", "F - test-jump-to-global/bg8"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   9/y, "                                                                                                                                ", "F - test-jump-to-global/bg9"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xa/y, "                                                                                                                                ", "F - test-jump-to-global/bg10"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xb/y, "                                                                                                                                ", "F - test-jump-to-global/bg11"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xc/y, "                                                                                                                                ", "F - test-jump-to-global/bg12"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xd/y, "                                                                                                                                ", "F - test-jump-to-global/bg13"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xe/y, "                                                                                                                                ", "F - test-jump-to-global/bg14"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xf/y, "                                                                                                                                ", "F - test-jump-to-global/bg15"
}

fn test-go-modal-prepopulates-word-at-cursor {
  var env-storage: environment
  var env/esi: (addr environment) <- address env-storage
  initialize-environment env, 8/fake-screen-width, 3/fake-screen-height
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width, 0x10/height, 0/no-pixel-graphics
  # type a word at the cursor
  type-in env, screen, "fn1"
  # hit ctrl-g
  edit-environment env, 7/ctrl-g, 0/no-disk
  render-environment screen, env
  # modal prepopulates word at cursor
  check-background-color-in-screen-row screen, 0xf/bg=modal,   0/y, "                                                                                                                                ", "F - test-go-modal-prepopulates-word-at-cursor/0"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   1/y, "                                                                                                                                ", "F - test-go-modal-prepopulates-word-at-cursor/1"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   2/y, "                                                                                                                                ", "F - test-go-modal-prepopulates-word-at-cursor/2"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   3/y, "                                                                                                                                ", "F - test-go-modal-prepopulates-word-at-cursor/3"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   4/y, "                                                                                                                                ", "F - test-go-modal-prepopulates-word-at-cursor/4"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   5/y, "                                                                                                                                ", "F - test-go-modal-prepopulates-word-at-cursor/5"
  check-screen-row                     screen,                 6/y, "                                    go to global (or leave blank to go to REPL)                                                 ", "F - test-go-modal-prepopulates-word-at-cursor/6-text"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   6/y, "                                ................................................................                                ", "F - test-go-modal-prepopulates-word-at-cursor/6"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   7/y, "                                ................................................................                                ", "F - test-go-modal-prepopulates-word-at-cursor/7"
  # word at cursor
  check-screen-row                     screen,                 8/y, "                                fn1                                                                                             ", "F - test-go-modal-prepopulates-word-at-cursor/8-text"
  # new cursor position
  check-background-color-in-screen-row screen,   0/bg=cursor,  8/y, "                                   |                                                                                            ", "F - test-go-modal-prepopulates-word-at-cursor/8-cursor"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   8/y, "                                ... ............................................................                                ", "F - test-go-modal-prepopulates-word-at-cursor/8"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   9/y, "                                                                                                                                ", "F - test-go-modal-prepopulates-word-at-cursor/9"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xa/y, "                                                                                                                                ", "F - test-go-modal-prepopulates-word-at-cursor/10"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xb/y, "                                                                                                                                ", "F - test-go-modal-prepopulates-word-at-cursor/11"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xc/y, "                                                                                                                                ", "F - test-go-modal-prepopulates-word-at-cursor/12"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xd/y, "                                                                                                                                ", "F - test-go-modal-prepopulates-word-at-cursor/13"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xe/y, "                                                                                                                                ", "F - test-go-modal-prepopulates-word-at-cursor/14"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xf/y, "                                                                                                                                ", "F - test-go-modal-prepopulates-word-at-cursor/15"
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
  check-background-color-in-screen-row screen, 0xf/bg=modal,   0/y, "                                                                                                                                ", "F - test-go-modal-prepopulates-word-at-cursor/test2-0"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   1/y, "                                                                                                                                ", "F - test-go-modal-prepopulates-word-at-cursor/test2-1"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   2/y, "                                                                                                                                ", "F - test-go-modal-prepopulates-word-at-cursor/test2-2"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   3/y, "                                                                                                                                ", "F - test-go-modal-prepopulates-word-at-cursor/test2-3"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   4/y, "                                                                                                                                ", "F - test-go-modal-prepopulates-word-at-cursor/test2-4"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   5/y, "                                                                                                                                ", "F - test-go-modal-prepopulates-word-at-cursor/test2-5"
  check-screen-row                     screen,                 6/y, "                                    go to global (or leave blank to go to REPL)                                                 ", "F - test-go-modal-prepopulates-word-at-cursor/test2-6-text"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   6/y, "                                ................................................................                                ", "F - test-go-modal-prepopulates-word-at-cursor/test2-6"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   7/y, "                                ................................................................                                ", "F - test-go-modal-prepopulates-word-at-cursor/test2-7"
  # no word at cursor
  check-screen-row                     screen,                 8/y, "                                                                                                                                ", "F - test-go-modal-prepopulates-word-at-cursor/test2-8-text"
  # new cursor position
  check-background-color-in-screen-row screen,   0/bg=cursor,  8/y, "                                |                                                                                               ", "F - test-go-modal-prepopulates-word-at-cursor/test2-8-cursor"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   8/y, "                                 ...............................................................                                ", "F - test-go-modal-prepopulates-word-at-cursor/test2-8"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   9/y, "                                                                                                                                ", "F - test-go-modal-prepopulates-word-at-cursor/test2-9"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xa/y, "                                                                                                                                ", "F - test-go-modal-prepopulates-word-at-cursor/test2-10"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xb/y, "                                                                                                                                ", "F - test-go-modal-prepopulates-word-at-cursor/test2-11"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xc/y, "                                                                                                                                ", "F - test-go-modal-prepopulates-word-at-cursor/test2-12"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xd/y, "                                                                                                                                ", "F - test-go-modal-prepopulates-word-at-cursor/test2-13"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xe/y, "                                                                                                                                ", "F - test-go-modal-prepopulates-word-at-cursor/test2-14"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xf/y, "                                                                                                                                ", "F - test-go-modal-prepopulates-word-at-cursor/test2-15"
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
  check-background-color-in-screen-row screen, 0xf/bg=modal,   0/y, "                                                                                                                                ", "F - test-go-modal-prepopulates-word-at-cursor/test3-0"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   1/y, "                                                                                                                                ", "F - test-go-modal-prepopulates-word-at-cursor/test3-1"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   2/y, "                                                                                                                                ", "F - test-go-modal-prepopulates-word-at-cursor/test3-2"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   3/y, "                                                                                                                                ", "F - test-go-modal-prepopulates-word-at-cursor/test3-3"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   4/y, "                                                                                                                                ", "F - test-go-modal-prepopulates-word-at-cursor/test3-4"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   5/y, "                                                                                                                                ", "F - test-go-modal-prepopulates-word-at-cursor/test3-5"
  check-screen-row                     screen,                 6/y, "                                    go to global (or leave blank to go to REPL)                                                 ", "F - test-go-modal-prepopulates-word-at-cursor/test3-6-text"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   6/y, "                                ................................................................                                ", "F - test-go-modal-prepopulates-word-at-cursor/test3-6"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   7/y, "                                ................................................................                                ", "F - test-go-modal-prepopulates-word-at-cursor/test3-7"
  # word at cursor
  check-screen-row                     screen,                 8/y, "                                fn1                                                                                             ", "F - test-go-modal-prepopulates-word-at-cursor/test3-8-text"
  # new cursor position
  check-background-color-in-screen-row screen,   0/bg=cursor,  8/y, "                                   |                                                                                            ", "F - test-go-modal-prepopulates-word-at-cursor/test3-8-cursor"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   8/y, "                                ... ............................................................                                ", "F - test-go-modal-prepopulates-word-at-cursor/test3-8"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   9/y, "                                                                                                                                ", "F - test-go-modal-prepopulates-word-at-cursor/test3-9"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xa/y, "                                                                                                                                ", "F - test-go-modal-prepopulates-word-at-cursor/test3-10"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xb/y, "                                                                                                                                ", "F - test-go-modal-prepopulates-word-at-cursor/test3-11"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xc/y, "                                                                                                                                ", "F - test-go-modal-prepopulates-word-at-cursor/test3-12"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xd/y, "                                                                                                                                ", "F - test-go-modal-prepopulates-word-at-cursor/test3-13"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xe/y, "                                                                                                                                ", "F - test-go-modal-prepopulates-word-at-cursor/test3-14"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xf/y, "                                                                                                                                ", "F - test-go-modal-prepopulates-word-at-cursor/test3-15"
}

fn test-jump-to-nonexistent-global {
  var env-storage: environment
  var env/esi: (addr environment) <- address env-storage
  initialize-environment env, 8/fake-screen-width, 3/fake-screen-height
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width, 0x10/height, 0/no-pixel-graphics
  # type in any (nonexistent) global name
  type-in env, screen, "f"
  # hit ctrl-g
  edit-environment env, 7/ctrl-g, 0/no-disk
  render-environment screen, env
  # submit
  edit-environment env, 0xa/newline, 0/no-disk
  render-environment screen, env
  # modal now shows an error
  #                                                                 | global definitions                                                                 | sandbox
  check-background-color-in-screen-row screen, 0xf/bg=modal,   0/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-global/0"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   1/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-global/1"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   2/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-global/2"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   3/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-global/3"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   4/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-global/4"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   5/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-global/5"
  check-screen-row                     screen,                 6/y, "                                    go to global (or leave blank to go to REPL)                                                 ", "F - test-jump-to-nonexistent-global/6-text"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   6/y, "                                ................................................................                                ", "F - test-jump-to-nonexistent-global/6"
  check-screen-row-in-color            screen, 4/fg=error,     7/y, "                                no such global                                                                                  ", "F - test-jump-to-nonexistent-global/7-text"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   7/y, "                                ................................................................                                ", "F - test-jump-to-nonexistent-global/7"
  check-screen-row                     screen,                 8/y, "                                f                                                                                               ", "F - test-jump-to-nonexistent-global/8-text"
  check-background-color-in-screen-row screen,   0/bg=cursor,  8/y, "                                 |                                                                                              ", "F - test-jump-to-nonexistent-global/8-cursor"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   8/y, "                                . ..............................................................                                ", "F - test-jump-to-nonexistent-global/8"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   9/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-global/9"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xa/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-global/10"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xb/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-global/11"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xc/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-global/12"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xd/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-global/13"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xe/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-global/14"
  # menu at bottom is correct in context
  check-screen-row                     screen,               0xf/y, " ^r  run main   enter  go   ^m  create   esc  cancel   ^a  <<   ^b  <word   ^f  word>   ^e  >>                                  ", "F - test-jump-to-nonexistent-global/15-text"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xf/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-global/15"
  # cancel
  edit-environment env, 0x1b/escape, 0/no-disk
  render-environment screen, env
  # hit ctrl-g again
  edit-environment env, 7/ctrl-g, 0/no-disk
  render-environment screen, env
  # word prepopulated like before, but no error
  check-background-color-in-screen-row screen, 0xf/bg=modal,   0/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-global/test2-0"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   1/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-global/test2-1"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   2/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-global/test2-2"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   3/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-global/test2-3"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   4/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-global/test2-4"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   5/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-global/test2-5"
  check-screen-row                     screen,                 6/y, "                                    go to global (or leave blank to go to REPL)                                                 ", "F - test-jump-to-nonexistent-global/test2-6-text"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   6/y, "                                ................................................................                                ", "F - test-jump-to-nonexistent-global/test2-6"
  check-screen-row-in-color            screen, 4/fg=error,     7/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-global/test2-7-text"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   7/y, "                                ................................................................                                ", "F - test-jump-to-nonexistent-global/test2-7"
  # same word at cursor
  check-screen-row                     screen,                 8/y, "                                f                                                                                               ", "F - test-jump-to-nonexistent-global/test2-8-text"
  # new cursor position
  check-background-color-in-screen-row screen,   0/bg=cursor,  8/y, "                                 |                                                                                              ", "F - test-jump-to-nonexistent-global/test2-8-cursor"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   8/y, "                                . ..............................................................                                ", "F - test-jump-to-nonexistent-global/test2-8"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   9/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-global/test2-9"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xa/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-global/test2-10"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xb/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-global/test2-11"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xc/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-global/test2-12"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xd/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-global/test2-13"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xe/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-global/test2-14"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xf/y, "                                                                                                                                ", "F - test-jump-to-nonexistent-global/test2-15"
}

fn test-create-global {
  var env-storage: environment
  var env/esi: (addr environment) <- address env-storage
  initialize-environment env, 8/fake-screen-width, 3/fake-screen-height
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width, 0x30/height, 0/no-pixel-graphics
  # hit ctrl-g
  edit-environment env, 7/ctrl-g, 0/no-disk
  render-environment screen, env
  # type global name
  type-in env, screen, "fn1"
  # create
  edit-environment env, 0xd/ctrl-m, 0/no-disk
  render-environment screen, env
  #                                                                 | global definitions                                                                 | sandbox
  # cursor now on global side
  check-background-color-in-screen-row screen,   7/bg=cursor,  1/y, "                                           |                                                                                    ", "F - test-create-global/1-cursor"
  # no modal
  check-background-color-in-screen-row screen, 0xf/bg=modal,   0/y, "                                                                                                                                ", "F - test-create-global/bg0"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   1/y, "                                                                                                                                ", "F - test-create-global/bg1"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   2/y, "                                                                                                                                ", "F - test-create-global/bg2"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   3/y, "                                                                                                                                ", "F - test-create-global/bg3"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   4/y, "                                                                                                                                ", "F - test-create-global/bg4"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   5/y, "                                                                                                                                ", "F - test-create-global/bg5"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   6/y, "                                                                                                                                ", "F - test-create-global/bg6"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   7/y, "                                                                                                                                ", "F - test-create-global/bg7"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   8/y, "                                                                                                                                ", "F - test-create-global/bg8"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   9/y, "                                                                                                                                ", "F - test-create-global/bg9"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xa/y, "                                                                                                                                ", "F - test-create-global/bg10"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xb/y, "                                                                                                                                ", "F - test-create-global/bg11"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xc/y, "                                                                                                                                ", "F - test-create-global/bg12"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xd/y, "                                                                                                                                ", "F - test-create-global/bg13"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xe/y, "                                                                                                                                ", "F - test-create-global/bg14"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xf/y, "                                                                                                                                ", "F - test-create-global/bg15"
}

fn test-create-nonexistent-global {
  var env-storage: environment
  var env/esi: (addr environment) <- address env-storage
  initialize-environment env, 8/fake-screen-width, 3/fake-screen-height
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width, 0x10/height, 0/no-pixel-graphics
  # define a global
  type-in env, screen, "(define f 42)"
  edit-environment env, 0x13/ctrl-s, 0/no-disk
  render-environment screen, env
  # type in its name
  type-in env, screen, "f"
  # hit ctrl-g
  edit-environment env, 7/ctrl-g, 0/no-disk
  render-environment screen, env
  # submit
  edit-environment env, 0xd/ctrl-m, 0/no-disk
  render-environment screen, env
  # modal now shows an error
  #                                                                 | global definitions                                                                 | sandbox
  check-background-color-in-screen-row screen, 0xf/bg=modal,   0/y, "                                                                                                                                ", "F - test-create-nonexistent-global/0"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   1/y, "                                                                                                                                ", "F - test-create-nonexistent-global/1"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   2/y, "                                                                                                                                ", "F - test-create-nonexistent-global/2"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   3/y, "                                                                                                                                ", "F - test-create-nonexistent-global/3"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   4/y, "                                                                                                                                ", "F - test-create-nonexistent-global/4"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   5/y, "                                                                                                                                ", "F - test-create-nonexistent-global/5"
  check-screen-row                     screen,                 6/y, "                                    go to global (or leave blank to go to REPL)                                                 ", "F - test-create-nonexistent-global/6-text"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   6/y, "                                ................................................................                                ", "F - test-create-nonexistent-global/6"
  check-screen-row-in-color            screen, 4/fg=error,     7/y, "                                already exists                                                                                  ", "F - test-create-nonexistent-global/7-text"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   7/y, "                                ................................................................                                ", "F - test-create-nonexistent-global/7"
  check-screen-row-in-color            screen, 0/fg,           8/y, "                                f                                                                                               ", "F - test-create-nonexistent-global/8-text"
  check-background-color-in-screen-row screen,   0/bg=cursor,  8/y, "                                 |                                                                                              ", "F - test-create-nonexistent-global/8-cursor"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   8/y, "                                . ..............................................................                                ", "F - test-create-nonexistent-global/8"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   9/y, "                                                                                                                                ", "F - test-create-nonexistent-global/9"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xa/y, "                                                                                                                                ", "F - test-create-nonexistent-global/10"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xb/y, "                                                                                                                                ", "F - test-create-nonexistent-global/11"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xc/y, "                                                                                                                                ", "F - test-create-nonexistent-global/12"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xd/y, "                                                                                                                                ", "F - test-create-nonexistent-global/13"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xe/y, "                                                                                                                                ", "F - test-create-nonexistent-global/14"
  # menu at bottom is correct in context
  check-screen-row                     screen,               0xf/y, " ^r  run main   enter  go   ^m  create   esc  cancel   ^a  <<   ^b  <word   ^f  word>   ^e  >>                                  ", "F - test-create-nonexistent-global/15-text"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xf/y, "                                                                                                                                ", "F - test-create-nonexistent-global/15"
  # cancel
  edit-environment env, 0x1b/escape, 0/no-disk
  render-environment screen, env
  # hit ctrl-g again
  edit-environment env, 7/ctrl-g, 0/no-disk
  render-environment screen, env
  # word prepopulated like before, but no error
  check-background-color-in-screen-row screen, 0xf/bg=modal,   0/y, "                                                                                                                                ", "F - test-create-nonexistent-global/test2-0"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   1/y, "                                                                                                                                ", "F - test-create-nonexistent-global/test2-1"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   2/y, "                                                                                                                                ", "F - test-create-nonexistent-global/test2-2"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   3/y, "                                                                                                                                ", "F - test-create-nonexistent-global/test2-3"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   4/y, "                                                                                                                                ", "F - test-create-nonexistent-global/test2-4"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   5/y, "                                                                                                                                ", "F - test-create-nonexistent-global/test2-5"
  check-screen-row                     screen,                 6/y, "                                    go to global (or leave blank to go to REPL)                                                 ", "F - test-create-nonexistent-global/test2-6-text"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   6/y, "                                ................................................................                                ", "F - test-create-nonexistent-global/test2-6"
  check-screen-row-in-color            screen, 4/fg=error,     7/y, "                                                                                                                                ", "F - test-create-nonexistent-global/test2-7-text"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   7/y, "                                ................................................................                                ", "F - test-create-nonexistent-global/test2-7"
  # same word at cursor
  check-screen-row-in-color            screen, 0/fg,           8/y, "                                f                                                                                               ", "F - test-create-nonexistent-global/test2-8-text"
  # new cursor position
  check-background-color-in-screen-row screen,   0/bg=cursor,  8/y, "                                 |                                                                                              ", "F - test-create-nonexistent-global/test2-8-cursor"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   8/y, "                                . ..............................................................                                ", "F - test-create-nonexistent-global/test2-8"
  check-background-color-in-screen-row screen, 0xf/bg=modal,   9/y, "                                                                                                                                ", "F - test-create-nonexistent-global/test2-9"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xa/y, "                                                                                                                                ", "F - test-create-nonexistent-global/test2-10"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xb/y, "                                                                                                                                ", "F - test-create-nonexistent-global/test2-11"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xc/y, "                                                                                                                                ", "F - test-create-nonexistent-global/test2-12"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xd/y, "                                                                                                                                ", "F - test-create-nonexistent-global/test2-13"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xe/y, "                                                                                                                                ", "F - test-create-nonexistent-global/test2-14"
  check-background-color-in-screen-row screen, 0xf/bg=modal, 0xf/y, "                                                                                                                                ", "F - test-create-nonexistent-global/test2-15"
}

fn render-go-modal screen: (addr screen), _self: (addr environment) {
  var self/esi: (addr environment) <- copy _self
  var width/eax: int <- copy 0
  var height/ecx: int <- copy 0
  width, height <- screen-size screen
  # xmin = max(0, width/2 - 0x20)
  var xmin: int
  var tmp/edx: int <- copy width
  tmp <- shift-right 1
  tmp <- subtract 0x20/half-global-name-capacity
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
  tmp <- add 0x20/half-global-name-capacity
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
  draw-text-rightward-from-cursor screen, "go to global (or leave blank to go to REPL)", xmax, 8/fg=dark-grey, 0xf/bg=modal
  var partial-global-name-ah/eax: (addr handle gap-buffer) <- get self, partial-global-name
  var _partial-global-name/eax: (addr gap-buffer) <- lookup *partial-global-name-ah
  var partial-global-name/edx: (addr gap-buffer) <- copy _partial-global-name
  subtract-from xmin, 4
  increment ymin
  {
    var go-modal-error-ah/eax: (addr handle array byte) <- get self, go-modal-error
    var go-modal-error/eax: (addr array byte) <- lookup *go-modal-error-ah
    compare go-modal-error, 0
    break-if-=
    var dummy/eax: int <- draw-text-rightward screen, go-modal-error, xmin, xmax, ymin, 4/fg=error, 0xf/bg=modal
  }
  increment ymin
  var dummy/eax: int <- copy 0
  var dummy2/ecx: int <- copy 0
  dummy, dummy2 <- render-gap-buffer-wrapping-right-then-down screen, partial-global-name, xmin, ymin, xmax, ymax, 1/always-render-cursor, 0/fg=black, 0xf/bg=modal
}

fn render-go-modal-menu screen: (addr screen), _self: (addr environment) {
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
  draw-text-rightward-from-cursor screen, " enter ", width, 0/fg, 0xc/bg=menu-really-highlight
  draw-text-rightward-from-cursor screen, " go  ", width, 7/fg, 0xc5/bg=blue-bg
  draw-text-rightward-from-cursor screen, " ^m ", width, 0/fg, 0xc/bg=menu-really-highlight
  draw-text-rightward-from-cursor screen, " create  ", width, 7/fg, 0xc5/bg=blue-bg
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
  var cursor-in-go-modal-a/eax: (addr boolean) <- get self, cursor-in-go-modal?
  compare *cursor-in-go-modal-a, 0/false
  {
    break-if-=
    # cursor in go modal
    return
  }
  var cursor-in-globals-a/edx: (addr boolean) <- get self, cursor-in-globals?
  compare *cursor-in-globals-a, 0/false
  {
    break-if-=
    # cursor in some global editor
    var globals/eax: (addr global-table) <- get self, globals
    var cursor-index/ecx: int <- cursor-global globals
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
  var s-storage: (stream byte 0x40000)  # space for 0x200/sectors
  var s/ebx: (addr stream byte) <- address s-storage
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "loading sectors from data disk", 3/fg, 0/bg
  move-cursor-to-left-margin-of-next-line 0/screen
  load-sectors data-disk, 0/lba, 0x200/sectors, s
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
    var sandbox-data-ah/eax: (addr handle stream byte) <- get sandbox-cell, text-data
    var _sandbox-data/eax: (addr stream byte) <- lookup *sandbox-data-ah
    var sandbox-data/ecx: (addr stream byte) <- copy _sandbox-data
    # stream -> gap-buffer
    var sandbox/eax: (addr sandbox) <- get self, sandbox
    var data-ah/eax: (addr handle gap-buffer) <- get sandbox, data
    var data/eax: (addr gap-buffer) <- lookup *data-ah
    load-gap-buffer-from-stream data, sandbox-data
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
  var stream-storage: (stream byte 0x40000)  # space enough for 0x200/sectors
  var stream/edi: (addr stream byte) <- address stream-storage
  write stream, "(\n"
  write-globals stream, globals
  write-sandbox stream, sandbox
  write stream, ")\n"
  store-sectors data-disk, 0/lba, 0x200/sectors, stream
}
