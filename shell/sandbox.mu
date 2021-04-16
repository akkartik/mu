type sandbox {
  data: (handle gap-buffer)
  value: (handle stream byte)
  screen-var: (handle cell)
  keyboard-var: (handle cell)
  trace: (handle trace)
  cursor-in-data?: boolean
  cursor-in-keyboard?: boolean
  cursor-in-trace?: boolean
}

fn initialize-sandbox _self: (addr sandbox), screen-and-keyboard?: boolean {
  var self/esi: (addr sandbox) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, data
  allocate data-ah
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  initialize-gap-buffer data, 0x1000/4KB
  #
  var value-ah/eax: (addr handle stream byte) <- get self, value
  populate-stream value-ah, 0x1000/4KB
  #
  {
    compare screen-and-keyboard?, 0/false
    break-if-=
    var screen-ah/eax: (addr handle cell) <- get self, screen-var
    new-screen screen-ah, 5/width, 4/height
    var keyboard-ah/eax: (addr handle cell) <- get self, keyboard-var
    new-keyboard keyboard-ah, 0x10/keyboard-capacity
  }
  #
  var trace-ah/eax: (addr handle trace) <- get self, trace
  allocate trace-ah
  var trace/eax: (addr trace) <- lookup *trace-ah
  initialize-trace trace, 0x1000/lines, 0x80/visible-lines
  var cursor-in-data?/eax: (addr boolean) <- get self, cursor-in-data?
  copy-to *cursor-in-data?, 1/true
}

## some helpers for tests

fn initialize-sandbox-with _self: (addr sandbox), s: (addr array byte) {
  var self/esi: (addr sandbox) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, data
  allocate data-ah
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  initialize-gap-buffer-with data, s
}

fn allocate-sandbox-with _out: (addr handle sandbox), s: (addr array byte) {
  var out/eax: (addr handle sandbox) <- copy _out
  allocate out
  var out-addr/eax: (addr sandbox) <- lookup *out
  initialize-sandbox-with out-addr, s
}

fn write-sandbox out: (addr stream byte), _self: (addr sandbox) {
  var self/eax: (addr sandbox) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  {
    var len/eax: int <- gap-buffer-length data
    compare len, 0
    break-if-!=
    return
  }
  write out, "  (sandbox . "
  append-gap-buffer data, out
  write out, ")\n"
}

##

fn render-sandbox screen: (addr screen), _self: (addr sandbox), xmin: int, ymin: int, xmax: int, ymax: int, globals: (addr global-table) {
  clear-rect screen, xmin, ymin, xmax, ymax, 0/bg=black
  var self/esi: (addr sandbox) <- copy _self
  # data
  var data-ah/eax: (addr handle gap-buffer) <- get self, data
  var _data/eax: (addr gap-buffer) <- lookup *data-ah
  var data/edx: (addr gap-buffer) <- copy _data
  var x/eax: int <- copy xmin
  var y/ecx: int <- copy ymin
  y <- maybe-render-empty-screen screen, self, xmin, y
  y <- maybe-render-keyboard screen, self, xmin, y
  var cursor-in-sandbox?/ebx: (addr boolean) <- get self, cursor-in-data?
  x, y <- render-gap-buffer-wrapping-right-then-down screen, data, x, y, xmax, ymax, *cursor-in-sandbox?
  y <- increment
  # trace
  var trace-ah/eax: (addr handle trace) <- get self, trace
  var _trace/eax: (addr trace) <- lookup *trace-ah
  var trace/edx: (addr trace) <- copy _trace
  var cursor-in-trace?/eax: (addr boolean) <- get self, cursor-in-trace?
  y <- render-trace screen, trace, xmin, y, xmax, ymax, *cursor-in-trace?
  # value
  $render-sandbox:value: {
    var value-ah/eax: (addr handle stream byte) <- get self, value
    var _value/eax: (addr stream byte) <- lookup *value-ah
    var value/esi: (addr stream byte) <- copy _value
    rewind-stream value
    var done?/eax: boolean <- stream-empty? value
    compare done?, 0/false
    break-if-!=
    var x/eax: int <- copy 0
    x, y <- draw-text-wrapping-right-then-down screen, "=> ", xmin, y, xmax, ymax, xmin, y, 7/fg, 0/bg
    var x2/edx: int <- copy x
    var dummy/eax: int <- draw-stream-rightward screen, value, x2, xmax, y, 7/fg=grey, 0/bg
  }
  y <- add 2  # padding
  y <- maybe-render-screen screen, self, xmin, y
  # render menu
  var cursor-in-data?/eax: (addr boolean) <- get self, cursor-in-data?
  compare *cursor-in-data?, 0/false
  {
    break-if-=
    render-sandbox-menu screen, self
    return
  }
  var cursor-in-trace?/eax: (addr boolean) <- get self, cursor-in-trace?
  compare *cursor-in-trace?, 0/false
  {
    break-if-=
    render-trace-menu screen
    return
  }
  var cursor-in-keyboard?/eax: (addr boolean) <- get self, cursor-in-keyboard?
  compare *cursor-in-keyboard?, 0/false
  {
    break-if-=
    render-keyboard-menu screen
    return
  }
}

