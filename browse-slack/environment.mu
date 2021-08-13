type environment {
  item-index: int
}

# static buffer sizes in this file:
#   main-panel-hor            # in characters
#   item-padding-hor          # in pixels
#   item-padding-ver          # in characters
#   avatar-side               # in pixels
#   avatar-space-hor          # in characters
#   avatar-space-ver          # in characters
#   search-position-x         # in characters
#   search-space-ver          # in characters
#   author-name-padding-ver   # in characters
#   post-right-coord          # in characters
#   channel-offset-x          # in characters
#   menu-space-ver            # in characters

fn initialize-environment _self: (addr environment), _items: (addr item-list) {
  var self/esi: (addr environment) <- copy _self
  var items/eax: (addr item-list) <- copy _items
  var newest-item-a/eax: (addr int) <- get items, newest
  var newest-item/eax: int <- copy *newest-item-a
  var dest/edi: (addr int) <- get self, item-index
  copy-to *dest, newest-item
}

### Render

fn render-environment screen: (addr screen), env: (addr environment), users: (addr array user), channels: (addr array channel), items: (addr item-list) {
  clear-screen screen
  render-search-input screen, env
  render-channels screen, env, channels
  render-item-list screen, env, items, users
  render-menu screen
}

fn render-channels screen: (addr screen), env: (addr environment), _channels: (addr array channel) {
  var channels/esi: (addr array channel) <- copy _channels
  var y/ebx: int <- copy 2/search-space-ver
  y <- add 1/item-padding-ver
  var i/ecx: int <- copy 0
  var max/edx: int <- length channels
  {
    compare i, max
    break-if->=
    var offset/eax: (offset channel) <- compute-offset channels, i
    var curr/eax: (addr channel) <- index channels, offset
    var name-ah/eax: (addr handle array byte) <- get curr, name
    var name/eax: (addr array byte) <- lookup *name-ah
    compare name, 0
    break-if-=
    set-cursor-position screen, 2/x y
    draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, "#", 0xf/grey 0/black
    draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, name, 0xf/grey 0/black
    y <- add 2/channel-padding
    i <- increment
    loop
  }
}

fn render-item-list screen: (addr screen), _env: (addr environment), _items: (addr item-list), users: (addr array user) {
  var env/esi: (addr environment) <- copy _env
  var tmp-width/eax: int <- copy 0
  var tmp-height/ecx: int <- copy 0
  tmp-width, tmp-height <- screen-size screen
  var screen-width: int
  copy-to screen-width, tmp-width
  var screen-height: int
  copy-to screen-height, tmp-height
  #
  var y/ecx: int <- copy 2/search-space-ver
  y <- add 1/item-padding-ver
  var newest-item/eax: (addr int) <- get env, item-index
  var i/ebx: int <- copy *newest-item
  var items/esi: (addr item-list) <- copy _items
  var items-data-ah/eax: (addr handle array item) <- get items, data
  var _items-data/eax: (addr array item) <- lookup *items-data-ah
  var items-data/edi: (addr array item) <- copy _items-data
  {
    compare i, 0
    break-if-<
    compare y, screen-height
    break-if->=
    var offset/eax: (offset item) <- compute-offset items-data, i
    var curr-item/eax: (addr item) <- index items-data, offset
    y <- render-item screen, curr-item, users, y, screen-height
    i <- decrement
    loop
  }
  var top/eax: int <- copy screen-height
  top <- subtract 2/menu-space-ver
  clear-rect screen, 0 top, screen-width screen-height, 0/bg
}

fn render-search-input screen: (addr screen), env: (addr environment) {
  set-cursor-position 0/screen, 0x22/x=search-position-x 1/y
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, "search ", 7/fg 0/bg
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, "________________________________", 0xf/fg 0/bg
}

