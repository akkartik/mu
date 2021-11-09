type global-table {
  data: (handle array global)
  final-index: int
  render-list: (handle array int)  # sequence of globals to render on the left side
                                   # no pagination or scrolling
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
  var render-ah/eax: (addr handle array int) <- get self, render-list
  populate render-ah, 0x20/render-size
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
    var name-ah/eax: (addr handle cell) <- get curr, left
    var name/eax: (addr cell) <- lookup *name-ah
    var name-data-ah/eax: (addr handle stream byte) <- get name, text-data
    var _name-data/eax: (addr stream byte) <- lookup *name-data-ah
    var name-data/edx: (addr stream byte) <- copy _name-data
    rewind-stream name-data
    draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, " ", 3/fg 0/bg
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
    initialize-gap-buffer value-gap-buffer, 0x40000/256KB
    load-gap-buffer-from-stream value-gap-buffer, value-data
    load-lexical-scope value-gap-buffer-ah, self
    loop
  }
  move-cursor-to-left-margin-of-next-line 0/screen
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

# globals layout: 1 char padding, 41 code, 1 padding, 41 code, 1 padding = 85 chars
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
  var _data/eax: (addr array global) <- lookup *data-ah
  var data/ebx: (addr array global) <- copy _data
  var curr-index/edx: int <- copy 0
  var y1: int
  copy-to y1, 1/padding-top
  var y2: int
  copy-to y2, 1/padding-top
  $render-globals:loop: {
    compare curr-index, 0x20/render-size
    break-if->=
    {
      compare y1, 0x2f/ymax
      break-if-<
      compare y2, 0x2f/ymax
      break-if-<
      break $render-globals:loop
    }
    $render-globals:iter: {
      var cursor-in-current-line?: boolean
      {
        compare show-cursor?, 0/false
        break-if-=
        compare curr-index, 0
        break-if-!=
        copy-to cursor-in-current-line?, 1/true
      }
      var render-list-ah/eax: (addr handle array int) <- get self, render-list
      var render-list/eax: (addr array int) <- lookup *render-list-ah
      var global-id-a/eax: (addr int) <- index render-list, curr-index
      var global-id/eax: int <- copy *global-id-a
      compare global-id, 0
      break-if-=
      var global-offset/edx: (offset global) <- compute-offset data, global-id
      var curr/edx: (addr global) <- index data, global-offset
      {
        var render-image?/eax: boolean <- render-image? curr, cursor-in-current-line?
        compare render-image?, 0/false
        break-if-=
        var y/ecx: int <- render-image-definition screen, curr, 0/x y1
        y <- increment  # padding
        copy-to y1, y
        break $render-globals:iter
      }
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
    curr-index <- increment
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

fn edit-globals _self: (addr global-table), key: code-point-utf8 {
  var self/esi: (addr global-table) <- copy _self
  # ctrl-s
  {
    compare key, 0x13/ctrl-s
    break-if-!=
    #
    refresh-cursor-definition self
    return
  }
  var cursor-index/ecx: int <- cursor-global self
  compare cursor-index, 0
  {
    break-if-!=
    return
  }
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
  var render-list-ah/eax: (addr handle array int) <- get self, render-list
  var render-list/eax: (addr array int) <- lookup *render-list-ah
  slide-down render-list, 0/start 0x1f/penultimate, 1/target
  var curr-index/ecx: int <- copy *final-index-addr
  var dest/eax: (addr int) <- index render-list, 0
  copy-to *dest, curr-index
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
  var render-list-ah/eax: (addr handle array int) <- get self, render-list
  var render-list/eax: (addr array int) <- lookup *render-list-ah
  var cursor-index/edx: (addr int) <- index render-list, 0
  refresh-definition self, *cursor-index
}

fn refresh-definition _self: (addr global-table), _index: int {
  var self/esi: (addr global-table) <- copy _self
  var data-ah/eax: (addr handle array global) <- get self, data
  var data/eax: (addr array global) <- lookup *data-ah
  var index/ebx: int <- copy _index
  var offset/ebx: (offset global) <- compute-offset data, index
  var curr-global/ebx: (addr global) <- index data, offset
  var curr-input-ah/edx: (addr handle gap-buffer) <- get curr-global, input
  var curr-trace-ah/eax: (addr handle trace) <- get curr-global, trace
  var curr-trace/eax: (addr trace) <- lookup *curr-trace-ah
  clear-trace curr-trace
  var curr-value-ah/edi: (addr handle cell) <- get curr-global, value
  var definitions-created-storage: (stream int 0x10)
  var definitions-created/ecx: (addr stream int) <- address definitions-created-storage
  read-and-evaluate-and-save-gap-buffer-to-globals curr-input-ah, curr-value-ah, self, definitions-created, curr-trace, 0/no-screen, 0/no-keyboard
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
    var arr-ah/eax: (addr handle array int) <- get self, render-list
    var arr/eax: (addr array int) <- lookup *arr-ah
    slide-down arr, 0/start 0x1e/penultimate, 1/target
    var dest/eax: (addr int) <- index arr, 0
    copy-to *dest, curr-index
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

fn bump-global _globals: (addr global-table), global-id: int {
  var globals/esi: (addr global-table) <- copy _globals
  var render-list-ah/eax: (addr handle array int) <- get globals, render-list
  var render-list/eax: (addr array int) <- lookup *render-list-ah
  var idx/ecx: int <- find-slide-down-slot-in-array render-list, global-id
  {
    compare idx, 0
    break-if-!=
    return
  }
  slide-down render-list, 0/start idx, 1/target
  var dest/eax: (addr int) <- index render-list, 0
  var val/ecx: int <- copy global-id
  copy-to *dest, val
}

fn cursor-global _globals: (addr global-table) -> _/ecx: int {
  var globals/esi: (addr global-table) <- copy _globals
  var render-list-ah/eax: (addr handle array int) <- get globals, render-list
  var render-list/eax: (addr array int) <- lookup *render-list-ah
  var dest/eax: (addr int) <- index render-list, 0
  return *dest
}

fn lookup-symbol-in-globals _sym: (addr cell), out: (addr handle cell), _globals: (addr global-table), trace: (addr trace), inner-screen-var: (addr handle cell), inner-keyboard-var: (addr handle cell) {
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
  # if sym is "screen" and inner-screen-var exists, return it
  {
    var sym-is-screen?/eax: boolean <- stream-data-equal? sym-name, "screen"
    compare sym-is-screen?, 0/false
    break-if-=
    compare inner-screen-var, 0
    break-if-=
    copy-object inner-screen-var, out
    return
  }
  # if sym is "keyboard" and inner-keyboard-var exists, return it
  {
    var sym-is-keyboard?/eax: boolean <- stream-data-equal? sym-name, "keyboard"
    compare sym-is-keyboard?, 0/false
    break-if-=
    compare inner-keyboard-var, 0
    break-if-=
    copy-object inner-keyboard-var, out
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

# load all bindings in a single lexical scope, aka gap buffer of the environment, aka file of the file system
fn load-lexical-scope in-ah: (addr handle gap-buffer), _globals: (addr global-table) {
  var globals/esi: (addr global-table) <- copy _globals
  var definitions-created-storage: (stream int 0x10)
  var definitions-created/ebx: (addr stream int) <- address definitions-created-storage
  var trace-h: (handle trace)
  var trace-ah/edx: (addr handle trace) <- address trace-h
  allocate trace-ah
  var trace/eax: (addr trace) <- lookup *trace-ah
  initialize-trace trace, 1/only-errors, 0x10/capacity, 0/visible
  var dummy-result-h: (handle cell)
  var dummy-result-ah/ecx: (addr handle cell) <- address dummy-result-h
  read-and-evaluate-and-save-gap-buffer-to-globals in-ah, dummy-result-ah, globals, definitions-created, trace, 0/no-inner-screen-var, 0/no-inner-keyboard-var
  #
  # save trace to all needed globals as well
  rewind-stream definitions-created
  var globals-data-ah/eax: (addr handle array global) <- get globals, data
  var _globals-data/eax: (addr array global) <- lookup *globals-data-ah
  var globals-data/edi: (addr array global) <- copy _globals-data
  {
    var no-definitions?/eax: boolean <- stream-empty? definitions-created
    compare no-definitions?, 0/false
    break-if-!=
    var curr-index: int
    var curr-index-a/eax: (addr int) <- address curr-index
    read-from-stream definitions-created, curr-index-a
    var curr-offset/eax: (offset global) <- compute-offset globals-data, curr-index
    var curr-global/ecx: (addr global) <- index globals-data, curr-offset
    var curr-trace-ah/eax: (addr handle trace) <- get curr-global, trace
    copy-object trace-ah, curr-trace-ah
    loop
  }
}

fn render-image? _self: (addr global), cursor-in-definition?: boolean -> _/eax: boolean {
  {
    compare cursor-in-definition?, 0/false
    break-if-=
    # if the cursor is in this definition we need to be able to edit raw data
    return 0/false
  }
  var self/esi: (addr global) <- copy _self
  var value-ah/eax: (addr handle cell) <- get self, value
  var value/eax: (addr cell) <- lookup *value-ah
  compare value, 0
  {
    break-if-!=
    # unparsed buffers can't be rendered; either they're uninitialized or they have errors
    return 0/false
  }
  {
    var pair?/eax: boolean <- pair? value
    compare pair?, 0/false
    break-if-!=
    # not a pair? not an image
    return 0/false
  }
  var first-ah/eax: (addr handle cell) <- get value, left
  var first/eax: (addr cell) <- lookup *first-ah
  var litimg?/eax: boolean <- litimg? first
  return litimg?
}

fn render-image-definition screen: (addr screen), _self: (addr global), x: int, _y: int -> _/ecx: int {
  var self/esi: (addr global) <- copy _self
  var y/ecx: int <- copy _y
  set-cursor-position 0/screen, 0x20 0x20
  draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, y, 4/fg 0/bg
  {
    var name-ah/eax: (addr handle array byte) <- get self, name
    var _name/eax: (addr array byte) <- lookup *name-ah
    var name/edx: (addr array byte) <- copy _name
    var x/eax: int <- draw-text-rightward-over-full-screen screen, "define ", x y, 7/fg=definition, 0xc5/bg=blue-bg
    x <- draw-text-rightward-over-full-screen screen, name, x y, 7/fg=definition, 0xc5/bg=blue-bg
  }
  y <- increment  # skip definition line
  # y is now in pixels
  y <- shift-left 4/log2fontheight
  add-to x, 4
  shift-left x, 3/log2fontwidth
  var value-ah/eax: (addr handle cell) <- get self, value
  var value/eax: (addr cell) <- lookup *value-ah
  var rest-ah/eax: (addr handle cell) <- get value, right
  var rest/eax: (addr cell) <- lookup *rest-ah
  var second-ah/eax: (addr handle cell) <- get rest, left
  var second/eax: (addr cell) <- lookup *second-ah
  var img-data-ah/eax: (addr handle stream byte) <- get second, text-data
  var img-data/eax: (addr stream byte) <- lookup *img-data-ah
  var img-h: (handle cell)
  var img-cell-ah/edx: (addr handle cell) <- address img-h
  new-image img-cell-ah, img-data
  var img-cell/eax: (addr cell) <- lookup *img-cell-ah
  var img-ah/eax: (addr handle image) <- get img-cell, image-data
  var img/eax: (addr image) <- lookup *img-ah
  var height/ebx: int <- scale-image-height img, 0x80/width
  render-image screen, img, x y, 0x80/width height
  y <- add height
  # switch y back to characters
  y <- scale-down-and-round-up y, 0x10/font-height
  return y
}