fn maybe-render-empty-screen screen: (addr screen), _self: (addr sandbox), xmin: int, ymin: int -> _/ecx: int {
  var self/esi: (addr sandbox) <- copy _self
  var screen-obj-cell-ah/eax: (addr handle cell) <- get self, screen-var
  var screen-obj-cell/eax: (addr cell) <- lookup *screen-obj-cell-ah
  compare screen-obj-cell, 0
  {
    break-if-!=
    return ymin
  }
  var screen-obj-cell-type/ecx: (addr int) <- get screen-obj-cell, type
  compare *screen-obj-cell-type, 5/screen
  {
    break-if-=
    return ymin  # silently give up on rendering the screen
  }
  var y/ecx: int <- copy ymin
  var screen-obj-ah/eax: (addr handle screen) <- get screen-obj-cell, screen-data
  var _screen-obj/eax: (addr screen) <- lookup *screen-obj-ah
  var screen-obj/edx: (addr screen) <- copy _screen-obj
  var x/eax: int <- draw-text-rightward screen, "screen:   ", xmin, 0x99/xmax, y, 7/fg, 0/bg
  y <- render-empty-screen screen, screen-obj, x, y
  return y
}

fn maybe-render-screen screen: (addr screen), _self: (addr sandbox), xmin: int, ymin: int -> _/ecx: int {
  var self/esi: (addr sandbox) <- copy _self
  var screen-obj-cell-ah/eax: (addr handle cell) <- get self, screen-var
  var screen-obj-cell/eax: (addr cell) <- lookup *screen-obj-cell-ah
  compare screen-obj-cell, 0
  {
    break-if-!=
    return ymin
  }
  var screen-obj-cell-type/ecx: (addr int) <- get screen-obj-cell, type
  compare *screen-obj-cell-type, 5/screen
  {
    break-if-=
    return ymin  # silently give up on rendering the screen
  }
  var screen-obj-ah/eax: (addr handle screen) <- get screen-obj-cell, screen-data
  var _screen-obj/eax: (addr screen) <- lookup *screen-obj-ah
  var screen-obj/edx: (addr screen) <- copy _screen-obj
  {
    var screen-empty?/eax: boolean <- fake-screen-empty? screen-obj
    compare screen-empty?, 0/false
    break-if-=
    return ymin
  }
  var x/eax: int <- draw-text-rightward screen, "screen:   ", xmin, 0x99/xmax, ymin, 7/fg, 0/bg
  var y/ecx: int <- copy ymin
  y <- render-screen screen, screen-obj, x, y
  return y
}

fn render-empty-screen screen: (addr screen), _target-screen: (addr screen), xmin: int, ymin: int -> _/ecx: int {
  var target-screen/esi: (addr screen) <- copy _target-screen
  var screen-y/edi: int <- copy ymin
  # top border
  {
    set-cursor-position screen, xmin, screen-y
    move-cursor-right screen
    var width/edx: (addr int) <- get target-screen, width
    var x/ebx: int <- copy 0
    {
      compare x, *width
      break-if->=
      draw-code-point-at-cursor screen, 0x2d/horizontal-bar, 0x18/fg, 0/bg
      move-cursor-right screen
      x <- increment
      loop
    }
    screen-y <- increment
  }
  # screen
  var height/edx: (addr int) <- get target-screen, height
  var y/ecx: int <- copy 0
  {
    compare y, *height
    break-if->=
    set-cursor-position screen, xmin, screen-y
    draw-code-point-at-cursor screen, 0x7c/vertical-bar, 0x18/fg, 0/bg
    move-cursor-right screen
    var width/edx: (addr int) <- get target-screen, width
    var x/ebx: int <- copy 0
    {
      compare x, *width
      break-if->=
      draw-code-point-at-cursor screen, 0x20/space, 0x18/fg, 0/bg
      move-cursor-right screen
      x <- increment
      loop
    }
    draw-code-point-at-cursor screen, 0x7c/vertical-bar, 0x18/fg, 0/bg
    y <- increment
    screen-y <- increment
    loop
  }
  # bottom border
  {
    set-cursor-position screen, xmin, screen-y
    move-cursor-right screen
    var width/edx: (addr int) <- get target-screen, width
    var x/ebx: int <- copy 0
    {
      compare x, *width
      break-if->=
      draw-code-point-at-cursor screen, 0x2d/horizontal-bar, 0x18/fg, 0/bg
      move-cursor-right screen
      x <- increment
      loop
    }
    screen-y <- increment
  }
  return screen-y
}

