# The environment is a thin layer in this app, just a history of 'tabs' that
# are fully specified by the operations used to generate them.

type environment {
  tabs: (handle array tab)
  current: int  # index into tabs
}

type tab {
  type: int
  # type 0: items by a user
  # type 1: items in a channel
  # type 2: comments for a post
  # type 3: items containing a search (TODO)
  root-index: int  # into either users, items or comments
  item-index: int  # what item in the corresponding list we start rendering
                   # the current page at
  grapheme-index: int  # what character in the item we start rendering
                       # the current page at
}

# static buffer sizes in this file:
#   item-padding-hor          # in pixels
#   item-padding-ver          # in characters
#   avatar-side               # in pixels
#   avatar-space-hor          # in characters
#   author-name-padding-ver   # in characters
#   post-right-coord          # in characters

fn render-environment screen: (addr screen), env: (addr environment), users: (addr array user), channels: (addr array channel), _items: (addr array item) {
  clear-screen screen
  var tmp-width/eax: int <- copy 0
  var tmp-height/ecx: int <- copy 0
  tmp-width, tmp-height <- screen-size screen
  var screen-height: int
  copy-to screen-height, tmp-height
  #
  var y/ecx: int <- copy 1/item-padding-ver
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
    render-image screen, author-avatar, 0x18/item-padding-hor, y, 0x50/avatar-side, 0x50/avatar-side
  }
  # author name
  var author-real-name-ah/eax: (addr handle array byte) <- get author, real-name
  var author-real-name/eax: (addr array byte) <- lookup *author-real-name-ah
  set-cursor-position screen, 0x10/avatar-space-hor, y
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, author-real-name, 0xf/white 0/black
  increment y
  # text
  var text-ah/eax: (addr handle array byte) <- get item, text
  var _text/eax: (addr array byte) <- lookup *text-ah
  var text/edx: (addr array byte) <- copy _text
  var x/eax: int <- copy 0x10/avatar-space-hor
  var text-y/ecx: int <- copy y
  text-y <- add 1/author-name-padding-ver
  x, text-y <- draw-text-wrapping-right-then-down screen, text, x text-y, 0x50/xmax=post-right-coord screen-height, x text-y, 7/fg 0/bg
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