fn render-menu screen: (addr screen) {
  var width/eax: int <- copy 0
  var y/ecx: int <- copy 0
  width, y <- screen-size screen
  y <- decrement
  set-cursor-position screen, 2/x, y
  draw-text-rightward-from-cursor screen, " / ", width, 0/fg 0xf/bg
  draw-text-rightward-from-cursor screen, " search  ", width, 0xf/fg, 0/bg
  draw-text-rightward-from-cursor screen, " ^f ", width, 0/fg 0xf/bg
  draw-text-rightward-from-cursor screen, " next page  ", width, 0xf/fg, 0/bg
  draw-text-rightward-from-cursor screen, " ^b ", width, 0/fg 0xf/bg
  draw-text-rightward-from-cursor screen, " previous page  ", width, 0xf/fg, 0/bg
  draw-text-rightward-from-cursor screen, " ^n ", width, 0/fg 0xf/bg
  draw-text-rightward-from-cursor screen, " next item  ", width, 0xf/fg, 0/bg
  draw-text-rightward-from-cursor screen, " ^p ", width, 0/fg 0xf/bg
  draw-text-rightward-from-cursor screen, " previous item  ", width, 0xf/fg, 0/bg
}

fn render-item screen: (addr screen), _item: (addr item), _users: (addr array user), y: int, screen-height: int -> _/ecx: int {
  var item/esi: (addr item) <- copy _item
  var users/edi: (addr array user) <- copy _users
  var author-index-addr/ecx: (addr int) <- get item, by
  var author-index/ecx: int <- copy *author-index-addr
  var author-offset/ecx: (offset user) <- compute-offset users, author-index
  var author/ecx: (addr user) <- index users, author-offset
  # author avatar
  var author-avatar-ah/eax: (addr handle image) <- get author, avatar
  var _author-avatar/eax: (addr image) <- lookup *author-avatar-ah
  var author-avatar/ebx: (addr image) <- copy _author-avatar
  {
    compare author-avatar, 0
    break-if-=
    var y/edx: int <- copy y
    y <- shift-left 4/log2font-height
    var x/eax: int <- copy 0x20/main-panel-hor
    x <- shift-left 3/log2font-width
    x <- add 0x18/item-padding-hor
    render-image screen, author-avatar, x, y, 0x50/avatar-side, 0x50/avatar-side
  }
  # channel
  var channel-name-ah/eax: (addr handle array byte) <- get item, channel
  var channel-name/eax: (addr array byte) <- lookup *channel-name-ah
  {
    var x/eax: int <- copy 0x20/main-panel-hor
    x <- add 0x40/channel-offset-x
    set-cursor-position screen, x y
  }
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, "#", 7/grey 0/black
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, channel-name, 7/grey 0/black
  # author name
  var author-real-name-ah/eax: (addr handle array byte) <- get author, real-name
  var author-real-name/eax: (addr array byte) <- lookup *author-real-name-ah
  {
    var x/ecx: int <- copy 0x20/main-panel-hor
    x <- add 0x10/avatar-space-hor
    set-cursor-position screen, x y
    draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, author-real-name, 0xf/white 0/black
  }
  increment y
  # text
  var text-ah/eax: (addr handle array byte) <- get item, text
  var _text/eax: (addr array byte) <- lookup *text-ah
  var text/edx: (addr array byte) <- copy _text
  var text-y/eax: int <- render-slack-message screen, text, y, screen-height
  # flush
  add-to y, 6/avatar-space-ver
  compare y, text-y
  {
    break-if-<
    return y
  }
  return text-y
}

fn render-slack-message screen: (addr screen), text: (addr array byte), ymin: int, ymax: int -> _/eax: int {
  var x/eax: int <- copy 0x20/main-panel-hor
  x <- add 0x10/avatar-space-hor
  var y/ecx: int <- copy ymin
  y <- add 1/author-name-padding-ver
  x, y <- draw-json-text-wrapping-right-then-down screen, text, x y, 0x70/xmax=post-right-coord ymax, x y, 7/fg 0/bg
  y <- add 2/item-padding-ver
  return y
}

# draw text in the rectangle from (xmin, ymin) to (xmax, ymax), starting from (x, y), wrapping as necessary
# return the next (x, y) coordinate in raster order where drawing stopped
# that way the caller can draw more if given the same min and max bounding-box.
# if there isn't enough space, truncate
fn draw-json-text-wrapping-right-then-down screen: (addr screen), _text: (addr array byte), xmin: int, ymin: int, xmax: int, ymax: int, _x: int, _y: int, color: int, background-color: int -> _/eax: int, _/ecx: int {
  var stream-storage: (stream byte 0x4000/print-buffer-size)
  var stream/edi: (addr stream byte) <- address stream-storage
  var text/esi: (addr array byte) <- copy _text
  var len/eax: int <- length text
  compare len, 0x4000/print-buffer-size
  {
    break-if-<
    write stream, "ERROR: stream too small in draw-text-wrapping-right-then-down"
  }
  compare len, 0x4000/print-buffer-size
  {
    break-if->=
    write stream, text
  }
  var x/eax: int <- copy _x
  var y/ecx: int <- copy _y
  x, y <- draw-json-stream-wrapping-right-then-down screen, stream, xmin, ymin, xmax, ymax, x, y, color, background-color
  return x, y
}