fn render-screen screen: (addr screen), _target-screen: (addr screen), xmin: int, ymin: int -> _/ecx: int {
  var target-screen/esi: (addr screen) <- copy _target-screen
  var screen-y/edi: int <- copy ymin
  # top border
  {
    set-cursor-position screen, xmin, screen-y
    move-cursor-right screen
    var width/edx: (addr int) <- get target-screen, width
    var x/ebx: int <- copy 0
    {
      compare x, *width
      break-if->=
      draw-code-point-at-cursor screen, 0x2d/horizontal-bar, 0x18/fg, 0/bg
      move-cursor-right screen
      x <- increment
      loop
    }
    screen-y <- increment
  }
  # text data
  {
    var height/edx: (addr int) <- get target-screen, height
    var y/ecx: int <- copy 0
    {
      compare y, *height
      break-if->=
      set-cursor-position screen, xmin, screen-y
      draw-code-point-at-cursor screen, 0x7c/vertical-bar, 0x18/fg, 0/bg
      move-cursor-right screen
      var width/edx: (addr int) <- get target-screen, width
      var x/ebx: int <- copy 0
      {
        compare x, *width
        break-if->=
        print-screen-cell-of-fake-screen screen, target-screen, x, y
        move-cursor-right screen
        x <- increment
        loop
      }
      draw-code-point-at-cursor screen, 0x7c/vertical-bar, 0x18/fg, 0/bg
      y <- increment
      screen-y <- increment
      loop
    }
  }
  # pixel data
  {
    var left/ebx: int <- copy xmin
    left <- add 1/margin-left
    left <- shift-left 3/log-font-width
    var top/edx: int <- copy ymin
    top <- add 1/margin-top
    top <- shift-left 4/log-font-height
    var pixels-ah/esi: (addr handle stream pixel) <- get target-screen, pixels
    var _pixels/eax: (addr stream pixel) <- lookup *pixels-ah
    var pixels/esi: (addr stream pixel) <- copy _pixels
    rewind-stream pixels
    {
      var done?/eax: boolean <- stream-empty? pixels
      compare done?, 0/false
      break-if-!=
      var curr-pixel: pixel
      var curr-pixel-addr/eax: (addr pixel) <- address curr-pixel
      read-from-stream pixels, curr-pixel-addr
      var curr-x/eax: (addr int) <- get curr-pixel, x
      var x/eax: int <- copy *curr-x
      x <- add left
      var curr-y/ecx: (addr int) <- get curr-pixel, y
      var y/ecx: int <- copy *curr-y
      y <- add top
      var curr-color/edx: (addr int) <- get curr-pixel, color
      pixel screen, x, y, *curr-color
      loop
    }
  }
  # bottom border
  {
    set-cursor-position screen, xmin, screen-y
    move-cursor-right screen
    var width/edx: (addr int) <- get target-screen, width
    var x/ebx: int <- copy 0
    {
      compare x, *width
      break-if->=
      draw-code-point-at-cursor screen, 0x2d/horizontal-bar, 0x18/fg, 0/bg
      move-cursor-right screen
      x <- increment
      loop
    }
    screen-y <- increment
  }
  return screen-y
}

fn has-keyboard? _self: (addr sandbox) -> _/eax: boolean {
  var self/esi: (addr sandbox) <- copy _self
  var keyboard-obj-cell-ah/eax: (addr handle cell) <- get self, keyboard-var
  var keyboard-obj-cell/eax: (addr cell) <- lookup *keyboard-obj-cell-ah
  compare keyboard-obj-cell, 0
  {
    break-if-!=
    return 0/false
  }
  var keyboard-obj-cell-type/ecx: (addr int) <- get keyboard-obj-cell, type
  compare *keyboard-obj-cell-type, 6/keyboard
  {
    break-if-=
    return 0/false
  }
  var keyboard-obj-ah/eax: (addr handle gap-buffer) <- get keyboard-obj-cell, keyboard-data
  var _keyboard-obj/eax: (addr gap-buffer) <- lookup *keyboard-obj-ah
  var keyboard-obj/edx: (addr gap-buffer) <- copy _keyboard-obj
  compare keyboard-obj, 0
  {
    break-if-!=
    return 0/false
  }
  return 1/true
}

