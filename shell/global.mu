type global-table {
  data: (handle array global)
  final-index: int
  cursor-index: int
}

type global {
  name: (handle array byte)
  input: (handle gap-buffer)
  value: (handle cell)
}

fn initialize-globals _self: (addr global-table) {
  var self/esi: (addr global-table) <- copy _self
  compare self, 0
  {
    break-if-!=
    abort "initialize globals"
    return
  }
  var data-ah/eax: (addr handle array global) <- get self, data
  populate data-ah, 0x40
  initialize-primitives self
}

fn load-globals in: (addr handle cell), self: (addr global-table) {
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "loading globals:", 3/fg, 0/bg
  var remaining-ah/esi: (addr handle cell) <- copy in
  {
    var _remaining/eax: (addr cell) <- lookup *remaining-ah
    var remaining/ebx: (addr cell) <- copy _remaining
    var done?/eax: boolean <- nil? remaining
    compare done?, 0/false
    break-if-!=
#?     draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "b", 2/fg 0/bg
    var curr-ah/eax: (addr handle cell) <- get remaining, left
    var _curr/eax: (addr cell) <- lookup *curr-ah
    var curr/ecx: (addr cell) <- copy _curr
    remaining-ah <- get remaining, right
    draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, " ", 2/fg 0/bg
    var name-ah/eax: (addr handle cell) <- get curr, left
    var name/eax: (addr cell) <- lookup *name-ah
    var name-data-ah/eax: (addr handle stream byte) <- get name, text-data
    var _name-data/eax: (addr stream byte) <- lookup *name-data-ah
    var name-data/edx: (addr stream byte) <- copy _name-data
    rewind-stream name-data
    draw-stream-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, name-data, 3/fg, 0/bg
    var value-ah/eax: (addr handle cell) <- get curr, right
    var value/eax: (addr cell) <- lookup *value-ah
    var value-data-ah/eax: (addr handle stream byte) <- get value, text-data
    var _value-data/eax: (addr stream byte) <- lookup *value-data-ah
    var value-data/ecx: (addr stream byte) <- copy _value-data
    var value-gap-buffer-storage: (handle gap-buffer)
    var value-gap-buffer-ah/edi: (addr handle gap-buffer) <- address value-gap-buffer-storage
    allocate value-gap-buffer-ah
    var value-gap-buffer/eax: (addr gap-buffer) <- lookup *value-gap-buffer-ah
    initialize-gap-buffer value-gap-buffer, 0x1000/4KB
#?     draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "w", 2/fg 0/bg
    load-gap-buffer-from-stream value-gap-buffer, value-data
#?     draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "x", 2/fg 0/bg
    read-evaluate-and-move-to-globals value-gap-buffer-ah, self, name-data
#?     draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "y", 2/fg 0/bg
    loop
  }
  move-cursor-to-left-margin-of-next-line 0/screen
#?   abort "zz"
}

fn write-globals out: (addr stream byte), _self: (addr global-table) {
  var self/esi: (addr global-table) <- copy _self
  compare self, 0
  {
    break-if-!=
    abort "write globals"
    return
  }
  write out, "  (globals . (\n"
  var data-ah/eax: (addr handle array global) <- get self, data
  var data/eax: (addr array global) <- lookup *data-ah
  var final-index/edx: (addr int) <- get self, final-index
  var curr-index/ecx: int <- copy 1/skip-0
  {
    compare curr-index, *final-index
    break-if->
    var curr-offset/ebx: (offset global) <- compute-offset data, curr-index
    var curr/ebx: (addr global) <- index data, curr-offset
    var curr-value-ah/edx: (addr handle cell) <- get curr, value
    var curr-value/eax: (addr cell) <- lookup *curr-value-ah
    var curr-type/eax: (addr int) <- get curr-value, type
    {
      compare *curr-type, 4/primitive-function
      break-if-=
      compare *curr-type, 5/screen
      break-if-=
      compare *curr-type, 6/keyboard
      break-if-=
      compare *curr-type, 3/stream  # not implemented yet
      break-if-=
      write out, "    ("
      var curr-name-ah/eax: (addr handle array byte) <- get curr, name
      var curr-name/eax: (addr array byte) <- lookup *curr-name-ah
      write out, curr-name
      write out, " . ["
      var curr-input-ah/eax: (addr handle gap-buffer) <- get curr, input
      var curr-input/eax: (addr gap-buffer) <- lookup *curr-input-ah
      append-gap-buffer curr-input, out
      write out, "])\n"
    }
    curr-index <- increment
    loop
  }
  write out, "  ))\n"
}

