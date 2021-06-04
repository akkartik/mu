type environment {
  globals: global-table
  sandbox: sandbox
}

fn initialize-environment _self: (addr environment) {
  var self/esi: (addr environment) <- copy _self
  var globals/eax: (addr global-table) <- get self, globals
  initialize-globals globals
  var sandbox/eax: (addr sandbox) <- get self, sandbox
  initialize-sandbox sandbox, 1/with-screen
}

fn render-environment screen: (addr screen), _self: (addr environment) {
  # globals layout: 1 char padding, 41 code, 1 padding, 41 code, 1 padding =  85
  # sandbox layout: 1 padding, 41 code, 1 padding                          =  43
  #                                                                  total = 128 chars
  var self/esi: (addr environment) <- copy _self
  var globals/eax: (addr global-table) <- get self, globals
  render-globals screen, globals
  var sandbox/eax: (addr sandbox) <- get self, sandbox
  render-sandbox screen, sandbox, 0x55/sandbox-left-margin, 0/sandbox-top-margin, 0x80/screen-width, 0x2f/screen-height-without-menu
}

fn edit-environment _self: (addr environment), key: byte, data-disk: (addr disk) {
  var self/esi: (addr environment) <- copy _self
  var globals/edi: (addr global-table) <- get self, globals
  var sandbox/esi: (addr sandbox) <- get self, sandbox
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
  edit-sandbox sandbox, key, globals, data-disk, 1/tweak-real-screen
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