fn maybe-render-keyboard screen: (addr screen), _self: (addr sandbox), xmin: int, ymin: int -> _/ecx: int {
  var self/esi: (addr sandbox) <- copy _self
  var keyboard-obj-cell-ah/eax: (addr handle cell) <- get self, keyboard-var
  var keyboard-obj-cell/eax: (addr cell) <- lookup *keyboard-obj-cell-ah
  compare keyboard-obj-cell, 0
  {
    break-if-!=
    return ymin
  }
  var keyboard-obj-cell-type/ecx: (addr int) <- get keyboard-obj-cell, type
  compare *keyboard-obj-cell-type, 6/keyboard
  {
    break-if-=
    return ymin  # silently give up on rendering the keyboard
  }
  var keyboard-obj-ah/eax: (addr handle gap-buffer) <- get keyboard-obj-cell, keyboard-data
  var _keyboard-obj/eax: (addr gap-buffer) <- lookup *keyboard-obj-ah
  var keyboard-obj/edx: (addr gap-buffer) <- copy _keyboard-obj
  var x/eax: int <- draw-text-rightward screen, "keyboard: ", xmin, 0x99/xmax, ymin, 7/fg, 0/bg
  var y/ecx: int <- copy ymin
  var cursor-in-keyboard?/esi: (addr boolean) <- get self, cursor-in-keyboard?
  y <- render-keyboard screen, keyboard-obj, x, y, *cursor-in-keyboard?
  y <- increment  # padding
  return y
}

# draw an evocative shape
fn render-keyboard screen: (addr screen), _keyboard: (addr gap-buffer), xmin: int, ymin: int, render-cursor?: boolean -> _/ecx: int {
  var keyboard/esi: (addr gap-buffer) <- copy _keyboard
  var width/edx: int <- copy 0x10/keyboard-capacity
  var y/edi: int <- copy ymin
  # top border
  {
    set-cursor-position screen, xmin, y
    move-cursor-right screen
    var x/ebx: int <- copy 0
    {
      compare x, width
      break-if->=
      draw-code-point-at-cursor screen, 0x2d/horizontal-bar, 0x18/fg, 0/bg
      move-cursor-right screen
      x <- increment
      loop
    }
    y <- increment
  }
  # keyboard
  var x/eax: int <- copy xmin
  draw-code-point screen, 0x7c/vertical-bar, x, y, 0x18/fg, 0/bg
  x <- increment
  x <- render-gap-buffer screen, keyboard, x, y, render-cursor?
  x <- copy xmin
  x <- add 1  # for left bar
  x <- add 0x10/keyboard-capacity
  draw-code-point screen, 0x7c/vertical-bar, x, y, 0x18/fg, 0/bg
  y <- increment
  # bottom border
  {
    set-cursor-position screen, xmin, y
    move-cursor-right screen
    var x/ebx: int <- copy 0
    {
      compare x, width
      break-if->=
      draw-code-point-at-cursor screen, 0x2d/horizontal-bar, 0x18/fg, 0/bg
      move-cursor-right screen
      x <- increment
      loop
    }
    y <- increment
  }
  return y
}

fn print-screen-cell-of-fake-screen screen: (addr screen), _target: (addr screen), x: int, y: int {
  var target/ecx: (addr screen) <- copy _target
  var data-ah/eax: (addr handle array screen-cell) <- get target, data
  var data/eax: (addr array screen-cell) <- lookup *data-ah
  var index/ecx: int <- screen-cell-index target, x, y
  var offset/ecx: (offset screen-cell) <- compute-offset data, index
  var src-cell/esi: (addr screen-cell) <- index data, offset
  var src-grapheme/eax: (addr grapheme) <- get src-cell, data
  var src-color/ecx: (addr int) <- get src-cell, color
  var src-background-color/edx: (addr int) <- get src-cell, background-color
  draw-grapheme-at-cursor screen, *src-grapheme, *src-color, *src-background-color
}

