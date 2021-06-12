type global-table {
  data: (handle array global)
  final-index: int
  cursor-index: int
}

type global {
  name: (handle array byte)
  input: (handle gap-buffer)
  value: (handle cell)
  trace: (handle trace)
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
  populate data-ah, 0x80
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
    load-gap-buffer-from-stream value-gap-buffer, value-data
    read-evaluate-and-move-to-globals value-gap-buffer-ah, self, name-data
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
      {
        compare curr-input, 0
        break-if-!=
        abort "null gap buffer"
      }
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
  var cursor-index/edx: (addr int) <- get self, cursor-index
  var curr-index/edx: int <- copy *cursor-index
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
      var cursor-in-current-line?: boolean
      {
        compare show-cursor?, 0/false
        break-if-=
        var cursor-index/eax: (addr int) <- get self, cursor-index
        compare *cursor-index, curr-index
        break-if-!=
        copy-to cursor-in-current-line?, 1/true
      }
      var curr-offset/edx: (offset global) <- compute-offset data, curr-index
      var curr/edx: (addr global) <- index data, curr-offset
      var curr-input-ah/eax: (addr handle gap-buffer) <- get curr, input
      var _curr-input/eax: (addr gap-buffer) <- lookup *curr-input-ah
      var curr-input/ebx: (addr gap-buffer) <- copy _curr-input
      compare curr-input, 0
      break-if-=
      var curr-trace-ah/eax: (addr handle trace) <- get curr, trace
      var _curr-trace/eax: (addr trace) <- lookup *curr-trace-ah
      var curr-trace/edx: (addr trace) <- copy _curr-trace
      $render-globals:render-global: {
        var x/eax: int <- copy 0
        var y/ecx: int <- copy y1
        compare y, y2
        {
          break-if->=
          x, y <- render-gap-buffer-wrapping-right-then-down screen, curr-input, 1/padding-left, y1, 0x2a/xmax, 0x2f/ymax, cursor-in-current-line?, 7/fg=definition, 0xc5/bg=blue-bg
          y <- increment
          y <- render-trace screen, curr-trace, 1/padding-left, y, 0x2a/xmax, 0x2f/ymax, 0/no-cursor
          y <- increment
          copy-to y1, y
          break $render-globals:render-global
        }
        x, y <- render-gap-buffer-wrapping-right-then-down screen, curr-input, 0x2b/xmin, y2, 0x54/xmax, 0x2f/ymax, cursor-in-current-line?, 7/fg=definition, 0xc5/bg=blue-bg
        y <- increment
        y <- render-trace screen, curr-trace, 0x2b/xmin, y, 0x54/xmax, 0x2f/ymax, 0/no-cursor
        y <- increment
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
  draw-text-rightward-from-cursor screen, " ^s ", width, 0/fg, 0x5c/bg=menu-highlight
  draw-text-rightward-from-cursor screen, " run sandbox  ", width, 7/fg, 0xc5/bg=blue-bg
  draw-text-rightward-from-cursor screen, " ^g ", width, 0/fg, 0x5c/bg=menu-highlight
  draw-text-rightward-from-cursor screen, " go to  ", width, 7/fg, 0xc5/bg=blue-bg
  draw-text-rightward-from-cursor screen, " ^a ", width, 0/fg, 0x5c/bg=menu-highlight
  draw-text-rightward-from-cursor screen, " <<  ", width, 7/fg, 0xc5/bg=blue-bg
  draw-text-rightward-from-cursor screen, " ^b ", width, 0/fg, 0x5c/bg=menu-highlight
  draw-text-rightward-from-cursor screen, " <word  ", width, 7/fg, 0xc5/bg=blue-bg
  draw-text-rightward-from-cursor screen, " ^f ", width, 0/fg, 0x5c/bg=menu-highlight
  draw-text-rightward-from-cursor screen, " word>  ", width, 7/fg, 0xc5/bg=blue-bg
  draw-text-rightward-from-cursor screen, " ^e ", width, 0/fg, 0x5c/bg=menu-highlight
  draw-text-rightward-from-cursor screen, " >>  ", width, 7/fg, 0xc5/bg=blue-bg
}

fn edit-globals _self: (addr global-table), key: grapheme {
  var self/esi: (addr global-table) <- copy _self
  # ctrl-s
  {
    compare key, 0x13/ctrl-s
    break-if-!=
    #
    refresh-cursor-definition self
    return
  }
  var cursor-index-addr/ecx: (addr int) <- get self, cursor-index
  var cursor-index/ecx: int <- copy *cursor-index-addr
  var data-ah/eax: (addr handle array global) <- get self, data
  var data/eax: (addr array global) <- lookup *data-ah
  var cursor-offset/ecx: (offset global) <- compute-offset data, cursor-index
  var curr-global/eax: (addr global) <- index data, cursor-offset
  var curr-editor-ah/eax: (addr handle gap-buffer) <- get curr-global, input
  var curr-editor/eax: (addr gap-buffer) <- lookup *curr-editor-ah
  edit-gap-buffer curr-editor, key
}

fn create-empty-global _self: (addr global-table), name-stream: (addr stream byte), capacity: int {
  var self/esi: (addr global-table) <- copy _self
  var final-index-addr/ecx: (addr int) <- get self, final-index
  increment *final-index-addr
  var curr-index/ecx: int <- copy *final-index-addr
  var cursor-index-addr/eax: (addr int) <- get self, cursor-index
  copy-to *cursor-index-addr, curr-index
  var data-ah/eax: (addr handle array global) <- get self, data
  var data/eax: (addr array global) <- lookup *data-ah
  var curr-offset/ecx: (offset global) <- compute-offset data, curr-index
  var curr/esi: (addr global) <- index data, curr-offset
  var curr-name-ah/eax: (addr handle array byte) <- get curr, name
  stream-to-array name-stream, curr-name-ah
  var curr-input-ah/eax: (addr handle gap-buffer) <- get curr, input
  allocate curr-input-ah
  var curr-input/eax: (addr gap-buffer) <- lookup *curr-input-ah
  initialize-gap-buffer curr-input, capacity
  var trace-ah/eax: (addr handle trace) <- get curr, trace
  allocate trace-ah
  var trace/eax: (addr trace) <- lookup *trace-ah
  initialize-trace trace, 1/only-errors, 0x10/capacity, 0/visible
}

fn refresh-cursor-definition _self: (addr global-table) {
  var self/esi: (addr global-table) <- copy _self
  var cursor-index/edx: (addr int) <- get self, cursor-index
  refresh-definition self, *cursor-index
}

# HERE: reconcile what happens here
fn refresh-definition _self: (addr global-table), _index: int {
  var self/esi: (addr global-table) <- copy _self
  var data-ah/eax: (addr handle array global) <- get self, data
  var data/eax: (addr array global) <- lookup *data-ah
  var index/ebx: int <- copy _index
  var offset/ebx: (offset global) <- compute-offset data, index
  var curr-global/ebx: (addr global) <- index data, offset
  var curr-input-ah/eax: (addr handle gap-buffer) <- get curr-global, input
  var _curr-input/eax: (addr gap-buffer) <- lookup *curr-input-ah
  var curr-input/edx: (addr gap-buffer) <- copy _curr-input
  var curr-trace-ah/eax: (addr handle trace) <- get curr-global, trace
  var curr-trace/eax: (addr trace) <- lookup *curr-trace-ah
  clear-trace curr-trace
  var read-result-h: (handle cell)
  var read-result-ah/ecx: (addr handle cell) <- address read-result-h
  read-cell curr-input, read-result-ah, curr-trace
  {
    var error?/eax: boolean <- has-errors? curr-trace
    compare error?, 0/false
    break-if-=
    return
  }
  macroexpand read-result-ah, self, curr-trace
  {
    var error?/eax: boolean <- has-errors? curr-trace
    compare error?, 0/false
    break-if-=
    return
  }
  var nil-h: (handle cell)
  {
    var nil-ah/eax: (addr handle cell) <- address nil-h
    allocate-pair nil-ah
  }
  var curr-value-ah/edi: (addr handle cell) <- get curr-global, value
  debug-print "GL", 4/fg, 0/bg
  evaluate read-result-ah, curr-value-ah, nil-h, self, curr-trace, 0/no-screen-cell, 0/no-keyboard-cell, 0/definitions-created, 1/call-number
  debug-print "GZ", 4/fg, 0/bg
  {
    var error?/eax: boolean <- has-errors? curr-trace
    compare error?, 0/false
    break-if-=
    return
  }
  # update definition name if necessary
  var curr-global-name-ah/edx: (addr handle array byte) <- get curr-global, name
  var _curr-global-name/eax: (addr array byte) <- lookup *curr-global-name-ah
  var curr-global-name/ebx: (addr array byte) <- copy _curr-global-name
  var read-result/eax: (addr cell) <- lookup *read-result-ah
  {
    var is-definition?/eax: boolean <- is-definition? read-result
    compare is-definition?, 0/false
    break-if-!=
    return
  }
  # (no error checking since it's a definition and there were no errors)
  var rest-ah/eax: (addr handle cell) <- get read-result, right
  var rest/eax: (addr cell) <- lookup *rest-ah
  var correct-definition-symbol-ah/eax: (addr handle cell) <- get rest, left
  var correct-definition-symbol/eax: (addr cell) <- lookup *correct-definition-symbol-ah
  var correct-definition-name-ah/eax: (addr handle stream byte) <- get correct-definition-symbol, text-data
  var correct-definition-name/eax: (addr stream byte) <- lookup *correct-definition-name-ah
  {
    var still-matches?/eax: boolean <- stream-data-equal? correct-definition-name, curr-global-name
    compare still-matches?, 0/false
    break-if-=
    return
  }
  stream-to-array correct-definition-name, curr-global-name-ah
}

fn assign-or-create-global _self: (addr global-table), name: (addr array byte), value: (handle cell), index-updated: (addr int), trace: (addr trace) {
  var self/esi: (addr global-table) <- copy _self
  compare self, 0
  {
    break-if-!=
    abort "assign global"
  }
  var curr-index/ecx: int <- find-symbol-name-in-globals self, name
  {
    compare curr-index, -1/not-found
    break-if-!=
    var final-index-addr/eax: (addr int) <- get self, final-index
    increment *final-index-addr
    curr-index <- copy *final-index-addr
    var cursor-index-addr/eax: (addr int) <- get self, cursor-index
    copy-to *cursor-index-addr, curr-index
  }
  var data-ah/eax: (addr handle array global) <- get self, data
  var data/eax: (addr array global) <- lookup *data-ah
  var curr-offset/esi: (offset global) <- compute-offset data, curr-index
  var curr/esi: (addr global) <- index data, curr-offset
  var curr-name-ah/eax: (addr handle array byte) <- get curr, name
  copy-array-object name, curr-name-ah
  var curr-value-ah/eax: (addr handle cell) <- get curr, value
  copy-handle value, curr-value-ah
  var index-updated/edi: (addr int) <- copy index-updated
  copy-to *index-updated, curr-index
  var trace-ah/eax: (addr handle trace) <- get curr, trace
  allocate trace-ah
  var trace/eax: (addr trace) <- lookup *trace-ah
  initialize-trace trace, 1/only-errors, 0x10/capacity, 0/visible
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

fn stash-gap-buffer-to-globals _globals: (addr global-table), definitions: (addr stream int), gap: (addr handle gap-buffer) {
  var globals/eax: (addr global-table) <- copy _globals
  compare globals, 0
  {
    break-if-!=
    return
  }
  var global-data-ah/eax: (addr handle array global) <- get globals, data
  var global-data/eax: (addr array global) <- lookup *global-data-ah
  rewind-stream definitions
  {
    {
      var done?/eax: boolean <- stream-empty? definitions
      compare done?, 0/false
    }
    break-if-!=
    var index: int
    var index-addr/ecx: (addr int) <- address index
    read-from-stream definitions, index-addr
    var index/ecx: int <- copy *index-addr
    var offset/ebx: (offset global) <- compute-offset global-data, index
    var dest-global/eax: (addr global) <- index global-data, offset
    var dest-ah/eax: (addr handle gap-buffer) <- get dest-global, input
    copy-object gap, dest-ah
    loop
  }
}

fn is-definition? _expr: (addr cell) -> _/eax: boolean {
  var expr/eax: (addr cell) <- copy _expr
  # if expr->left is neither "define" nor "set", return
  var left-ah/eax: (addr handle cell) <- get expr, left
  var _left/eax: (addr cell) <- lookup *left-ah
  var left/ecx: (addr cell) <- copy _left
  {
    var def?/eax: boolean <- symbol-equal? left, "define"
    compare def?, 0/false
    break-if-=
    return 1/true
  }
  {
    var set?/eax: boolean <- symbol-equal? left, "set"
    compare set?, 0/false
    break-if-=
    return 1/true
  }
  return 0/false
}

# HERE: ..and this
fn read-evaluate-and-move-to-globals _in-ah: (addr handle gap-buffer), globals: (addr global-table), definition-name: (addr stream byte) {
  var in-ah/eax: (addr handle gap-buffer) <- copy _in-ah
  var in/eax: (addr gap-buffer) <- lookup *in-ah
  var read-result-h: (handle cell)
  var read-result-ah/esi: (addr handle cell) <- address read-result-h
  var trace-storage: trace
  var trace/edx: (addr trace) <- address trace-storage
  initialize-trace trace, 1/only-errors, 0x10/capacity, 0/visible
  read-cell in, read-result-ah, trace
  macroexpand read-result-ah, globals, trace
  var nil-storage: (handle cell)
  var nil-ah/eax: (addr handle cell) <- address nil-storage
  allocate-pair nil-ah
  var eval-result-storage: (handle cell)
  var eval-result/edi: (addr handle cell) <- address eval-result-storage
  debug-print "^", 4/fg, 0/bg
  evaluate read-result-ah, eval-result, *nil-ah, globals, trace, 0/no-screen-cell, 0/no-keyboard-cell, 0/definitions-created, 1/call-number
  {
    var error?/eax: boolean <- has-errors? trace
    compare error?, 0/false
    break-if-=
    set-cursor-position 0/screen, 0x40/x, 0x18/y
    draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "error when loading definition for ", 4/fg 0/bg
    rewind-stream definition-name
    draw-stream-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, definition-name, 3/fg 0/bg
    set-cursor-position 0/screen, 0x40/x, 0x19/y
    draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "see trace in grey at top-left", 7/fg 0/bg
    dump-trace trace  # will print from 0, 0
    {
      loop
    }
  }
  debug-print "$", 4/fg, 0/bg
  # Naively check if read-result is a definition, and if so save the gap-buffer
  # to the appropriate global.
  {
    var _read-result/eax: (addr cell) <- lookup *read-result-ah
    var read-result/esi: (addr cell) <- copy _read-result
    var read-result-type/eax: (addr int) <- get read-result, type
    compare *read-result-type, 0/pair
    {
      break-if-=
      return
    }
    # if read-result->left is neither "define" nor "set", return
    var left-ah/eax: (addr handle cell) <- get read-result, left
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
    # locate the global for read-result->right->left
    var right-ah/eax: (addr handle cell) <- get read-result, right
    var right/eax: (addr cell) <- lookup *right-ah
    var defined-symbol-ah/eax: (addr handle cell) <- get right, left
    var defined-symbol/eax: (addr cell) <- lookup *defined-symbol-ah
    var defined-symbol-name-ah/eax: (addr handle stream byte) <- get defined-symbol, text-data
    var defined-symbol-name/eax: (addr stream byte) <- lookup *defined-symbol-name-ah
    var index/ecx: int <- find-symbol-in-globals globals, defined-symbol-name
    {
      compare index, -1/not-found
      break-if-!=
      return
    }
    # move 'gap' to it
    var globals/eax: (addr global-table) <- copy globals
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
    copy-object _in-ah, dest-ah
  }
}

fn set-global-cursor-index _globals: (addr global-table), name-gap: (addr gap-buffer) {
  var globals/esi: (addr global-table) <- copy _globals
  var name-storage: (stream byte 0x40)
  var name/ecx: (addr stream byte) <- address name-storage
  emit-gap-buffer name-gap, name
  var index/ecx: int <- find-symbol-in-globals globals, name
  var dest/edi: (addr int) <- get globals, cursor-index
  copy-to *dest, index
}
