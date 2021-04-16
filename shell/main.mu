# Experimental Mu shell
# A Lisp with indent-sensitivity and infix.

fn main screen: (addr screen), keyboard: (addr keyboard), data-disk: (addr disk) {
  var globals-storage: global-table
  var globals/edi: (addr global-table) <- address globals-storage
  initialize-globals globals
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox sandbox, 1/with-screen
  load-sandbox data-disk, sandbox
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

# Read an s-expression from data-disk to sandbox.
# Gotcha: saved state with syntax errors may not load, and may need to be
# edited as a disk image to get it to load.
fn load-sandbox data-disk: (addr disk), _self: (addr sandbox) {
  var self/eax: (addr sandbox) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, data
  var _data/eax: (addr gap-buffer) <- lookup *data-ah
  var data/esi: (addr gap-buffer) <- copy _data
  # data-disk -> stream
  var s-storage: (stream byte 0x200)
  var s/ebx: (addr stream byte) <- address s-storage
  load-sector data-disk, 0/lba, s
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
  # print: cell -> stream
  print-cell initial-root, s, 0/no-trace
  # stream -> gap-buffer
  load-gap-buffer-from-stream data, s
}

fn store-sandbox data-disk: (addr disk), _self: (addr sandbox) {
  compare data-disk, 0/no-disk
  {
    break-if-!=
    return
  }
  var self/eax: (addr sandbox) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  var stream-storage: (stream byte 0x200)
  var stream/edi: (addr stream byte) <- address stream-storage
  emit-gap-buffer data, stream
  store-sector data-disk, 0/lba, stream
}
