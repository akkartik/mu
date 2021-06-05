type environment {
  globals: global-table
  sandbox: sandbox
  partial-function-name: (handle gap-buffer)
  cursor-in-globals?: boolean
  cursor-in-function-modal?: boolean
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
  # ctrl-g: go to a function (or the repl)
  {
    compare key, 7/ctrl-g
    break-if-!=
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
      return
    }
    # enter = switch to function name and exit modal dialog
    {
      compare key, 0xa/newline
      break-if-!=
      var cursor-in-globals-a/edx: (addr boolean) <- get self, cursor-in-globals?
      copy-to *cursor-in-globals-a, 1/true
      # TODO: use function name
      var partial-function-name-ah/eax: (addr handle gap-buffer) <- get self, partial-function-name
      var partial-function-name/eax: (addr gap-buffer) <- lookup *partial-function-name-ah
      var cursor-in-globals-a/ecx: (addr boolean) <- get self, cursor-in-globals?
      copy-to *cursor-in-globals-a, 1/true
      {
        var empty?/eax: boolean <- gap-buffer-empty? partial-function-name
        compare empty?, 0/false
        break-if-=
        copy-to *cursor-in-globals-a, 0/false
      }
      clear-gap-buffer partial-function-name
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
    edit-globals globals, key, data-disk
    return
  }
  edit-sandbox sandbox, key, globals, data-disk, 1/tweak-real-screen
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
  add-to ymin 2
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

# Gotcha: some saved state may not load.
fn load-state _self: (addr environment), data-disk: (addr disk) {
  var self/esi: (addr environment) <- copy _self
  # data-disk -> stream
  var s-storage: (stream byte 0x1000)  # space for 8/sectors
  var s/ebx: (addr stream byte) <- address s-storage
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "loading sectors from data disk", 3/fg, 0/bg
  move-cursor-to-left-margin-of-next-line 0/screen
  load-sectors data-disk, 0/lba, 8/sectors, s
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
  var stream-storage: (stream byte 0x1000)  # space enough for 8/sectors
  var stream/edi: (addr stream byte) <- address stream-storage
  write stream, "(\n"
  write-globals stream, globals
  write-sandbox stream, sandbox
  write stream, ")\n"
  store-sectors data-disk, 0/lba, 8/sectors, stream
}