fn render-sandbox-menu screen: (addr screen), _self: (addr sandbox) {
  var _width/eax: int <- copy 0
  var height/ecx: int <- copy 0
  _width, height <- screen-size screen
  var width/edx: int <- copy _width
  var y/ecx: int <- copy height
  y <- decrement
  var height/ebx: int <- copy y
  height <- increment
  clear-rect screen, 0/x, y, width, height, 0/bg=black
  set-cursor-position screen, 0/x, y
  draw-text-rightward-from-cursor screen, " ctrl-s ", width, 0/fg, 7/bg=grey
  draw-text-rightward-from-cursor screen, " run sandbox  ", width, 7/fg, 0/bg
  $render-sandbox-menu:render-tab: {
    var self/eax: (addr sandbox) <- copy _self
    var has-trace?/eax: boolean <- has-trace? self
    compare has-trace?, 0/false
    {
      break-if-=
      draw-text-rightward-from-cursor screen, " tab ", width, 0/fg, 9/bg=blue
      draw-text-rightward-from-cursor screen, " move to trace  ", width, 7/fg, 0/bg
      break $render-sandbox-menu:render-tab
    }
    draw-text-rightward-from-cursor screen, " tab ", width, 0/fg, 0x18/bg=keyboard
    draw-text-rightward-from-cursor screen, " move to keyboard  ", width, 7/fg, 0/bg
  }
  draw-text-rightward-from-cursor screen, " ctrl-a ", width, 0/fg, 7/bg=grey
  draw-text-rightward-from-cursor screen, " <<  ", width, 7/fg, 0/bg
  draw-text-rightward-from-cursor screen, " ctrl-b ", width, 0/fg, 7/bg=grey
  draw-text-rightward-from-cursor screen, " <word  ", width, 7/fg, 0/bg
  draw-text-rightward-from-cursor screen, " ctrl-f ", width, 0/fg, 7/bg=grey
  draw-text-rightward-from-cursor screen, " word>  ", width, 7/fg, 0/bg
  draw-text-rightward-from-cursor screen, " ctrl-e ", width, 0/fg, 7/bg=grey
  draw-text-rightward-from-cursor screen, " >>  ", width, 7/fg, 0/bg
}

fn render-keyboard-menu screen: (addr screen) {
  var width/eax: int <- copy 0
  var height/ecx: int <- copy 0
  width, height <- screen-size screen
  var y/ecx: int <- copy height
  y <- decrement
  var height/edx: int <- copy y
  height <- increment
  clear-rect screen, 0/x, y, width, height, 0/bg=black
  set-cursor-position screen, 0/x, y
  draw-text-rightward-from-cursor screen, " ctrl-s ", width, 0/fg, 7/bg=grey
  draw-text-rightward-from-cursor screen, " run sandbox  ", width, 7/fg, 0/bg
  draw-text-rightward-from-cursor screen, " tab ", width, 0/fg, 3/bg=cyan
  draw-text-rightward-from-cursor screen, " move to sandbox  ", width, 7/fg, 0/bg
}