# globals layout: 1 char padding, 41 code, 1 padding, 41 code, 1 padding =  85 chars
fn render-globals screen: (addr screen), _self: (addr global-table), show-cursor?: boolean {
  clear-rect screen, 0/xmin, 0/ymin, 0x55/xmax, 0x2f/ymax=screen-height-without-menu, 0xdc/bg=green-bg
  var self/esi: (addr global-table) <- copy _self
  compare self, 0
  {
    break-if-!=
    abort "render globals"
    return
  }
  var data-ah/eax: (addr handle array global) <- get self, data
  var data/eax: (addr array global) <- lookup *data-ah
  var curr-index/edx: int <- copy 1
  {
    var curr-offset/ebx: (offset global) <- compute-offset data, curr-index
    var curr/ebx: (addr global) <- index data, curr-offset
    var continue?/eax: boolean <- primitive-global? curr
    compare continue?, 0/false
    break-if-=
    curr-index <- increment
    loop
  }
  var lowest-index/edi: int <- copy curr-index
  var final-index/edx: (addr int) <- get self, final-index
  var curr-index/edx: int <- copy *final-index
  var y1: int
  copy-to y1, 1/padding-top
  var y2: int
  copy-to y2, 1/padding-top
  $render-globals:loop: {
    compare curr-index, lowest-index
    break-if-<
    {
      compare y1, 0x2f/ymax
      break-if-<
      compare y2, 0x2f/ymax
      break-if-<
      break $render-globals:loop
    }
    {
      var show-cursor?/edi: boolean <- copy show-cursor?
      {
        compare show-cursor?, 0/false
        break-if-=
        var cursor-index/eax: (addr int) <- get self, cursor-index
        compare *cursor-index, curr-index
        break-if-=
        show-cursor? <- copy 0/false
      }
      var curr-offset/edx: (offset global) <- compute-offset data, curr-index
      var curr/edx: (addr global) <- index data, curr-offset
      var curr-input-ah/edx: (addr handle gap-buffer) <- get curr, input
      var _curr-input/eax: (addr gap-buffer) <- lookup *curr-input-ah
      var curr-input/ebx: (addr gap-buffer) <- copy _curr-input
      compare curr-input, 0
      break-if-=
      $render-globals:render-global: {
        var x/eax: int <- copy 0
        var y/ecx: int <- copy y1
        compare y, y2
        {
          break-if->=
          x, y <- render-gap-buffer-wrapping-right-then-down screen, curr-input, 1/padding-left, y1, 0x2a/xmax, 0x2f/ymax, show-cursor?, 7/fg=definition, 0xc5/bg=blue-bg
          y <- add 2
          copy-to y1, y
          break $render-globals:render-global
        }
        x, y <- render-gap-buffer-wrapping-right-then-down screen, curr-input, 0x2b/xmin, y2, 0x54/xmax, 0x2f/ymax, show-cursor?, 7/fg=definition, 0xc5/bg=blue-bg
        y <- add 2
        copy-to y2, y
      }
    }
    curr-index <- decrement
    loop
  }
  # render primitives on top
  render-primitives screen, 1/xmin=padding-left, 0x55/xmax, 0x2f/ymax
}

fn render-globals-menu screen: (addr screen), _self: (addr global-table) {
}

fn edit-globals _self: (addr global-table), key: grapheme, data-disk: (addr disk) {
}