# draw a stream in the rectangle from (xmin, ymin) to (xmax, ymax), starting from (x, y), wrapping as necessary
# return the next (x, y) coordinate in raster order where drawing stopped
# that way the caller can draw more if given the same min and max bounding-box.
# if there isn't enough space, truncate
fn draw-json-stream-wrapping-right-then-down screen: (addr screen), stream: (addr stream byte), xmin: int, ymin: int, xmax: int, ymax: int, x: int, y: int, color: int, background-color: int -> _/eax: int, _/ecx: int {
  var xcurr/eax: int <- copy x
  var ycurr/ecx: int <- copy y
  {
    var g/ebx: grapheme <- read-json-grapheme stream
    compare g, 0xffffffff/end-of-file
    break-if-=
    $draw-json-stream-wrapping-right-then-down:render-grapheme: {
      compare g, 0x5c/backslash
      {
        break-if-!=
        xcurr, ycurr <- render-json-escaped-grapheme screen, stream, xmin, ymin, xmax, ymax, xcurr, ycurr, color, background-color
        break $draw-json-stream-wrapping-right-then-down:render-grapheme
      }
      xcurr, ycurr <- render-grapheme screen, g, xmin, ymin, xmax, ymax, xcurr, ycurr, color, background-color
    }
    loop
  }
  set-cursor-position screen, xcurr, ycurr
  return xcurr, ycurr
}

# just return a different register
fn read-json-grapheme stream: (addr stream byte) -> _/ebx: grapheme {
  var result/eax: grapheme <- read-grapheme stream
  return result
}

# '\' encountered
fn render-json-escaped-grapheme screen: (addr screen), stream: (addr stream byte), xmin: int, ymin: int, xmax: int, ymax: int, xcurr: int, ycurr: int, color: int, background-color: int -> _/eax: int, _/ecx: int {
  var g/ebx: grapheme <- read-json-grapheme stream
  compare g, 0xffffffff/end-of-file
  {
    break-if-!=
    return xcurr, ycurr
  }
  # \n = newline
  compare g, 0x6e/n
  var x/eax: int <- copy xcurr
  {
    break-if-!=
    increment ycurr
    return xmin, ycurr
  }
  # ignore \t \r \f \b
  {
    compare g, 0x74/t
    break-if-!=
    return xcurr, ycurr
  }
  {
    compare g, 0x72/r
    break-if-!=
    return xcurr, ycurr
  }
  {
    compare g, 0x66/f
    break-if-!=
    return xcurr, ycurr
  }
  {
    compare g, 0x62/b
    break-if-!=
    return xcurr, ycurr
  }
  var y/ecx: int <- copy 0
  # \u = Unicode
  {
    compare g, 0x75/u
    break-if-!=
    x, y <- render-json-escaped-unicode-grapheme screen, stream, xmin, ymin, xmax, ymax, xcurr, ycurr, color, background-color
    return x, y
  }
  # most characters escape to themselves
  x, y <- render-grapheme screen, g, xmin, ymin, xmax, ymax, xcurr, ycurr, color, background-color
  return x, y
}

