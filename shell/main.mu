# Experimental Mu shell
# A Lisp with indent-sensitivity and infix.

fn main screen: (addr screen), keyboard: (addr keyboard), data-disk: (addr disk) {
  var globals-storage: global-table
  var globals/edi: (addr global-table) <- address globals-storage
  initialize-globals globals
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox sandbox, 1/with-screen
  load-state data-disk, sandbox, globals
  $main:loop: {
    render-globals screen, globals, 0/x, 0/y, 0x40/xmax, 0x2f/screen-height-without-menu
    render-sandbox screen, sandbox, 0x40/x, 0/y, 0x80/screen-width, 0x2f/screen-height-without-menu, globals
    {
      var key/eax: byte <- read-key keyboard
      compare key, 0
      loop-if-=
      # ctrl-r
      {
        compare key, 0x12/ctrl-r
        break-if-!=
        var tmp/eax: (addr handle cell) <- copy 0
        var nil: (handle cell)
        tmp <- address nil
        allocate-pair tmp
        # (main 0/real-screen 0/real-keyboard)
        # We're using the fact that 'screen' and 'keyboard' in this function are always 0.
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
        clear-screen screen
        set-cursor-position screen, 0, 0
        # run
        var out: (handle cell)
        var out-ah/ecx: (addr handle cell) <- address out
        evaluate tmp, out-ah, nil, globals, 0/trace, 0/no-fake-screen, 0/no-fake-keyboard, 0/call-number
        {
          var tmp/eax: byte <- read-key keyboard
          compare tmp, 0
          loop-if-=
        }
        #
        loop $main:loop
      }
      # no way to quit right now; just reboot
      edit-sandbox sandbox, key, globals, screen, data-disk
    }
    loop
  }
}

# Gotcha: some saved state may not load.
fn load-state data-disk: (addr disk), _sandbox: (addr sandbox), globals: (addr global-table) {
  var sandbox/eax: (addr sandbox) <- copy _sandbox
  var data-ah/eax: (addr handle gap-buffer) <- get sandbox, data
  var _data/eax: (addr gap-buffer) <- lookup *data-ah
  var data/esi: (addr gap-buffer) <- copy _data
  # data-disk -> stream
  var s-storage: (stream byte 0x1000)  # space for 8/sectors
  var s/ebx: (addr stream byte) <- address s-storage
  load-sectors data-disk, 0/lba, 8/sectors, s
#?   draw-stream-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, s, 7/fg, 0/bg
  # stream -> gap-buffer
  load-gap-buffer-from-stream data, s
  clear-stream s
  # read: gap-buffer -> cell
  var initial-root-storage: (handle cell)
  var initial-root/ecx: (addr handle cell) <- address initial-root-storage
  read-cell data, initial-root, 0/no-trace
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
  lookup-symbol globals-literal, globals-cell-ah, *initial-root, 0/no-globals, 0/no-trace, 0/no-screen, 0/no-keyboard
  var globals-cell/eax: (addr cell) <- lookup *globals-cell-ah
  {
    compare globals-cell, 0
    break-if-=
    load-globals globals-cell-ah, globals
  }
  # sandbox = assoc(initial-root, 'sandbox)
  var sandbox-literal-storage: (handle cell)
  var sandbox-literal-ah/eax: (addr handle cell) <- address sandbox-literal-storage
  new-symbol sandbox-literal-ah, "sandbox"
  var sandbox-literal/eax: (addr cell) <- lookup *sandbox-literal-ah
  var sandbox-cell-storage: (handle cell)
  var sandbox-cell-ah/edx: (addr handle cell) <- address sandbox-cell-storage
  lookup-symbol sandbox-literal, sandbox-cell-ah, *initial-root, 0/no-globals, 0/no-trace, 0/no-screen, 0/no-keyboard
  var sandbox-cell/eax: (addr cell) <- lookup *sandbox-cell-ah
  {
    compare sandbox-cell, 0
    break-if-=
    # print: cell -> stream
    print-cell sandbox-cell-ah, s, 0/no-trace
    # stream -> gap-buffer
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