fn assign-or-create-global _self: (addr global-table), name: (addr array byte), value: (handle cell), trace: (addr trace) {
  var self/esi: (addr global-table) <- copy _self
  compare self, 0
  {
    break-if-!=
    abort "assign global"
    return
  }
  var curr-index/ecx: int <- find-symbol-name-in-globals self, name
  {
    compare curr-index, -1/not-found
    break-if-!=
    var final-index-addr/eax: (addr int) <- get self, final-index
    increment *final-index-addr
    curr-index <- copy *final-index-addr
  }
  var data-ah/eax: (addr handle array global) <- get self, data
  var data/eax: (addr array global) <- lookup *data-ah
  var curr-offset/esi: (offset global) <- compute-offset data, curr-index
  var curr/esi: (addr global) <- index data, curr-offset
  var curr-name-ah/eax: (addr handle array byte) <- get curr, name
  copy-array-object name, curr-name-ah
  var curr-value-ah/eax: (addr handle cell) <- get curr, value
  copy-handle value, curr-value-ah
}

fn lookup-symbol-in-globals _sym: (addr cell), out: (addr handle cell), _globals: (addr global-table), trace: (addr trace), screen-cell: (addr handle cell), keyboard-cell: (addr handle cell) {
  var sym/eax: (addr cell) <- copy _sym
  var sym-name-ah/eax: (addr handle stream byte) <- get sym, text-data
  var _sym-name/eax: (addr stream byte) <- lookup *sym-name-ah
  var sym-name/edx: (addr stream byte) <- copy _sym-name
  var globals/esi: (addr global-table) <- copy _globals
  {
    compare globals, 0
    break-if-=
    var curr-index/ecx: int <- find-symbol-in-globals globals, sym-name
    compare curr-index, -1/not-found
    break-if-=
    var global-data-ah/eax: (addr handle array global) <- get globals, data
    var global-data/eax: (addr array global) <- lookup *global-data-ah
    var curr-offset/ebx: (offset global) <- compute-offset global-data, curr-index
    var curr/ebx: (addr global) <- index global-data, curr-offset
    var curr-value/eax: (addr handle cell) <- get curr, value
    copy-object curr-value, out
    return
  }
  # if sym is "screen" and screen-cell exists, return it
  {
    var sym-is-screen?/eax: boolean <- stream-data-equal? sym-name, "screen"
    compare sym-is-screen?, 0/false
    break-if-=
    compare screen-cell, 0
    break-if-=
    copy-object screen-cell, out
    return
  }
  # if sym is "keyboard" and keyboard-cell exists, return it
  {
    var sym-is-keyboard?/eax: boolean <- stream-data-equal? sym-name, "keyboard"
    compare sym-is-keyboard?, 0/false
    break-if-=
    compare keyboard-cell, 0
    break-if-=
    copy-object keyboard-cell, out
    return
  }
  # otherwise error "unbound symbol: ", sym
  var stream-storage: (stream byte 0x40)
  var stream/ecx: (addr stream byte) <- address stream-storage
  write stream, "unbound symbol: "
  rewind-stream sym-name
  write-stream stream, sym-name
  error-stream trace, stream
}

fn maybe-lookup-symbol-in-globals _sym: (addr cell), out: (addr handle cell), _globals: (addr global-table), trace: (addr trace) {
  var sym/eax: (addr cell) <- copy _sym
  var sym-name-ah/eax: (addr handle stream byte) <- get sym, text-data
  var _sym-name/eax: (addr stream byte) <- lookup *sym-name-ah
  var sym-name/edx: (addr stream byte) <- copy _sym-name
  var globals/esi: (addr global-table) <- copy _globals
  {
    compare globals, 0
    break-if-=
    var curr-index/ecx: int <- find-symbol-in-globals globals, sym-name
    compare curr-index, -1/not-found
    break-if-=
    var global-data-ah/eax: (addr handle array global) <- get globals, data
    var global-data/eax: (addr array global) <- lookup *global-data-ah
    var curr-offset/ebx: (offset global) <- compute-offset global-data, curr-index
    var curr/ebx: (addr global) <- index global-data, curr-offset
    var curr-value/eax: (addr handle cell) <- get curr, value
    copy-object curr-value, out
    return
  }
}

