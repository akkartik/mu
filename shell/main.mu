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
  {
    render-globals screen, globals, 0/x, 0/y, 0x40/xmax, 0x2f/screen-height-without-menu
    render-sandbox screen, sandbox, 0x40/x, 0/y, 0x80/screen-width, 0x2f/screen-height-without-menu, globals
    {
      var key/eax: byte <- read-key keyboard
      compare key, 0
      loop-if-=
      # no way to quit right now; just reboot
      edit-sandbox sandbox, key, globals, screen, keyboard, data-disk
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
  var s-storage: (stream byte 0x800)  # space for 4/sectors
  var s/ebx: (addr stream byte) <- address s-storage
  load-sectors data-disk, 0/lba, 4/sectors, s
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
  compare globals-cell, 0
  {
    break-if-!=
    return
  }
  load-globals globals-cell-ah, globals
  # sandbox = assoc(initial-root, 'sandbox)
  var sandbox-literal-storage: (handle cell)
  var sandbox-literal-ah/eax: (addr handle cell) <- address sandbox-literal-storage
  new-symbol sandbox-literal-ah, "sandbox"
  var sandbox-literal/eax: (addr cell) <- lookup *sandbox-literal-ah
  var sandbox-cell-storage: (handle cell)
  var sandbox-cell-ah/edx: (addr handle cell) <- address sandbox-cell-storage
  lookup-symbol sandbox-literal, sandbox-cell-ah, *initial-root, 0/no-globals, 0/no-trace, 0/no-screen, 0/no-keyboard
  var sandbox-cell/eax: (addr cell) <- lookup *sandbox-cell-ah
  compare sandbox-cell, 0
  {
    break-if-!=
    return
  }
  # print: cell -> stream
  print-cell sandbox-cell-ah, s, 0/no-trace
  # stream -> gap-buffer
  load-gap-buffer-from-stream data, s
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
  var stream-storage: (stream byte 0x800)  # space enough for 4/sectors
  var stream/edi: (addr stream byte) <- address stream-storage
  write stream, "(\n"
  write-globals stream, globals
  write-sandbox stream, sandbox
  write stream, ")\n"
  store-sectors data-disk, 0/lba, 4/sectors, stream
}