# '\u' encountered
fn render-json-escaped-unicode-grapheme screen: (addr screen), stream: (addr stream byte), xmin: int, ymin: int, xmax: int, ymax: int, xcurr: int, ycurr: int, color: int, background-color: int -> _/eax: int, _/ecx: int {
  var ustream-storage: (stream byte 4)
  var ustream/esi: (addr stream byte) <- address ustream-storage
  # slurp 4 bytes exactly
  var b/eax: byte <- read-byte stream
  var b-int/eax: int <- copy b
  append-byte ustream, b-int
  var b/eax: byte <- read-byte stream
  var b-int/eax: int <- copy b
  append-byte ustream, b-int
  var b/eax: byte <- read-byte stream
  var b-int/eax: int <- copy b
  append-byte ustream, b-int
  var b/eax: byte <- read-byte stream
  var b-int/eax: int <- copy b
  append-byte ustream, b-int
  # \u2013 = -
  {
    var endash?/eax: boolean <- stream-data-equal? ustream, "2013"
    compare endash?, 0/false
    break-if-=
    var x/eax: int <- copy 0
    var y/ecx: int <- copy 0
    x, y <- render-grapheme screen, 0x2d/dash, xmin, ymin, xmax, ymax, xcurr, ycurr, color, background-color
    return x, y
  }
  # \u2014 = -
  {
    var emdash?/eax: boolean <- stream-data-equal? ustream, "2014"
    compare emdash?, 0/false
    break-if-=
    var x/eax: int <- copy 0
    var y/ecx: int <- copy 0
    x, y <- render-grapheme screen, 0x2d/dash, xmin, ymin, xmax, ymax, xcurr, ycurr, color, background-color
    return x, y
  }
  # \u2018 = '
  {
    var left-quote?/eax: boolean <- stream-data-equal? ustream, "2018"
    compare left-quote?, 0/false
    break-if-=
    var x/eax: int <- copy 0
    var y/ecx: int <- copy 0
    x, y <- render-grapheme screen, 0x27/quote, xmin, ymin, xmax, ymax, xcurr, ycurr, color, background-color
    return x, y
  }
  # \u2019 = '
  {
    var right-quote?/eax: boolean <- stream-data-equal? ustream, "2019"
    compare right-quote?, 0/false
    break-if-=
    var x/eax: int <- copy 0
    var y/ecx: int <- copy 0
    x, y <- render-grapheme screen, 0x27/quote, xmin, ymin, xmax, ymax, xcurr, ycurr, color, background-color
    return x, y
  }
  # \u201c = "
  {
    var left-dquote?/eax: boolean <- stream-data-equal? ustream, "201c"
    compare left-dquote?, 0/false
    break-if-=
    var x/eax: int <- copy 0
    var y/ecx: int <- copy 0
    x, y <- render-grapheme screen, 0x22/dquote, xmin, ymin, xmax, ymax, xcurr, ycurr, color, background-color
    return x, y
  }
  # \u201d = "
  {
    var right-dquote?/eax: boolean <- stream-data-equal? ustream, "201d"
    compare right-dquote?, 0/false
    break-if-=
    var x/eax: int <- copy 0
    var y/ecx: int <- copy 0
    x, y <- render-grapheme screen, 0x22/dquote, xmin, ymin, xmax, ymax, xcurr, ycurr, color, background-color
    return x, y
  }
  # \u2022 = *
  {
    var bullet?/eax: boolean <- stream-data-equal? ustream, "2022"
    compare bullet?, 0/false
    break-if-=
    var x/eax: int <- copy 0
    var y/ecx: int <- copy 0
    x, y <- render-grapheme screen, 0x2a/asterisk, xmin, ymin, xmax, ymax, xcurr, ycurr, color, background-color
    return x, y
  }
  # \u2026 = ...
  {
    var ellipses?/eax: boolean <- stream-data-equal? ustream, "2026"
    compare ellipses?, 0/false
    break-if-=
    var x/eax: int <- copy 0
    var y/ecx: int <- copy 0
    x, y <- draw-text-wrapping-right-then-down screen, "...", xmin, ymin, xmax, ymax, xcurr, ycurr, color, background-color
    return x, y
  }
  # TODO: rest of Unicode
  var x/eax: int <- copy 0
  var y/ecx: int <- copy 0
  x, y <- draw-stream-wrapping-right-then-down screen, ustream, xmin, ymin, xmax, ymax, xcurr, ycurr, color, background-color
  return x, y
}

### Edit

fn update-environment env: (addr environment), key: byte, items: (addr item-list) {
  {
    compare key, 0xe/ctrl-n
    break-if-!=
    next-item env, items
    return
  }
  {
    compare key, 0x10/ctrl-p
    break-if-!=
    previous-item env, items
    return
  }
  {
    compare key, 6/ctrl-f
    break-if-!=
    page-down env, items
    return
  }
  {
    compare key, 2/ctrl-b
    break-if-!=
    page-up env, items
    return
  }
}