# return the index in globals containing 'sym'
# or -1 if not found
fn find-symbol-in-globals _globals: (addr global-table), sym-name: (addr stream byte) -> _/ecx: int {
  var globals/esi: (addr global-table) <- copy _globals
  compare globals, 0
  {
    break-if-!=
    return -1/not-found
  }
  var global-data-ah/eax: (addr handle array global) <- get globals, data
  var global-data/eax: (addr array global) <- lookup *global-data-ah
  var final-index/ecx: (addr int) <- get globals, final-index
  var curr-index/ecx: int <- copy *final-index
  {
    compare curr-index, 0
    break-if-<
    var curr-offset/ebx: (offset global) <- compute-offset global-data, curr-index
    var curr/ebx: (addr global) <- index global-data, curr-offset
    var curr-name-ah/eax: (addr handle array byte) <- get curr, name
    var curr-name/eax: (addr array byte) <- lookup *curr-name-ah
    var found?/eax: boolean <- stream-data-equal? sym-name, curr-name
    compare found?, 0/false
    {
      break-if-=
      return curr-index
    }
    curr-index <- decrement
    loop
  }
  return -1/not-found
}

# return the index in globals containing 'sym'
# or -1 if not found
fn find-symbol-name-in-globals _globals: (addr global-table), sym-name: (addr array byte) -> _/ecx: int {
  var globals/esi: (addr global-table) <- copy _globals
  compare globals, 0
  {
    break-if-!=
    return -1/not-found
  }
  var global-data-ah/eax: (addr handle array global) <- get globals, data
  var global-data/eax: (addr array global) <- lookup *global-data-ah
  var final-index/ecx: (addr int) <- get globals, final-index
  var curr-index/ecx: int <- copy *final-index
  {
    compare curr-index, 0
    break-if-<
    var curr-offset/ebx: (offset global) <- compute-offset global-data, curr-index
    var curr/ebx: (addr global) <- index global-data, curr-offset
    var curr-name-ah/eax: (addr handle array byte) <- get curr, name
    var curr-name/eax: (addr array byte) <- lookup *curr-name-ah
    var found?/eax: boolean <- string-equal? sym-name, curr-name
    compare found?, 0/false
    {
      break-if-=
      return curr-index
    }
    curr-index <- decrement
    loop
  }
  return -1/not-found
}

fn mutate-binding-in-globals name: (addr stream byte), val: (addr handle cell), _globals: (addr global-table), trace: (addr trace) {
  var globals/esi: (addr global-table) <- copy _globals
  {
    compare globals, 0
    break-if-=
    var curr-index/ecx: int <- find-symbol-in-globals globals, name
    compare curr-index, -1/not-found
    break-if-=
    var global-data-ah/eax: (addr handle array global) <- get globals, data
    var global-data/eax: (addr array global) <- lookup *global-data-ah
    var curr-offset/ebx: (offset global) <- compute-offset global-data, curr-index
    var curr/ebx: (addr global) <- index global-data, curr-offset
    var dest/eax: (addr handle cell) <- get curr, value
    copy-object val, dest
    return
  }
  # otherwise error "unbound symbol: ", sym
  var stream-storage: (stream byte 0x40)
  var stream/ecx: (addr stream byte) <- address stream-storage
  write stream, "unbound symbol: "
  rewind-stream name
  write-stream stream, name
  error-stream trace, stream
}

