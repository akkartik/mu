# The environment is a thin layer in this app, just a history of 'tabs' that
# are fully specified by the operations used to generate them.

type environment {
}

# static buffer sizes in this file:
#   main-panel-hor            # in characters
#   item-padding-hor          # in pixels
#   item-padding-ver          # in characters
#   avatar-side               # in pixels
#   avatar-space-hor          # in characters
#   search-space-ver          # in characters
#   author-name-padding-ver   # in characters
#   post-right-coord          # in characters
#   channel-offset-x          # in characters
#   menu-space-ver            # in characters

fn render-environment screen: (addr screen), env: (addr environment), users: (addr array user), channels: (addr array channel), items: (addr array item) {
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

fn render-item-list screen: (addr screen), env: (addr environment), _items: (addr array item), users: (addr array user) {
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
  var items/esi: (addr array item) <- copy _items
  var i/ebx: int <- copy 0
  var max/edx: int <- length items
  {
    compare i, max
    break-if->=
    compare y, screen-height
    break-if->=
    var offset/eax: (offset item) <- compute-offset items, i
    var curr-item/eax: (addr item) <- index items, offset
    y <- render-item screen, curr-item, users, y, screen-height
    i <- increment
    loop
  }
  var top/eax: int <- copy screen-height
  top <- subtract 2/menu-space-ver
  clear-rect screen, 0 top, screen-width screen-height, 0/bg
}

fn render-search-input screen: (addr screen), env: (addr environment) {
  set-cursor-position 0/screen, 2/x 1/y
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
  var x/eax: int <- copy 0x20/main-panel-hor
  x <- add 0x10/avatar-space-hor
  var text-y/ecx: int <- copy y
  text-y <- add 1/author-name-padding-ver
  x, text-y <- draw-text-wrapping-right-then-down screen, text, x text-y, 0x70/xmax=post-right-coord screen-height, x text-y, 7/fg 0/bg
  # flush
  add-to y, 6
  compare y, text-y
  {
    break-if-<
    return y
  }
  return text-y
}

fn update-environment env: (addr environment), key: byte {
}