fn edit-sandbox _self: (addr sandbox), key: byte, globals: (addr global-table), real-screen: (addr screen), real-keyboard: (addr keyboard), data-disk: (addr disk) {
  var self/esi: (addr sandbox) <- copy _self
  var g/edx: grapheme <- copy key
  # ctrl-r
  {
    compare g, 0x12/ctrl-r
    break-if-!=
    # run function outside sandbox
    # required: fn (addr screen), (addr keyboard)
    # Mu will pass in the real screen and keyboard.
    return
  }
  # ctrl-s
  {
    compare g, 0x13/ctrl-s
    break-if-!=
    # minor gotcha here: any bindings created later in this iteration won't be
    # persisted.
    # That's ok since we don't clear the gap buffer. If we start doing so
    # we'll need to revisit where serialization happens.
    store-state data-disk, self, globals
    # run sandbox
    var data-ah/eax: (addr handle gap-buffer) <- get self, data
    var _data/eax: (addr gap-buffer) <- lookup *data-ah
    var data/ecx: (addr gap-buffer) <- copy _data
    var value-ah/eax: (addr handle stream byte) <- get self, value
    var _value/eax: (addr stream byte) <- lookup *value-ah
    var value/edx: (addr stream byte) <- copy _value
    var trace-ah/eax: (addr handle trace) <- get self, trace
    var _trace/eax: (addr trace) <- lookup *trace-ah
    var trace/ebx: (addr trace) <- copy _trace
    clear-trace trace
    var screen-cell/eax: (addr handle cell) <- get self, screen-var
    clear-screen-cell screen-cell
    var keyboard-cell/esi: (addr handle cell) <- get self, keyboard-var
    rewind-keyboard-cell keyboard-cell  # don't clear keys from before
    run data, value, globals, trace, screen-cell, keyboard-cell
    return
  }
  # tab
  {
    compare g, 9/tab
    break-if-!=
    # if cursor in data, switch to trace or fall through to keyboard
    {
      var cursor-in-data?/eax: (addr boolean) <- get self, cursor-in-data?
      compare *cursor-in-data?, 0/false
      break-if-=
      var has-trace?/eax: boolean <- has-trace? self
      compare has-trace?, 0/false
      {
        break-if-=
        var cursor-in-data?/eax: (addr boolean) <- get self, cursor-in-data?
        copy-to *cursor-in-data?, 0/false
        var cursor-in-trace?/eax: (addr boolean) <- get self, cursor-in-trace?
        copy-to *cursor-in-trace?, 1/false
        return
      }
      var has-keyboard?/eax: boolean <- has-keyboard? self
      compare has-keyboard?, 0/false
      {
        break-if-=
        var cursor-in-data?/eax: (addr boolean) <- get self, cursor-in-data?
        copy-to *cursor-in-data?, 0/false
        var cursor-in-keyboard?/eax: (addr boolean) <- get self, cursor-in-keyboard?
        copy-to *cursor-in-keyboard?, 1/false
        return
      }
      return
    }
    # if cursor in trace, switch to keyboard or fall through to data
    {
      var cursor-in-trace?/eax: (addr boolean) <- get self, cursor-in-trace?
      compare *cursor-in-trace?, 0/false
      break-if-=
      copy-to *cursor-in-trace?, 0/false
      var cursor-target/ecx: (addr boolean) <- get self, cursor-in-keyboard?
      var has-keyboard?/eax: boolean <- has-keyboard? self
      compare has-keyboard?, 0/false
      {
        break-if-!=
        cursor-target <- get self, cursor-in-data?
      }
      copy-to *cursor-target, 1/true
      return
    }
    # otherwise if cursor in keyboard, switch to data
    {
      var cursor-in-keyboard?/eax: (addr boolean) <- get self, cursor-in-keyboard?
      compare *cursor-in-keyboard?, 0/false
      break-if-=
      copy-to *cursor-in-keyboard?, 0/false
      var cursor-in-data?/eax: (addr boolean) <- get self, cursor-in-data?
      copy-to *cursor-in-data?, 1/true
      return
    }
    return
  }
  # if cursor in data, send key to data
  {
    var cursor-in-data?/eax: (addr boolean) <- get self, cursor-in-data?
    compare *cursor-in-data?, 0/false
    break-if-=
    var data-ah/eax: (addr handle gap-buffer) <- get self, data
    var data/eax: (addr gap-buffer) <- lookup *data-ah
    edit-gap-buffer data, g
    return
  }
  # if cursor in keyboard, send key to keyboard
  {
    var cursor-in-keyboard?/eax: (addr boolean) <- get self, cursor-in-keyboard?
    compare *cursor-in-keyboard?, 0/false
    break-if-=
    var keyboard-cell-ah/eax: (addr handle cell) <- get self, keyboard-var
    var keyboard-cell/eax: (addr cell) <- lookup *keyboard-cell-ah
    compare keyboard-cell, 0
    {
      break-if-!=
      return
    }
    var keyboard-cell-type/ecx: (addr int) <- get keyboard-cell, type
    compare *keyboard-cell-type, 6/keyboard
    {
      break-if-=
      return
    }
    var keyboard-ah/eax: (addr handle gap-buffer) <- get keyboard-cell, keyboard-data
    var keyboard/eax: (addr gap-buffer) <- lookup *keyboard-ah
    edit-gap-buffer keyboard, g
    return
  }
  # if cursor in trace, send key to trace
  {
    var cursor-in-trace?/eax: (addr boolean) <- get self, cursor-in-trace?
    compare *cursor-in-trace?, 0/false
    break-if-=
    var trace-ah/eax: (addr handle trace) <- get self, trace
    var trace/eax: (addr trace) <- lookup *trace-ah
    edit-trace trace, g
    return
  }
}

fn run in: (addr gap-buffer), out: (addr stream byte), globals: (addr global-table), trace: (addr trace), screen-cell: (addr handle cell), keyboard-cell: (addr handle cell) {
  var read-result-storage: (handle cell)
  var read-result/esi: (addr handle cell) <- address read-result-storage
  read-cell in, read-result, trace
  var error?/eax: boolean <- has-errors? trace
  {
    compare error?, 0/false
    break-if-=
    return
  }
  var nil-storage: (handle cell)
  var nil-ah/eax: (addr handle cell) <- address nil-storage
  allocate-pair nil-ah
  var eval-result-storage: (handle cell)
  var eval-result/edi: (addr handle cell) <- address eval-result-storage
  evaluate read-result, eval-result, *nil-ah, globals, trace, screen-cell, keyboard-cell
  var error?/eax: boolean <- has-errors? trace
  {
    compare error?, 0/false
    break-if-=
    return
  }
  clear-stream out
  print-cell eval-result, out, trace
  mark-lines-dirty trace
}

