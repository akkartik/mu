type sandbox {
  data: (handle gap-buffer)
  value: (handle stream byte)
  trace: (handle trace)
  screen-var: (handle cell)
  keyboard-var: (handle cell)
  cursor-in-data?: boolean
  cursor-in-trace?: boolean
  cursor-in-keyboard?: boolean
}

fn initialize-sandbox _self: (addr sandbox), fake-screen-and-keyboard?: boolean {
  var self/esi: (addr sandbox) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, data
  allocate data-ah
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  initialize-gap-buffer data, 0x2000/default-gap-buffer-size=8KB
  #
  var value-ah/eax: (addr handle stream byte) <- get self, value
  populate-stream value-ah, 0x1000/4KB
  #
  {
    compare fake-screen-and-keyboard?, 0/false
    break-if-=
    var screen-ah/eax: (addr handle cell) <- get self, screen-var
    new-fake-screen screen-ah, 8/width, 3/height, 1/enable-pixel-graphics
    var keyboard-ah/eax: (addr handle cell) <- get self, keyboard-var
    new-fake-keyboard keyboard-ah, 0x10/keyboard-capacity
  }
  #
  var trace-ah/eax: (addr handle trace) <- get self, trace
  allocate trace-ah
  var trace/eax: (addr trace) <- lookup *trace-ah
  initialize-trace trace, 4/max-depth, 0x8000/lines, 0x80/visible
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
  var value-ah/eax: (addr handle stream byte) <- get self, value
  populate-stream value-ah, 0x1000/4KB
  var trace-ah/eax: (addr handle trace) <- get self, trace
  allocate trace-ah
  var trace/eax: (addr trace) <- lookup *trace-ah
  initialize-trace trace, 3/max-depth, 0x8000/lines, 0x80/visible
  var cursor-in-data?/eax: (addr boolean) <- get self, cursor-in-data?
  copy-to *cursor-in-data?, 1/true
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

fn render-sandbox screen: (addr screen), _self: (addr sandbox), xmin: int, ymin: int, xmax: int, ymax: int, show-cursor?: boolean {
  clear-rect screen, xmin, ymin, xmax, ymax, 0xc5/bg=blue-bg
  add-to xmin, 1/padding-left
  add-to ymin, 1/padding-top
  subtract-from xmax, 1/padding-right
  var self/esi: (addr sandbox) <- copy _self
  # data
  var data-ah/eax: (addr handle gap-buffer) <- get self, data
  var _data/eax: (addr gap-buffer) <- lookup *data-ah
  var data/edx: (addr gap-buffer) <- copy _data
  var x/eax: int <- copy xmin
  var y/ecx: int <- copy ymin
  y <- maybe-render-empty-screen screen, self, xmin, y
  y <- maybe-render-keyboard screen, self, xmin, y
  var cursor-in-editor?/ebx: boolean <- copy show-cursor?
  {
    compare cursor-in-editor?, 0/false
    break-if-=
    var cursor-in-data-a/eax: (addr boolean) <- get self, cursor-in-data?
    cursor-in-editor? <- copy *cursor-in-data-a
  }
  x, y <- render-gap-buffer-wrapping-right-then-down screen, data, x, y, xmax, ymax, cursor-in-editor?, 7/fg, 0xc5/bg=blue-bg
  y <- increment
  # trace
  var trace-ah/eax: (addr handle trace) <- get self, trace
  var _trace/eax: (addr trace) <- lookup *trace-ah
  var trace/edx: (addr trace) <- copy _trace
  var cursor-in-trace?/eax: (addr boolean) <- get self, cursor-in-trace?
  y <- render-trace screen, trace, xmin, y, xmax, ymax, *cursor-in-trace?
  # value
  $render-sandbox:value: {
    compare y, ymax
    break-if->=
    var value-ah/eax: (addr handle stream byte) <- get self, value
    var _value/eax: (addr stream byte) <- lookup *value-ah
    var value/esi: (addr stream byte) <- copy _value
    rewind-stream value
    var done?/eax: boolean <- stream-empty? value
    compare done?, 0/false
    break-if-!=
    var x/eax: int <- copy 0
    x, y <- draw-text-wrapping-right-then-down screen, "=> ", xmin, y, xmax, ymax, xmin, y, 7/fg, 0xc5/bg=blue-bg
    var x2/edx: int <- copy x
    var dummy/eax: int <- draw-stream-rightward screen, value, x2, xmax, y, 7/fg=grey, 0xc5/bg=blue-bg
  }
  y <- add 2  # padding
  y <- maybe-render-screen screen, self, xmin, y
}

fn render-sandbox-menu screen: (addr screen), _self: (addr sandbox) {
  var self/esi: (addr sandbox) <- copy _self
  var cursor-in-data?/eax: (addr boolean) <- get self, cursor-in-data?
  compare *cursor-in-data?, 0/false
  {
    break-if-=
    render-sandbox-edit-menu screen, self
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

fn clear-sandbox-output screen: (addr screen), _self: (addr sandbox), xmin: int, ymin: int, xmax: int, ymax: int {
  # render just enough of the sandbox to figure out what to erase
  var self/esi: (addr sandbox) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, data
  var _data/eax: (addr gap-buffer) <- lookup *data-ah
  var data/edx: (addr gap-buffer) <- copy _data
  var x/eax: int <- copy xmin
  var y/ecx: int <- copy ymin
  y <- maybe-render-empty-screen screen, self, xmin, y
  y <- maybe-render-keyboard screen, self, xmin, y
  var cursor-in-sandbox?/ebx: (addr boolean) <- get self, cursor-in-data?
  x, y <- render-gap-buffer-wrapping-right-then-down screen, data, x, y, xmax, ymax, *cursor-in-sandbox?, 3/fg, 0xc5/bg=blue-bg
  y <- increment
  clear-rect screen, xmin, y, xmax, ymax, 0xc5/bg=blue-bg
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
  var x/eax: int <- draw-text-rightward screen, "screen:   ", xmin, 0x99/xmax, y, 0x17/fg, 0xc5/bg=blue-bg
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
  var x/eax: int <- draw-text-rightward screen, "screen:   ", xmin, 0x99/xmax, ymin, 0x17/fg, 0xc5/bg=blue-bg
  var y/ecx: int <- copy ymin
  y <- render-screen screen, screen-obj, x, y
  return y
}

fn render-empty-screen screen: (addr screen), _target-screen: (addr screen), xmin: int, ymin: int -> _/ecx: int {
  var target-screen/esi: (addr screen) <- copy _target-screen
  var screen-y/edi: int <- copy ymin
  # screen
  var height/edx: (addr int) <- get target-screen, height
  var y/ecx: int <- copy 0
  {
    compare y, *height
    break-if->=
    set-cursor-position screen, xmin, screen-y
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
    y <- increment
    screen-y <- increment
    loop
  }
  return screen-y
}

fn render-screen screen: (addr screen), _target-screen: (addr screen), xmin: int, ymin: int -> _/ecx: int {
  var target-screen/esi: (addr screen) <- copy _target-screen
  var screen-y/edi: int <- copy ymin
  # text data
  {
    var height/edx: (addr int) <- get target-screen, height
    var y/ecx: int <- copy 0
    {
      compare y, *height
      break-if->=
      set-cursor-position screen, xmin, screen-y
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
      y <- increment
      screen-y <- increment
      loop
    }
  }
  # pixel data
  {
    # screen top left pixels x y width height
    var tmp/eax: int <- copy xmin
    tmp <- shift-left 3/log2-font-width
    var left: int
    copy-to left, tmp
    tmp <- copy ymin
    tmp <- shift-left 4/log2-font-height
    var top: int
    copy-to top, tmp
    var pixels-ah/eax: (addr handle array byte) <- get target-screen, pixels
    var _pixels/eax: (addr array byte) <- lookup *pixels-ah
    var pixels/edi: (addr array byte) <- copy _pixels
    compare pixels, 0
    break-if-=
    var y/ebx: int <- copy 0
    var height-addr/edx: (addr int) <- get target-screen, height
    var height/edx: int <- copy *height-addr
    height <- shift-left 4/log2-font-height
    {
      compare y, height
      break-if->=
      var width-addr/edx: (addr int) <- get target-screen, width
      var width/edx: int <- copy *width-addr
      width <- shift-left 3/log2-font-width
      var x/eax: int <- copy 0
      {
        compare x, width
        break-if->=
        {
          var idx/ecx: int <- pixel-index target-screen, x, y
          var color-addr/ecx: (addr byte) <- index pixels, idx
          var color/ecx: byte <- copy-byte *color-addr
          var color2/ecx: int <- copy color
          compare color2, 0
          break-if-=
          var x2/eax: int <- copy x
          x2 <- add left
          var y2/ebx: int <- copy y
          y2 <- add top
          pixel screen, x2, y2, color2
        }
        x <- increment
        loop
      }
      y <- increment
      loop
    }
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
  var y/ecx: int <- copy ymin
  y <- increment  # padding
  var x/eax: int <- draw-text-rightward screen, "keyboard: ", xmin, 0x99/xmax, y, 0x17/fg, 0xc5/bg=blue-bg
  var cursor-in-keyboard?/esi: (addr boolean) <- get self, cursor-in-keyboard?
  y <- render-keyboard screen, keyboard-obj, x, y, *cursor-in-keyboard?
  y <- increment  # padding
  return y
}

fn render-keyboard screen: (addr screen), _keyboard: (addr gap-buffer), xmin: int, ymin: int, render-cursor?: boolean -> _/ecx: int {
  var keyboard/esi: (addr gap-buffer) <- copy _keyboard
  var width/edx: int <- copy 0x10/keyboard-capacity
  var y/edi: int <- copy ymin
  # keyboard
  var x/eax: int <- copy xmin
  var xmax/ecx: int <- copy x
  xmax <- add 0x10
  var ymax/edx: int <- copy ymin
  ymax <- add 1
  clear-rect screen, x, y, xmax, ymax, 0/bg
  x <- render-gap-buffer screen, keyboard, x, y, render-cursor?, 3/fg, 0/bg
  y <- increment
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

fn render-sandbox-edit-menu screen: (addr screen), _self: (addr sandbox) {
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
  $render-sandbox-edit-menu:render-ctrl-m: {
    var self/eax: (addr sandbox) <- copy _self
    var has-trace?/eax: boolean <- has-trace? self
    compare has-trace?, 0/false
    {
      break-if-=
      draw-text-rightward-from-cursor screen, " ^m ", width, 0/fg, 0x38/bg=trace
      draw-text-rightward-from-cursor screen, " to trace  ", width, 7/fg, 0xc5/bg=blue-bg
      break $render-sandbox-edit-menu:render-ctrl-m
    }
    draw-text-rightward-from-cursor screen, " ^m ", width, 0/fg, 3/bg=keyboard
    draw-text-rightward-from-cursor screen, " to keyboard  ", width, 7/fg, 0xc5/bg=blue-bg
  }
  draw-text-rightward-from-cursor screen, " ^a ", width, 0/fg, 0x5c/bg=menu-highlight
  draw-text-rightward-from-cursor screen, " <<  ", width, 7/fg, 0xc5/bg=blue-bg
  draw-text-rightward-from-cursor screen, " ^b ", width, 0/fg, 0x5c/bg=menu-highlight
  draw-text-rightward-from-cursor screen, " <word  ", width, 7/fg, 0xc5/bg=blue-bg
  draw-text-rightward-from-cursor screen, " ^f ", width, 0/fg, 0x5c/bg=menu-highlight
  draw-text-rightward-from-cursor screen, " word>  ", width, 7/fg, 0xc5/bg=blue-bg
  draw-text-rightward-from-cursor screen, " ^e ", width, 0/fg, 0x5c/bg=menu-highlight
  draw-text-rightward-from-cursor screen, " >>  ", width, 7/fg, 0xc5/bg=blue-bg
}

fn render-keyboard-menu screen: (addr screen) {
  var width/eax: int <- copy 0
  var height/ecx: int <- copy 0
  width, height <- screen-size screen
  var y/ecx: int <- copy height
  y <- decrement
  var height/edx: int <- copy y
  height <- increment
  clear-rect screen, 0/x, y, width, height, 0xc5/bg=blue-bg
  set-cursor-position screen, 0/x, y
  draw-text-rightward-from-cursor screen, " ^r ", width, 0/fg, 0x5c/bg=menu-highlight
  draw-text-rightward-from-cursor screen, " run main  ", width, 7/fg, 0xc5/bg=blue-bg
  draw-text-rightward-from-cursor screen, " ^s ", width, 0/fg, 0x5c/bg=menu-highlight
  draw-text-rightward-from-cursor screen, " run sandbox  ", width, 7/fg, 0xc5/bg=blue-bg
  draw-text-rightward-from-cursor screen, " ^g ", width, 0/fg, 0x5c/bg=menu-highlight
  draw-text-rightward-from-cursor screen, " go to  ", width, 7/fg, 0xc5/bg=blue-bg
  draw-text-rightward-from-cursor screen, " ^m ", width, 0/fg, 7/bg
  draw-text-rightward-from-cursor screen, " to sandbox  ", width, 7/fg, 0xc5/bg=blue-bg
}

fn edit-sandbox _self: (addr sandbox), key: grapheme, globals: (addr global-table), data-disk: (addr disk) {
  var self/esi: (addr sandbox) <- copy _self
  # ctrl-s
  {
    compare key, 0x13/ctrl-s
    break-if-!=
    # if cursor is in trace, skip
    var cursor-in-trace?/eax: (addr boolean) <- get self, cursor-in-trace?
    compare *cursor-in-trace?, 0/false
    break-if-!=
    # minor gotcha here: any bindings created later in this iteration won't be
    # persisted until the next call to ctrl-s.
    store-state data-disk, self, globals
    #
    run-sandbox self, globals
    return
  }
  # ctrl-m
  {
    compare key, 0xd/ctrl-m
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
    edit-gap-buffer data, key
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
    edit-gap-buffer keyboard, key
    return
  }
  # if cursor in trace, send key to trace
  {
    var cursor-in-trace?/eax: (addr boolean) <- get self, cursor-in-trace?
    compare *cursor-in-trace?, 0/false
    break-if-=
    var trace-ah/eax: (addr handle trace) <- get self, trace
    var trace/eax: (addr trace) <- lookup *trace-ah
    # if expanding the trace, first check if we need to run the sandbox again with a deeper trace
    {
      compare key, 0xa/newline
      break-if-!=
      {
        var need-rerun?/eax: boolean <- cursor-too-deep? trace
        compare need-rerun?, 0/false
      }
      break-if-=
#?       draw-text-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, "rerun", 7/fg 0/bg
      # save trace lines at various cached indices
      var save: trace-index-stash
      var save-addr/ecx: (addr trace-index-stash) <- address save
      save-indices trace, save-addr
      # rerun at higher depth
      var max-depth-addr/ecx: (addr int) <- get trace, max-depth
      increment *max-depth-addr
      run-sandbox self, globals
      # recompute cached indices
      recompute-all-visible-lines trace
      var save-addr/ecx: (addr trace-index-stash) <- address save
      restore-indices trace, save-addr
    }
    edit-trace trace, key
    return
  }
}

fn run-sandbox _self: (addr sandbox), globals: (addr global-table) {
  var self/esi: (addr sandbox) <- copy _self
  var data-ah/ecx: (addr handle gap-buffer) <- get self, data
  var eval-result-h: (handle cell)
  var eval-result-ah/edi: (addr handle cell) <- address eval-result-h
  var definitions-created-storage: (stream int 0x10)
  var definitions-created/edx: (addr stream int) <- address definitions-created-storage
  var trace-ah/eax: (addr handle trace) <- get self, trace
  var _trace/eax: (addr trace) <- lookup *trace-ah
  var trace/ebx: (addr trace) <- copy _trace
  clear-trace trace
  var tmp/eax: (addr handle cell) <- get self, screen-var
  var screen-cell: (addr handle cell)
  copy-to screen-cell, tmp
  clear-screen-cell screen-cell
  var keyboard-cell/eax: (addr handle cell) <- get self, keyboard-var
  rewind-keyboard-cell keyboard-cell  # don't clear keys from before
  # read, eval, save gap buffer
  run data-ah, eval-result-ah, globals, definitions-created, trace, screen-cell, keyboard-cell
  # if necessary, initialize a new gap-buffer for sandbox
  {
    compare globals, 0
    break-if-=
    rewind-stream definitions-created
    var no-definitions?/eax: boolean <- stream-empty? definitions-created
    compare no-definitions?, 0/false
    break-if-!=
    # some definitions were created; clear the gap buffer
    var data/eax: (addr gap-buffer) <- lookup *data-ah
    var capacity/edx: int <- gap-buffer-capacity data
    allocate data-ah
    var new-data/eax: (addr gap-buffer) <- lookup *data-ah
    initialize-gap-buffer new-data, capacity
  }
  # print
  var value-ah/eax: (addr handle stream byte) <- get self, value
  var value/eax: (addr stream byte) <- lookup *value-ah
  clear-stream value
  print-cell eval-result-ah, value, trace
}

fn run _in-ah: (addr handle gap-buffer), result-ah: (addr handle cell), globals: (addr global-table), definitions-created: (addr stream int), trace: (addr trace), screen-cell: (addr handle cell), keyboard-cell: (addr handle cell) {
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
  debug-print "^", 4/fg, 0/bg
  evaluate read-result-ah, result-ah, *nil-ah, globals, trace, screen-cell, keyboard-cell, definitions-created, 1/call-number
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

fn test-run-integer {
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox-with sandbox, "1"
  # eval
  edit-sandbox sandbox, 0x13/ctrl-s, 0/no-globals, 0/no-disk
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width, 0x10/height, 0/no-pixel-graphics
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 1/show-cursor
  # skip one line of padding
  check-screen-row screen, 1/y, " 1    ", "F - test-run-integer/0"
  check-screen-row screen, 2/y, " ...  ", "F - test-run-integer/1"
  check-screen-row screen, 3/y, " => 1 ", "F - test-run-integer/2"
}

fn test-run-negative-integer {
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox-with sandbox, "-1"
  # eval
  edit-sandbox sandbox, 0x13/ctrl-s, 0/no-globals, 0/no-disk
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width, 0x10/height, 0/no-pixel-graphics
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 1/show-cursor
  # skip one line of padding
  check-screen-row screen, 1/y, " -1    ", "F - test-run-negative-integer/0"
  check-screen-row screen, 2/y, " ...   ", "F - test-run-negative-integer/1"
  check-screen-row screen, 3/y, " => -1 ", "F - test-run-negative-integer/2"
}

fn test-run-error-invalid-integer {
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox-with sandbox, "1a"
  # eval
  edit-sandbox sandbox, 0x13/ctrl-s, 0/no-globals, 0/no-disk
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width, 0x10/height, 0/no-pixel-graphics
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 1/show-cursor
  # skip one line of padding
  check-screen-row            screen,               1/y, " 1a             ", "F - test-run-error-invalid-integer/0"
  check-screen-row            screen,               2/y, " ...            ", "F - test-run-error-invalid-integer/1"
  check-screen-row-in-color   screen, 0xc/fg=error, 3/y, " invalid number ", "F - test-run-error-invalid-integer/2"
}

fn test-run-error-unknown-symbol {
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox-with sandbox, "a"
  # eval
  edit-sandbox sandbox, 0x13/ctrl-s, 0/no-globals, 0/no-disk
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width, 0x10/height, 0/no-pixel-graphics
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 1/show-cursor
  # skip one line of padding
  check-screen-row            screen,               1/y, " a                  ", "F - test-run-error-unknown-symbol/0"
  check-screen-row            screen,               2/y, " ...                ", "F - test-run-error-unknown-symbol/1"
  check-screen-row-in-color   screen, 0xc/fg=error, 3/y, " unbound symbol: a  ", "F - test-run-error-unknown-symbol/2"
}

fn test-run-with-spaces {
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox-with sandbox, " 1 \n"
  # eval
  edit-sandbox sandbox, 0x13/ctrl-s, 0/no-globals, 0/no-disk
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width, 0x10/height, 0/no-pixel-graphics
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 1/show-cursor
  # skip one line of padding
  check-screen-row screen, 1/y, "  1   ", "F - test-run-with-spaces/0"
  check-screen-row screen, 2/y, "      ", "F - test-run-with-spaces/1"
  check-screen-row screen, 3/y, " ...  ", "F - test-run-with-spaces/2"
  check-screen-row screen, 4/y, " => 1 ", "F - test-run-with-spaces/3"
}

fn test-run-quote {
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox-with sandbox, "'a"
  # eval
  edit-sandbox sandbox, 0x13/ctrl-s, 0/no-globals, 0/no-disk
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width, 0x10/height, 0/no-pixel-graphics
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 1/show-cursor
  # skip one line of padding
  check-screen-row screen, 1/y, " 'a   ", "F - test-run-quote/0"
  check-screen-row screen, 2/y, " ...  ", "F - test-run-quote/1"
  check-screen-row screen, 3/y, " => a ", "F - test-run-quote/2"
}

fn test-run-dotted-list {
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox-with sandbox, "'(a . b)"
  # eval
  edit-sandbox sandbox, 0x13/ctrl-s, 0/no-globals, 0/no-disk
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width, 0x10/height, 0/no-pixel-graphics
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 1/show-cursor
  # skip one line of padding
  check-screen-row screen, 1/y, " '(a . b)   ", "F - test-run-dotted-list/0"
  check-screen-row screen, 2/y, " ...        ", "F - test-run-dotted-list/1"
  check-screen-row screen, 3/y, " => (a . b) ", "F - test-run-dotted-list/2"
}

fn test-run-dot-and-list {
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox-with sandbox, "'(a . (b))"
  # eval
  edit-sandbox sandbox, 0x13/ctrl-s, 0/no-globals, 0/no-disk
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width, 0x10/height, 0/no-pixel-graphics
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 1/show-cursor
  # skip one line of padding
  check-screen-row screen, 1/y, " '(a . (b)) ", "F - test-run-dot-and-list/0"
  check-screen-row screen, 2/y, " ...        ", "F - test-run-dot-and-list/1"
  check-screen-row screen, 3/y, " => (a b)   ", "F - test-run-dot-and-list/2"
}

fn test-run-final-dot {
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox-with sandbox, "'(a .)"
  # eval
  edit-sandbox sandbox, 0x13/ctrl-s, 0/no-globals, 0/no-disk
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width, 0x10/height, 0/no-pixel-graphics
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 1/show-cursor
  # skip one line of padding
  check-screen-row screen, 1/y, " '(a .)               ", "F - test-run-final-dot/0"
  check-screen-row screen, 2/y, " ...                  ", "F - test-run-final-dot/1"
  check-screen-row screen, 3/y, " '. )' makes no sense ", "F - test-run-final-dot/2"
  # further errors may occur
}

fn test-run-double-dot {
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox-with sandbox, "'(a . .)"
  # eval
  edit-sandbox sandbox, 0x13/ctrl-s, 0/no-globals, 0/no-disk
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width, 0x10/height, 0/no-pixel-graphics
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 1/show-cursor
  # skip one line of padding
  check-screen-row screen, 1/y, " '(a . .)             ", "F - test-run-double-dot/0"
  check-screen-row screen, 2/y, " ...                  ", "F - test-run-double-dot/1"
  check-screen-row screen, 3/y, " '. .' makes no sense ", "F - test-run-double-dot/2"
  # further errors may occur
}

fn test-run-multiple-expressions-after-dot {
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox-with sandbox, "'(a . b c)"
  # eval
  edit-sandbox sandbox, 0x13/ctrl-s, 0/no-globals, 0/no-disk
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width, 0x10/height, 0/no-pixel-graphics
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 1/show-cursor
  # skip one line of padding
  check-screen-row screen, 1/y, " '(a . b c)                                           ", "F - test-run-multiple-expressions-after-dot/0"
  check-screen-row screen, 2/y, " ...                                                  ", "F - test-run-multiple-expressions-after-dot/1"
  check-screen-row screen, 3/y, " cannot have multiple expressions between '.' and ')' ", "F - test-run-multiple-expressions-after-dot/2"
  # further errors may occur
}

fn test-run-stream {
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox-with sandbox, "[a b]"
  # eval
  edit-sandbox sandbox, 0x13/ctrl-s, 0/no-globals, 0/no-disk
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width, 0x10/height, 0/no-pixel-graphics
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 1/show-cursor
  # skip one line of padding
  check-screen-row screen, 1/y, " [a b]    ", "F - test-run-stream/0"
  check-screen-row screen, 2/y, " ...      ", "F - test-run-stream/1"
  check-screen-row screen, 3/y, " => [a b] ", "F - test-run-stream/2"
}

fn test-run-move-cursor-into-trace {
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox-with sandbox, "12"
  # eval
  edit-sandbox sandbox, 0x13/ctrl-s, 0/no-globals, 0/no-disk
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width, 0x10/height, 0/no-pixel-graphics
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 1/show-cursor
  # skip one line of padding
  check-screen-row screen,                                  1/y, " 12    ", "F - test-run-move-cursor-into-trace/pre-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "   |   ", "F - test-run-move-cursor-into-trace/pre-0/cursor"
  check-screen-row screen,                                  2/y, " ...   ", "F - test-run-move-cursor-into-trace/pre-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "       ", "F - test-run-move-cursor-into-trace/pre-1/cursor"
  check-screen-row screen,                                  3/y, " => 12 ", "F - test-run-move-cursor-into-trace/pre-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 3/y, "       ", "F - test-run-move-cursor-into-trace/pre-2/cursor"
  # move cursor into trace
  edit-sandbox sandbox, 0xd/ctrl-m, 0/no-globals, 0/no-disk
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 1/show-cursor
  # skip one line of padding
  check-screen-row screen,                                  1/y, " 12    ", "F - test-run-move-cursor-into-trace/trace-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "       ", "F - test-run-move-cursor-into-trace/trace-0/cursor"
  check-screen-row screen,                                  2/y, " ...   ", "F - test-run-move-cursor-into-trace/trace-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, " |||   ", "F - test-run-move-cursor-into-trace/trace-1/cursor"
  check-screen-row screen,                                  3/y, " => 12 ", "F - test-run-move-cursor-into-trace/trace-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 3/y, "       ", "F - test-run-move-cursor-into-trace/trace-2/cursor"
  # move cursor into input
  edit-sandbox sandbox, 0xd/ctrl-m, 0/no-globals, 0/no-disk
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 1/show-cursor
  # skip one line of padding
  check-screen-row screen,                                  1/y, " 12    ", "F - test-run-move-cursor-into-trace/input-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "   |   ", "F - test-run-move-cursor-into-trace/input-0/cursor"
  check-screen-row screen,                                  2/y, " ...   ", "F - test-run-move-cursor-into-trace/input-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "       ", "F - test-run-move-cursor-into-trace/input-1/cursor"
  check-screen-row screen,                                  3/y, " => 12 ", "F - test-run-move-cursor-into-trace/input-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 3/y, "       ", "F - test-run-move-cursor-into-trace/input-2/cursor"
}

fn has-trace? _self: (addr sandbox) -> _/eax: boolean {
  var self/esi: (addr sandbox) <- copy _self
  var trace-ah/eax: (addr handle trace) <- get self, trace
  var _trace/eax: (addr trace) <- lookup *trace-ah
  var trace/edx: (addr trace) <- copy _trace
  compare trace, 0
  {
    break-if-!=
    abort "null trace"
  }
  var first-free/ebx: (addr int) <- get trace, first-free
  compare *first-free, 0
  {
    break-if->
    return 0/false
  }
  return 1/true
}

fn test-run-expand-trace {
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  initialize-sandbox-with sandbox, "12"
  # eval
  edit-sandbox sandbox, 0x13/ctrl-s, 0/no-globals, 0/no-disk
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width, 0x10/height, 0/no-pixel-graphics
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 1/show-cursor
  # skip one line of padding
  check-screen-row screen,                                  1/y, " 12    ", "F - test-run-expand-trace/pre0-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "   |   ", "F - test-run-expand-trace/pre0-0/cursor"
  check-screen-row screen,                                  2/y, " ...   ", "F - test-run-expand-trace/pre0-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "       ", "F - test-run-expand-trace/pre0-1/cursor"
  check-screen-row screen,                                  3/y, " => 12 ", "F - test-run-expand-trace/pre0-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 3/y, "       ", "F - test-run-expand-trace/pre0-2/cursor"
  # move cursor into trace
  edit-sandbox sandbox, 0xd/ctrl-m, 0/no-globals, 0/no-disk
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 1/show-cursor
  # skip one line of padding
  check-screen-row screen,                                  1/y, " 12    ", "F - test-run-expand-trace/pre1-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "       ", "F - test-run-expand-trace/pre1-0/cursor"
  check-screen-row screen,                                  2/y, " ...   ", "F - test-run-expand-trace/pre1-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, " |||   ", "F - test-run-expand-trace/pre1-1/cursor"
  check-screen-row screen,                                  3/y, " => 12 ", "F - test-run-expand-trace/pre1-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 3/y, "       ", "F - test-run-expand-trace/pre1-2/cursor"
  # expand
  edit-sandbox sandbox, 0xa/newline, 0/no-globals, 0/no-disk
  #
  clear-screen screen
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 1/show-cursor
  # skip one line of padding
  check-screen-row screen,                                  1/y, " 12    ", "F - test-run-expand-trace/expand-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "       ", "F - test-run-expand-trace/expand-0/cursor"
  check-screen-row screen,                                  2/y, " 1 toke", "F - test-run-expand-trace/expand-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, " ||||||", "F - test-run-expand-trace/expand-1/cursor"
  check-screen-row screen,                                  3/y, " ...   ", "F - test-run-expand-trace/expand-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 3/y, "       ", "F - test-run-expand-trace/expand-2/cursor"
  check-screen-row screen,                                  4/y, " 1 pars", "F - test-run-expand-trace/expand-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 4/y, "       ", "F - test-run-expand-trace/expand-2/cursor"
}

fn test-run-can-rerun-when-expanding-trace {
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  # initialize sandbox with a max-depth of 3
  initialize-sandbox-with sandbox, "12"
  # eval
  edit-sandbox sandbox, 0x13/ctrl-s, 0/no-globals, 0/no-disk
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width, 0x10/height, 0/no-pixel-graphics
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 1/show-cursor
  # skip one line of padding
  check-screen-row screen,                                  1/y, " 12    ", "F - test-run-can-rerun-when-expanding-trace/pre0-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "   |   ", "F - test-run-can-rerun-when-expanding-trace/pre0-0/cursor"
  check-screen-row screen,                                  2/y, " ...   ", "F - test-run-can-rerun-when-expanding-trace/pre0-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "       ", "F - test-run-can-rerun-when-expanding-trace/pre0-1/cursor"
  check-screen-row screen,                                  3/y, " => 12 ", "F - test-run-can-rerun-when-expanding-trace/pre0-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 3/y, "       ", "F - test-run-can-rerun-when-expanding-trace/pre0-2/cursor"
  # move cursor into trace
  edit-sandbox sandbox, 0xd/ctrl-m, 0/no-globals, 0/no-disk
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 1/show-cursor
  # skip one line of padding
  check-screen-row screen,                                  1/y, " 12    ", "F - test-run-can-rerun-when-expanding-trace/pre1-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "       ", "F - test-run-can-rerun-when-expanding-trace/pre1-0/cursor"
  check-screen-row screen,                                  2/y, " ...   ", "F - test-run-can-rerun-when-expanding-trace/pre1-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, " |||   ", "F - test-run-can-rerun-when-expanding-trace/pre1-1/cursor"
  check-screen-row screen,                                  3/y, " => 12 ", "F - test-run-can-rerun-when-expanding-trace/pre1-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 3/y, "       ", "F - test-run-can-rerun-when-expanding-trace/pre1-2/cursor"
  # expand
  edit-sandbox sandbox, 0xa/newline, 0/no-globals, 0/no-disk
  #
  clear-screen screen
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 1/show-cursor
  # skip one line of padding
  check-screen-row screen,                                  1/y, " 12    ", "F - test-run-can-rerun-when-expanding-trace/pre2-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "       ", "F - test-run-can-rerun-when-expanding-trace/pre2-0/cursor"
  check-screen-row screen,                                  2/y, " 1 toke", "F - test-run-can-rerun-when-expanding-trace/pre2-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, " ||||||", "F - test-run-can-rerun-when-expanding-trace/pre2-1/cursor"
  check-screen-row screen,                                  3/y, " ...   ", "F - test-run-can-rerun-when-expanding-trace/pre2-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 3/y, "       ", "F - test-run-can-rerun-when-expanding-trace/pre2-2/cursor"
  check-screen-row screen,                                  4/y, " 1 pars", "F - test-run-can-rerun-when-expanding-trace/pre2-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 4/y, "       ", "F - test-run-can-rerun-when-expanding-trace/pre2-2/cursor"
  # move cursor down and expand
  edit-sandbox sandbox, 0x6a/j, 0/no-globals, 0/no-disk
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 1/show-cursor
  edit-sandbox sandbox, 0xa/newline, 0/no-globals, 0/no-disk
  #
  clear-screen screen
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 1/show-cursor
  # screen looks same as if trace max-depth was really high
  check-screen-row screen,                                  1/y, " 12    ", "F - test-run-can-rerun-when-expanding-trace/expand-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "       ", "F - test-run-can-rerun-when-expanding-trace/expand-0/cursor"
  check-screen-row screen,                                  2/y, " 1 toke", "F - test-run-can-rerun-when-expanding-trace/expand-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "       ", "F - test-run-can-rerun-when-expanding-trace/expand-1/cursor"
  check-screen-row screen,                                  3/y, " 2 next", "F - test-run-can-rerun-when-expanding-trace/expand-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 3/y, " ||||||", "F - test-run-can-rerun-when-expanding-trace/expand-2/cursor"
  check-screen-row screen,                                  4/y, " ...   ", "F - test-run-can-rerun-when-expanding-trace/expand-3"
  check-background-color-in-screen-row screen, 7/bg=cursor, 4/y, "       ", "F - test-run-can-rerun-when-expanding-trace/expand-3/cursor"
  check-screen-row screen,                                  5/y, " 2 => 1", "F - test-run-can-rerun-when-expanding-trace/expand-4"
  check-background-color-in-screen-row screen, 7/bg=cursor, 5/y, "       ", "F - test-run-can-rerun-when-expanding-trace/expand-4/cursor"
}

fn test-run-preserves-trace-view-on-rerun {
  var sandbox-storage: sandbox
  var sandbox/esi: (addr sandbox) <- address sandbox-storage
  # initialize sandbox with a max-depth of 3
  initialize-sandbox-with sandbox, "7"
  # eval
  edit-sandbox sandbox, 0x13/ctrl-s, 0/no-globals, 0/no-disk
  # setup: screen
  var screen-on-stack: screen
  var screen/edi: (addr screen) <- address screen-on-stack
  initialize-screen screen, 0x80/width, 0x10/height, 0/no-pixel-graphics
  #
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 1/show-cursor
  # skip one line of padding
  check-screen-row screen,                                  1/y, " 7                     ", "F - test-run-preserves-trace-view-on-rerun/pre0-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "  |                    ", "F - test-run-preserves-trace-view-on-rerun/pre0-0/cursor"
  check-screen-row screen,                                  2/y, " ...                   ", "F - test-run-preserves-trace-view-on-rerun/pre0-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "                       ", "F - test-run-preserves-trace-view-on-rerun/pre0-1/cursor"
  check-screen-row screen,                                  3/y, " => 7                  ", "F - test-run-preserves-trace-view-on-rerun/pre0-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 3/y, "                       ", "F - test-run-preserves-trace-view-on-rerun/pre0-2/cursor"
  # move cursor into trace
  edit-sandbox sandbox, 0xd/ctrl-m, 0/no-globals, 0/no-disk
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 1/show-cursor
  #
  check-screen-row screen,                                  1/y, " 7                     ", "F - test-run-preserves-trace-view-on-rerun/pre1-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "                       ", "F - test-run-preserves-trace-view-on-rerun/pre1-0/cursor"
  check-screen-row screen,                                  2/y, " ...                   ", "F - test-run-preserves-trace-view-on-rerun/pre1-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, " |||                   ", "F - test-run-preserves-trace-view-on-rerun/pre1-1/cursor"
  check-screen-row screen,                                  3/y, " => 7                  ", "F - test-run-preserves-trace-view-on-rerun/pre1-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 3/y, "                       ", "F - test-run-preserves-trace-view-on-rerun/pre1-2/cursor"
  # expand
  edit-sandbox sandbox, 0xa/newline, 0/no-globals, 0/no-disk
  clear-screen screen
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 1/show-cursor
  #
  check-screen-row screen,                                  1/y, " 7                     ", "F - test-run-preserves-trace-view-on-rerun/pre2-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "                       ", "F - test-run-preserves-trace-view-on-rerun/pre2-0/cursor"
  check-screen-row screen,                                  2/y, " 1 tokenize            ", "F - test-run-preserves-trace-view-on-rerun/pre2-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, " ||||||||||            ", "F - test-run-preserves-trace-view-on-rerun/pre2-1/cursor"
  check-screen-row screen,                                  3/y, " ...                   ", "F - test-run-preserves-trace-view-on-rerun/pre2-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 3/y, "                       ", "F - test-run-preserves-trace-view-on-rerun/pre2-2/cursor"
  check-screen-row screen,                                  4/y, " 1 parse               ", "F - test-run-preserves-trace-view-on-rerun/pre2-3"
  check-background-color-in-screen-row screen, 7/bg=cursor, 4/y, "                       ", "F - test-run-preserves-trace-view-on-rerun/pre2-3/cursor"
  check-screen-row screen,                                  5/y, " ...                   ", "F - test-run-preserves-trace-view-on-rerun/pre2-4"
  check-background-color-in-screen-row screen, 7/bg=cursor, 5/y, "                       ", "F - test-run-preserves-trace-view-on-rerun/pre2-4/cursor"
  check-screen-row screen,                                  6/y, " 1 macroexpand 7       ", "F - test-run-preserves-trace-view-on-rerun/pre2-5"
  check-background-color-in-screen-row screen, 7/bg=cursor, 6/y, "                       ", "F - test-run-preserves-trace-view-on-rerun/pre2-5/cursor"
  check-screen-row screen,                                  7/y, " ...                   ", "F - test-run-preserves-trace-view-on-rerun/pre2-6"
  check-background-color-in-screen-row screen, 7/bg=cursor, 7/y, "                       ", "F - test-run-preserves-trace-view-on-rerun/pre2-6/cursor"
  check-screen-row screen,                                  8/y, " 1 => 7                ", "F - test-run-preserves-trace-view-on-rerun/pre2-7"
  check-background-color-in-screen-row screen, 7/bg=cursor, 8/y, "                       ", "F - test-run-preserves-trace-view-on-rerun/pre2-7/cursor"
  # move cursor down below the macroexpand line and expand
  edit-sandbox sandbox, 0x6a/j, 0/no-globals, 0/no-disk
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 1/show-cursor
  edit-sandbox sandbox, 0x6a/j, 0/no-globals, 0/no-disk
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 1/show-cursor
  edit-sandbox sandbox, 0x6a/j, 0/no-globals, 0/no-disk
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 1/show-cursor
  edit-sandbox sandbox, 0x6a/j, 0/no-globals, 0/no-disk
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 1/show-cursor
  edit-sandbox sandbox, 0x6a/j, 0/no-globals, 0/no-disk
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 1/show-cursor
  #
  check-screen-row screen,                                  1/y, " 7                     ", "F - test-run-preserves-trace-view-on-rerun/pre3-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "                       ", "F - test-run-preserves-trace-view-on-rerun/pre3-0/cursor"
  check-screen-row screen,                                  2/y, " 1 tokenize            ", "F - test-run-preserves-trace-view-on-rerun/pre3-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "                       ", "F - test-run-preserves-trace-view-on-rerun/pre3-1/cursor"
  check-screen-row screen,                                  3/y, " ...                   ", "F - test-run-preserves-trace-view-on-rerun/pre3-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 3/y, "                       ", "F - test-run-preserves-trace-view-on-rerun/pre3-2/cursor"
  check-screen-row screen,                                  4/y, " 1 parse               ", "F - test-run-preserves-trace-view-on-rerun/pre3-3"
  check-background-color-in-screen-row screen, 7/bg=cursor, 4/y, "                       ", "F - test-run-preserves-trace-view-on-rerun/pre3-3/cursor"
  check-screen-row screen,                                  5/y, " ...                   ", "F - test-run-preserves-trace-view-on-rerun/pre3-4"
  check-background-color-in-screen-row screen, 7/bg=cursor, 5/y, "                       ", "F - test-run-preserves-trace-view-on-rerun/pre3-4/cursor"
  check-screen-row screen,                                  6/y, " 1 macroexpand 7       ", "F - test-run-preserves-trace-view-on-rerun/pre3-5"
  check-background-color-in-screen-row screen, 7/bg=cursor, 6/y, "                       ", "F - test-run-preserves-trace-view-on-rerun/pre3-5/cursor"
  check-screen-row screen,                                  7/y, " ...                   ", "F - test-run-preserves-trace-view-on-rerun/pre3-6"
  check-background-color-in-screen-row screen, 7/bg=cursor, 7/y, " |||                   ", "F - test-run-preserves-trace-view-on-rerun/pre3-6/cursor"
  check-screen-row screen,                                  8/y, " 1 => 7                ", "F - test-run-preserves-trace-view-on-rerun/pre3-7"
  check-background-color-in-screen-row screen, 7/bg=cursor, 8/y, "                       ", "F - test-run-preserves-trace-view-on-rerun/pre3-7/cursor"
  # expand
  edit-sandbox sandbox, 0xa/newline, 0/no-globals, 0/no-disk
  clear-screen screen
  render-sandbox screen, sandbox, 0/x, 0/y, 0x80/width, 0x10/height, 1/show-cursor
  # cursor line is expanded
  check-screen-row screen,                                  1/y, " 7                     ", "F - test-run-preserves-trace-view-on-rerun/expand-0"
  check-background-color-in-screen-row screen, 7/bg=cursor, 1/y, "                       ", "F - test-run-preserves-trace-view-on-rerun/expand-0/cursor"
  check-screen-row screen,                                  2/y, " 1 tokenize            ", "F - test-run-preserves-trace-view-on-rerun/expand-1"
  check-background-color-in-screen-row screen, 7/bg=cursor, 2/y, "                       ", "F - test-run-preserves-trace-view-on-rerun/expand-1/cursor"
  check-screen-row screen,                                  3/y, " ...                   ", "F - test-run-preserves-trace-view-on-rerun/expand-2"
  check-background-color-in-screen-row screen, 7/bg=cursor, 3/y, "                       ", "F - test-run-preserves-trace-view-on-rerun/expand-2/cursor"
  check-screen-row screen,                                  4/y, " 1 parse               ", "F - test-run-preserves-trace-view-on-rerun/expand-3"
  check-background-color-in-screen-row screen, 7/bg=cursor, 4/y, "                       ", "F - test-run-preserves-trace-view-on-rerun/expand-3/cursor"
  check-screen-row screen,                                  5/y, " ...                   ", "F - test-run-preserves-trace-view-on-rerun/expand-4"
  check-background-color-in-screen-row screen, 7/bg=cursor, 5/y, "                       ", "F - test-run-preserves-trace-view-on-rerun/expand-4/cursor"
  check-screen-row screen,                                  6/y, " 1 macroexpand 7       ", "F - test-run-preserves-trace-view-on-rerun/expand-5"
  check-background-color-in-screen-row screen, 7/bg=cursor, 6/y, "                       ", "F - test-run-preserves-trace-view-on-rerun/expand-5/cursor"
  check-screen-row screen,                                  7/y, " 2 macroexpand-iter 7  ", "F - test-run-preserves-trace-view-on-rerun/expand-6"
  check-background-color-in-screen-row screen, 7/bg=cursor, 7/y, " ||||||||||||||||||||  ", "F - test-run-preserves-trace-view-on-rerun/expand-6/cursor"
  check-screen-row screen,                                  8/y, " ...                   ", "F - test-run-preserves-trace-view-on-rerun/expand-7"
  check-background-color-in-screen-row screen, 7/bg=cursor, 8/y, "                       ", "F - test-run-preserves-trace-view-on-rerun/expand-7/cursor"
}