fn next-item _env: (addr environment), _items: (addr item-list) {
  var env/edi: (addr environment) <- copy _env
  var dest/eax: (addr int) <- get env, item-index
  compare *dest, 0
  break-if-<=
  decrement *dest
}

fn previous-item _env: (addr environment), _items: (addr item-list) {
  var env/edi: (addr environment) <- copy _env
  var items/esi: (addr item-list) <- copy _items
  var newest-item-index-a/ecx: (addr int) <- get items, newest
  var newest-item-index/ecx: int <- copy *newest-item-index-a
  var dest/eax: (addr int) <- get env, item-index
  compare *dest, newest-item-index
  break-if->=
  increment *dest
}

fn page-down _env: (addr environment), _items: (addr item-list) {
  var env/edi: (addr environment) <- copy _env
  var items/esi: (addr item-list) <- copy _items
  var items-data-ah/eax: (addr handle array item) <- get items, data
  var _items-data/eax: (addr array item) <- lookup *items-data-ah
  var items-data/ebx: (addr array item) <- copy _items-data
  var src/eax: (addr int) <- get env, item-index
  var new-item-index/ecx: int <- copy *src
  var y/edx: int <- copy 2
  {
    compare new-item-index, 0
    break-if-<
    compare y, 0x28/screen-height-minus-menu
    break-if->=
    var offset/eax: (offset item) <- compute-offset items-data, new-item-index
    var item/eax: (addr item) <- index items-data, offset
    var item-text-ah/eax: (addr handle array byte) <- get item, text
    var item-text/eax: (addr array byte) <- lookup *item-text-ah
    var h/eax: int <- estimate-height item-text
    set-cursor-position 0/screen, 0 0
    draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, h, 4/fg 0/bg
    y <- add h
    new-item-index <- decrement
    loop
  }
  new-item-index <- increment
  var dest/eax: (addr int) <- get env, item-index
  {
    # HACK: make sure we make forward progress even if a single post takes up
    # the whole screen.
    # We can't see the rest of that single post at the moment. But at least we
    # can go past it.
    compare new-item-index, *dest
    break-if-!=
    # Don't make "forward progress" past post 0.
    compare new-item-index, 0
    break-if-=
    new-item-index <- decrement
  }
  copy-to *dest, new-item-index
}

fn page-up _env: (addr environment), _items: (addr item-list) {
  var env/edi: (addr environment) <- copy _env
  var items/esi: (addr item-list) <- copy _items
  var items-data-ah/eax: (addr handle array item) <- get items, data
  var _items-data/eax: (addr array item) <- lookup *items-data-ah
  var items-data/ebx: (addr array item) <- copy _items-data
  var newest-item-index-a/esi: (addr int) <- get items, newest
  var src/eax: (addr int) <- get env, item-index
  var new-item-index/ecx: int <- copy *src
  var y/edx: int <- copy 2
  {
    compare new-item-index, *newest-item-index-a
    break-if->
    compare y, 0x28/screen-height-minus-menu
    break-if->=
    var offset/eax: (offset item) <- compute-offset items-data, new-item-index
    var item/eax: (addr item) <- index items-data, offset
    var item-text-ah/eax: (addr handle array byte) <- get item, text
    var item-text/eax: (addr array byte) <- lookup *item-text-ah
    var h/eax: int <- estimate-height item-text
    set-cursor-position 0/screen, 0 0
    draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, h, 4/fg 0/bg
    y <- add h
    new-item-index <- increment
    loop
  }
  new-item-index <- decrement
  var dest/eax: (addr int) <- get env, item-index
  copy-to *dest, new-item-index
}

# keep sync'd with render-item
fn estimate-height _message-text: (addr array byte) -> _/eax: int {
  var message-text/esi: (addr array byte) <- copy _message-text
  var result/eax: int <- length message-text
  var remainder/edx: int <- copy 0
  result, remainder <- integer-divide result, 0x40/post-width
  compare remainder, 0
  {
    break-if-=
    result <- increment
  }
  result <- add 2/item-padding-ver
  compare result, 6/avatar-space-ver
  {
    break-if->
    return 6/avatar-space-ver
  }
  return result
}