fn test-run-integer {
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox sandbox, 0/no-screen-or-keyboard
  # type "1"
  edit-sandbox sandbox, 0x31/1, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  # eval
  edit-sandbox sandbox, 0x13/ctrl-s, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width, 0x10/height
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 0/no-globals
  check-screen-row screen, 0/y, "1    ", "F - test-run-integer/0"
  check-screen-row screen, 1/y, "...  ", "F - test-run-integer/1"
  check-screen-row screen, 2/y, "=> 1 ", "F - test-run-integer/2"
}

fn test-run-with-spaces {
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox sandbox, 0/no-screen-or-keyboard
  # type input with whitespace before and after
  edit-sandbox sandbox, 0x20/space, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x31/1, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x20/space, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0xa/newline, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  # eval
  edit-sandbox sandbox, 0x13/ctrl-s, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width, 0x10/height
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 0/no-globals
  check-screen-row screen, 0/y, " 1   ", "F - test-run-with-spaces/0"
  check-screen-row screen, 1/y, "     ", "F - test-run-with-spaces/1"
  check-screen-row screen, 2/y, "...  ", "F - test-run-with-spaces/2"
  check-screen-row screen, 3/y, "=> 1 ", "F - test-run-with-spaces/3"
}

fn test-run-quote {
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox sandbox, 0/no-screen-or-keyboard
  # type "'a"
  edit-sandbox sandbox, 0x27/quote, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x61/a, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  # eval
  edit-sandbox sandbox, 0x13/ctrl-s, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width, 0x10/height
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 0/no-globals
  check-screen-row screen, 0/y, "'a   ", "F - test-run-quote/0"
  check-screen-row screen, 1/y, "...  ", "F - test-run-quote/1"
  check-screen-row screen, 2/y, "=> a ", "F - test-run-quote/2"
}

fn test-run-dotted-list {
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox sandbox, 0/no-screen-or-keyboard
  # type "'(a . b)"
  edit-sandbox sandbox, 0x27/quote, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x28/open-paren, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x61/a, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x20/space, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x2e/dot, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x20/space, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x62/b, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x29/close-paren, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  # eval
  edit-sandbox sandbox, 0x13/ctrl-s, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width, 0x10/height
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 0/no-globals
  check-screen-row screen, 0/y, "'(a . b)   ", "F - test-run-dotted-list/0"
  check-screen-row screen, 1/y, "...        ", "F - test-run-dotted-list/1"
  check-screen-row screen, 2/y, "=> (a . b) ", "F - test-run-dotted-list/2"
}

fn test-run-dot-and-list {
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox sandbox, 0/no-screen-or-keyboard
  # type "'(a . (b))"
  edit-sandbox sandbox, 0x27/quote, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x28/open-paren, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x61/a, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x20/space, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x2e/dot, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x20/space, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x28/open-paren, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x62/b, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x29/close-paren, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x29/close-paren, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  # eval
  edit-sandbox sandbox, 0x13/ctrl-s, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width, 0x10/height
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 0/no-globals
  check-screen-row screen, 0/y, "'(a . (b)) ", "F - test-run-dot-and-list/0"
  check-screen-row screen, 1/y, "...        ", "F - test-run-dot-and-list/1"
  check-screen-row screen, 2/y, "=> (a b)   ", "F - test-run-dot-and-list/2"
}

fn test-run-final-dot {
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox sandbox, 0/no-screen-or-keyboard
  # type "'(a .)"
  edit-sandbox sandbox, 0x27/quote, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x28/open-paren, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x61/a, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x20/space, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x2e/dot, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x29/close-paren, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  # eval
  edit-sandbox sandbox, 0x13/ctrl-s, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width, 0x10/height
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 0/no-globals
  check-screen-row screen, 0/y, "'(a .)               ", "F - test-run-final-dot/0"
  check-screen-row screen, 1/y, "...                  ", "F - test-run-final-dot/1"
  check-screen-row screen, 2/y, "'. )' makes no sense ", "F - test-run-final-dot/2"
  # further errors may occur
}

fn test-run-double-dot {
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox sandbox, 0/no-screen-or-keyboard
  # type "'(a . .)"
  edit-sandbox sandbox, 0x27/quote, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x28/open-paren, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x61/a, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x20/space, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x2e/dot, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x20/space, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x2e/dot, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x29/close-paren, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  # eval
  edit-sandbox sandbox, 0x13/ctrl-s, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width, 0x10/height
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 0/no-globals
  check-screen-row screen, 0/y, "'(a . .)             ", "F - test-run-double-dot/0"
  check-screen-row screen, 1/y, "...                  ", "F - test-run-double-dot/1"
  check-screen-row screen, 2/y, "'. .' makes no sense ", "F - test-run-double-dot/2"
  # further errors may occur
}