# Accepts an input s-expression, naively checks if it is a definition, and if
# so saves the gap-buffer to the appropriate global, spinning up a new empty
# one to replace it with.
fn maybe-stash-gap-buffer-to-global _globals: (addr global-table), _definition-ah: (addr handle cell), gap: (addr handle gap-buffer) {
  # if 'definition' is not a pair, return
  var definition-ah/eax: (addr handle cell) <- copy _definition-ah
  var _definition/eax: (addr cell) <- lookup *definition-ah
  var definition/esi: (addr cell) <- copy _definition
  var definition-type/eax: (addr int) <- get definition, type
  compare *definition-type, 0/pair
  {
    break-if-=
    return
  }
  # if definition->left is neither "define" nor "set", return
  var left-ah/eax: (addr handle cell) <- get definition, left
  var _left/eax: (addr cell) <- lookup *left-ah
  var left/ecx: (addr cell) <- copy _left
  {
    var def?/eax: boolean <- symbol-equal? left, "define"
    compare def?, 0/false
    break-if-!=
    var set?/eax: boolean <- symbol-equal? left, "set"
    compare set?, 0/false
    break-if-!=
    return
  }
  # locate the global for definition->right->left
  var right-ah/eax: (addr handle cell) <- get definition, right
  var right/eax: (addr cell) <- lookup *right-ah
  var defined-symbol-ah/eax: (addr handle cell) <- get right, left
  var defined-symbol/eax: (addr cell) <- lookup *defined-symbol-ah
  var defined-symbol-name-ah/eax: (addr handle stream byte) <- get defined-symbol, text-data
  var defined-symbol-name/eax: (addr stream byte) <- lookup *defined-symbol-name-ah
  var index/ecx: int <- find-symbol-in-globals _globals, defined-symbol-name
  {
    compare index, -1/not-found
    break-if-!=
    return
  }
  # stash 'gap' to it
  var globals/eax: (addr global-table) <- copy _globals
  compare globals, 0
  {
    break-if-!=
    abort "stash to globals"
    return
  }
  var global-data-ah/eax: (addr handle array global) <- get globals, data
  var global-data/eax: (addr array global) <- lookup *global-data-ah
  var offset/ebx: (offset global) <- compute-offset global-data, index
  var dest-global/eax: (addr global) <- index global-data, offset
  var dest-ah/eax: (addr handle gap-buffer) <- get dest-global, input
  copy-object gap, dest-ah
  # initialize a new gap-buffer in 'gap'
  var dest/eax: (addr gap-buffer) <- lookup *dest-ah
  var capacity/ecx: int <- gap-buffer-capacity dest
  var gap2/eax: (addr handle gap-buffer) <- copy gap
  allocate gap2
  var gap-addr/eax: (addr gap-buffer) <- lookup *gap2
  initialize-gap-buffer gap-addr, capacity
}

# Accepts an input s-expression, naively checks if it is a definition, and if
# so saves the gap-buffer to the appropriate global.
fn move-gap-buffer-to-global _globals: (addr global-table), _definition-ah: (addr handle cell), gap: (addr handle gap-buffer) {
  # if 'definition' is not a pair, return
  var definition-ah/eax: (addr handle cell) <- copy _definition-ah
  var _definition/eax: (addr cell) <- lookup *definition-ah
  var definition/esi: (addr cell) <- copy _definition
  var definition-type/eax: (addr int) <- get definition, type
  compare *definition-type, 0/pair
  {
    break-if-=
    return
  }
  # if definition->left is neither "define" nor "set", return
  var left-ah/eax: (addr handle cell) <- get definition, left
  var _left/eax: (addr cell) <- lookup *left-ah
  var left/ecx: (addr cell) <- copy _left
  {
    var def?/eax: boolean <- symbol-equal? left, "define"
    compare def?, 0/false
    break-if-!=
    var set?/eax: boolean <- symbol-equal? left, "set"
    compare set?, 0/false
    break-if-!=
    return
  }
  # locate the global for definition->right->left
  var right-ah/eax: (addr handle cell) <- get definition, right
  var right/eax: (addr cell) <- lookup *right-ah
  var defined-symbol-ah/eax: (addr handle cell) <- get right, left
  var defined-symbol/eax: (addr cell) <- lookup *defined-symbol-ah
  var defined-symbol-name-ah/eax: (addr handle stream byte) <- get defined-symbol, text-data
  var defined-symbol-name/eax: (addr stream byte) <- lookup *defined-symbol-name-ah
  var index/ecx: int <- find-symbol-in-globals _globals, defined-symbol-name
  {
    compare index, -1/not-found
    break-if-!=
    return
  }
  # move 'gap' to it
  var globals/eax: (addr global-table) <- copy _globals
  compare globals, 0
  {
    break-if-!=
    abort "move to globals"
    return
  }
  var global-data-ah/eax: (addr handle array global) <- get globals, data
  var global-data/eax: (addr array global) <- lookup *global-data-ah
  var offset/ebx: (offset global) <- compute-offset global-data, index
  var dest-global/eax: (addr global) <- index global-data, offset
  var dest-ah/eax: (addr handle gap-buffer) <- get dest-global, input
  copy-object gap, dest-ah
}