fn test-run-multiple-expressions-after-dot {
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox sandbox, 0/no-screen-or-keyboard
  # type "'(a . b c)"
  edit-sandbox sandbox, 0x27/quote, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x28/open-paren, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x61/a, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x20/space, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x2e/dot, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x20/space, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x62/b, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x20/space, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x63/c, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x29/close-paren, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  # eval
  edit-sandbox sandbox, 0x13/ctrl-s, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width, 0x10/height
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 0/no-globals
  check-screen-row screen, 0/y, "'(a . b c)                                           ", "F - test-run-multiple-expressions-after-dot/0"
  check-screen-row screen, 1/y, "...                                                  ", "F - test-run-multiple-expressions-after-dot/1"
  check-screen-row screen, 2/y, "cannot have multiple expressions between '.' and ')' ", "F - test-run-multiple-expressions-after-dot/2"
  # further errors may occur
}

fn test-run-error-invalid-integer {
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox sandbox, 0/no-screen-or-keyboard
  # type "1a"
  edit-sandbox sandbox, 0x31/1, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x61/a, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  # eval
  edit-sandbox sandbox, 0x13/ctrl-s, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width, 0x10/height
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 0/no-globals
  check-screen-row screen, 0/y, "1a             ", "F - test-run-error-invalid-integer/0"
  check-screen-row screen, 1/y, "...            ", "F - test-run-error-invalid-integer/0"
  check-screen-row screen, 2/y, "invalid number ", "F - test-run-error-invalid-integer/2"
}

fn test-run-move-cursor-into-trace {
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox sandbox, 0/no-screen-or-keyboard
  # type "12"
  edit-sandbox sandbox, 0x31/1, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  edit-sandbox sandbox, 0x32/2, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  # eval
  edit-sandbox sandbox, 0x13/ctrl-s, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width, 0x10/height
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 0/no-globals
  check-screen-row screen,                                  0/y, "12    ", "F - test-run-move-cursor-into-trace/pre-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "  |   ", "F - test-run-move-cursor-into-trace/pre-0/cursor"
  check-screen-row screen,                                  1/y, "...   ", "F - test-run-move-cursor-into-trace/pre-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "      ", "F - test-run-move-cursor-into-trace/pre-1/cursor"
  check-screen-row screen,                                  2/y, "=> 12 ", "F - test-run-move-cursor-into-trace/pre-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "      ", "F - test-run-move-cursor-into-trace/pre-2/cursor"
  # move cursor into trace
  edit-sandbox sandbox, 9/tab, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 0/no-globals
  check-screen-row screen,                                  0/y, "12    ", "F - test-run-move-cursor-into-trace/trace-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "      ", "F - test-run-move-cursor-into-trace/trace-0/cursor"
  check-screen-row screen,                                  1/y, "...   ", "F - test-run-move-cursor-into-trace/trace-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "|||   ", "F - test-run-move-cursor-into-trace/trace-1/cursor"
  check-screen-row screen,                                  2/y, "=> 12 ", "F - test-run-move-cursor-into-trace/trace-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "      ", "F - test-run-move-cursor-into-trace/trace-2/cursor"
  # move cursor into input
  edit-sandbox sandbox, 9/tab, 0/no-globals, 0/no-screen, 0/no-keyboard, 0/no-disk
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 0/no-globals
  check-screen-row screen,                                  0/y, "12    ", "F - test-run-move-cursor-into-trace/input-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 0/y, "  |   ", "F - test-run-move-cursor-into-trace/input-0/cursor"
  check-screen-row screen,                                  1/y, "...   ", "F - test-run-move-cursor-into-trace/input-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "      ", "F - test-run-move-cursor-into-trace/input-1/cursor"
  check-screen-row screen,                                  2/y, "=> 12 ", "F - test-run-move-cursor-into-trace/input-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "      ", "F - test-run-move-cursor-into-trace/input-2/cursor"
}

fn has-trace? _self: (addr sandbox) -> _/eax: boolean {
  var self/esi: (addr sandbox) <- copy _self
  var trace-ah/eax: (addr handle trace) <- get self, trace
  var _trace/eax: (addr trace) <- lookup *trace-ah
  var trace/edx: (addr trace) <- copy _trace
  compare trace, 0
  {
    break-if-!=
    return 0/false
  }
  var first-free/ebx: (addr int) <- get trace, first-free
  compare *first-free, 0
  {
    break-if->
    return 0/false
  }
  return 1/true
}
