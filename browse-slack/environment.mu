type environment {
  search-terms: (handle gap-buffer)
  tabs: (handle array tab)
  current-tab-index: int  # index into tabs
  dirty?: boolean
  # search mode
  cursor-in-search?: boolean
  # channel mode
  cursor-in-channels?: boolean
  channel-cursor-index: int
}

type tab {
  type: int
      # type 0: everything
      # type 1: items in a channel
      # type 2: search for a term
      # type 3: comments in a single thread
  item-index: int  # what item in the corresponding list we start rendering
                   # the current page at
  # only for type 1
  channel-index: int
  # only for type 2
  search-terms: (handle gap-buffer)
  search-items: (handle array int)
  search-items-first-free: int
  # only for type 3
  root-index: int
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
#   max-search-results

fn initialize-environment _self: (addr environment), _items: (addr item-list) {
  var self/esi: (addr environment) <- copy _self
  var search-terms-ah/eax: (addr handle gap-buffer) <- get self, search-terms
  allocate search-terms-ah
  var search-terms/eax: (addr gap-buffer) <- lookup *search-terms-ah
  initialize-gap-buffer search-terms, 0x30/search-capacity
  var items/eax: (addr item-list) <- copy _items
  var items-data-first-free-a/eax: (addr int) <- get items, data-first-free
  var final-item/edx: int <- copy *items-data-first-free-a
  final-item <- decrement
  var tabs-ah/ecx: (addr handle array tab) <- get self, tabs
  populate tabs-ah, 0x10/max-history
  # current-tab-index implicitly set to 0
  var tabs/eax: (addr array tab) <- lookup *tabs-ah
  var first-tab/eax: (addr tab) <- index tabs, 0/current-tab-index
  var dest/edi: (addr int) <- get first-tab, item-index
  copy-to *dest, final-item
}

### Render

fn render-environment screen: (addr screen), _env: (addr environment), users: (addr array user), channels: (addr array channel), items: (addr item-list) {
  var env/esi: (addr environment) <- copy _env
  {
    var dirty?/eax: (addr boolean) <- get env, dirty?
    compare *dirty?, 0/false
    break-if-!=
    # minimize repaints when typing into the search bar
    {
      var cursor-in-search?/eax: (addr boolean) <- get env, cursor-in-search?
      compare *cursor-in-search?, 0/false
      break-if-=
      render-search-input screen, env
      clear-rect screen, 0/x 0x2f/y, 0x80/x 0x30/y, 0/bg
      render-search-menu screen, env
      return
    }
  }
  # full repaint
  clear-screen screen
  render-search-input screen, env
  render-channels screen, env, channels
  render-item-list screen, env, items, channels, users
  render-menu screen, env
  var dirty?/eax: (addr boolean) <- get env, dirty?
  copy-to *dirty?, 0/false
}

fn render-channels screen: (addr screen), _env: (addr environment), _channels: (addr array channel) {
  var env/esi: (addr environment) <- copy _env
  var cursor-index/edi: int <- copy -1
  {
    var cursor-in-search?/eax: (addr boolean) <- get env, cursor-in-search?
    compare *cursor-in-search?, 0/false
    break-if-!=
    var cursor-in-channels?/eax: (addr boolean) <- get env, cursor-in-channels?
    compare *cursor-in-channels?, 0/false
    break-if-=
    var cursor-index-addr/eax: (addr int) <- get env, channel-cursor-index
    cursor-index <- copy *cursor-index-addr
  }
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
    {
      compare cursor-index, i
      break-if-=
      draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, "#", 7/grey 0/black
      draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, name, 7/grey 0/black
    }
    {
      compare cursor-index, i
      break-if-!=
      # cursor; reverse video
      draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, "#", 0/black 0xf/white
      draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, name, 0/black 0xf/white
    }
    y <- add 2/channel-padding
    i <- increment
    loop
  }
}

fn render-item-list screen: (addr screen), _env: (addr environment), items: (addr item-list), channels: (addr array channel), users: (addr array user) {
  var env/esi: (addr environment) <- copy _env
  var tmp-width/eax: int <- copy 0
  var tmp-height/ecx: int <- copy 0
  tmp-width, tmp-height <- screen-size screen
  var screen-width: int
  copy-to screen-width, tmp-width
  var screen-height: int
  copy-to screen-height, tmp-height
  #
  var tabs-ah/eax: (addr handle array tab) <- get env, tabs
  var _tabs/eax: (addr array tab) <- lookup *tabs-ah
  var tabs/edx: (addr array tab) <- copy _tabs
  var current-tab-index-a/eax: (addr int) <- get env, current-tab-index
  var current-tab-index/eax: int <- copy *current-tab-index-a
  var current-tab-offset/eax: (offset tab) <- compute-offset tabs, current-tab-index
  var current-tab/edx: (addr tab) <- index tabs, current-tab-offset
  var show-cursor?: boolean
  {
    var cursor-in-search?/eax: (addr boolean) <- get env, cursor-in-search?
    compare *cursor-in-search?, 0/false
    break-if-!=
    var cursor-in-channels?/eax: (addr boolean) <- get env, cursor-in-channels?
    compare *cursor-in-channels?, 0/false
    break-if-!=
    copy-to show-cursor?, 1/true
  }
  render-tab screen, current-tab, show-cursor?, items, channels, users, screen-height
  var top/eax: int <- copy screen-height
  top <- subtract 2/menu-space-ver
  clear-rect screen, 0 top, screen-width screen-height, 0/bg
}

fn render-tab screen: (addr screen), _current-tab: (addr tab), show-cursor?: boolean, items: (addr item-list), channels: (addr array channel), users: (addr array user), screen-height: int {
  var current-tab/esi: (addr tab) <- copy _current-tab
  var current-tab-type/eax: (addr int) <- get current-tab, type
  compare *current-tab-type, 0/all-items
  {
    break-if-!=
    render-all-items screen, current-tab, show-cursor?, items, users, screen-height
    return
  }
  compare *current-tab-type, 1/channel
  {
    break-if-!=
    render-channel-tab screen, current-tab, show-cursor?, items, channels, users, screen-height
    return
  }
  compare *current-tab-type, 2/search
  {
    break-if-!=
    render-search-tab screen, current-tab, show-cursor?, items, channels, users, screen-height
    return
  }
  compare *current-tab-type, 3/thread
  {
    break-if-!=
    render-thread-tab screen, current-tab, show-cursor?, items, channels, users, screen-height
    return
  }
}

fn render-all-items screen: (addr screen), _current-tab: (addr tab), show-cursor?: boolean, _items: (addr item-list), users: (addr array user), screen-height: int {
  var current-tab/esi: (addr tab) <- copy _current-tab
  var items/edi: (addr item-list) <- copy _items
  var newest-item/eax: (addr int) <- get current-tab, item-index
  var i/ebx: int <- copy *newest-item
  var items-data-first-free-addr/eax: (addr int) <- get items, data-first-free
  render-progress screen, i, *items-data-first-free-addr
  var items-data-ah/eax: (addr handle array item) <- get items, data
  var _items-data/eax: (addr array item) <- lookup *items-data-ah
  var items-data/edi: (addr array item) <- copy _items-data
  var y/ecx: int <- copy 2/search-space-ver
  y <- add 1/item-padding-ver
  {
    compare i, 0
    break-if-<
    compare y, screen-height
    break-if->=
    var offset/eax: (offset item) <- compute-offset items-data, i
    var curr-item/eax: (addr item) <- index items-data, offset
    y <- render-item screen, curr-item, users, show-cursor?, y, screen-height
    # cursor always at top item
    copy-to show-cursor?, 0/false
    i <- decrement
    loop
  }
}

fn render-channel-tab screen: (addr screen), _current-tab: (addr tab), show-cursor?: boolean, _items: (addr item-list), _channels: (addr array channel), users: (addr array user), screen-height: int {
  var current-tab/esi: (addr tab) <- copy _current-tab
  var items/edi: (addr item-list) <- copy _items
  var channels/ebx: (addr array channel) <- copy _channels
  var channel-index-addr/eax: (addr int) <- get current-tab, channel-index
  var channel-index/eax: int <- copy *channel-index-addr
  var channel-offset/eax: (offset channel) <- compute-offset channels, channel-index
  var current-channel/ecx: (addr channel) <- index channels, channel-offset
  var current-channel-posts-ah/eax: (addr handle array int) <- get current-channel, posts
  var _current-channel-posts/eax: (addr array int) <- lookup *current-channel-posts-ah
  var current-channel-posts/edx: (addr array int) <- copy _current-channel-posts
  var current-channel-first-channel-item-addr/eax: (addr int) <- get current-tab, item-index
  var i/ebx: int <- copy *current-channel-first-channel-item-addr
  var current-channel-posts-first-free-addr/eax: (addr int) <- get current-channel, posts-first-free
  set-cursor-position 0/screen, 0x68/x 0/y
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, "channel", 7/fg 0/bg
  render-progress screen, i, *current-channel-posts-first-free-addr
  var items-data-ah/eax: (addr handle array item) <- get items, data
  var _items-data/eax: (addr array item) <- lookup *items-data-ah
  var items-data/edi: (addr array item) <- copy _items-data
  var y/ecx: int <- copy 2/search-space-ver
  y <- add 1/item-padding-ver
  {
    compare i, 0
    break-if-<
    compare y, screen-height
    break-if->=
    var item-index-addr/eax: (addr int) <- index current-channel-posts, i
    var item-index/eax: int <- copy *item-index-addr
    var item-offset/eax: (offset item) <- compute-offset items-data, item-index
    var curr-item/eax: (addr item) <- index items-data, item-offset
    y <- render-item screen, curr-item, users, show-cursor?, y, screen-height
    # cursor always at top item
    copy-to show-cursor?, 0/false
    i <- decrement
    loop
  }
}

fn render-search-tab screen: (addr screen), _current-tab: (addr tab), show-cursor?: boolean, _items: (addr item-list), channels: (addr array channel), users: (addr array user), screen-height: int {
  var current-tab/esi: (addr tab) <- copy _current-tab
  var items/edi: (addr item-list) <- copy _items
  var current-tab-search-items-ah/eax: (addr handle array int) <- get current-tab, search-items
  var _current-tab-search-items/eax: (addr array int) <- lookup *current-tab-search-items-ah
  var current-tab-search-items/ebx: (addr array int) <- copy _current-tab-search-items
  var current-tab-top-item-addr/eax: (addr int) <- get current-tab, item-index
  var i/edx: int <- copy *current-tab-top-item-addr
  var current-tab-search-items-first-free-addr/eax: (addr int) <- get current-tab, search-items-first-free
  set-cursor-position 0/screen, 0x68/x 0/y
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, "search", 7/fg 0/bg
  render-progress screen, i, *current-tab-search-items-first-free-addr
  {
    compare *current-tab-search-items-first-free-addr, 0x100/max-search-results
    break-if-<
    set-cursor-position 0/screen, 0x68/x 1/y
    draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, "too many results", 4/fg 0/bg
  }
  var items-data-ah/eax: (addr handle array item) <- get items, data
  var _items-data/eax: (addr array item) <- lookup *items-data-ah
  var items-data/edi: (addr array item) <- copy _items-data
  var y/ecx: int <- copy 2/search-space-ver
  y <- add 1/item-padding-ver
  {
    compare i, 0
    break-if-<
    compare y, screen-height
    break-if->=
    var item-index-addr/eax: (addr int) <- index current-tab-search-items, i
    var item-index/eax: int <- copy *item-index-addr
    var item-offset/eax: (offset item) <- compute-offset items-data, item-index
    var curr-item/eax: (addr item) <- index items-data, item-offset
    y <- render-item screen, curr-item, users, show-cursor?, y, screen-height
    # cursor always at top item
    copy-to show-cursor?, 0/false
    i <- decrement
    loop
  }
}

fn render-thread-tab screen: (addr screen), _current-tab: (addr tab), show-cursor?: boolean, _items: (addr item-list), channels: (addr array channel), users: (addr array user), screen-height: int {
  var current-tab/esi: (addr tab) <- copy _current-tab
  var items/eax: (addr item-list) <- copy _items
  var items-data-ah/eax: (addr handle array item) <- get items, data
  var _items-data/eax: (addr array item) <- lookup *items-data-ah
  var items-data/edi: (addr array item) <- copy _items-data
  var post-index-addr/eax: (addr int) <- get current-tab, root-index
  var post-index/eax: int <- copy *post-index-addr
  var post-offset/eax: (offset item) <- compute-offset items-data, post-index
  var post/ebx: (addr item) <- index items-data, post-offset
  var current-tab-top-item-addr/eax: (addr int) <- get current-tab, item-index
  var i/edx: int <- copy *current-tab-top-item-addr
  var post-comments-first-free-addr/eax: (addr int) <- get post, comments-first-free
  set-cursor-position 0/screen, 0x68/x 0/y
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, "thread", 7/fg 0/bg
  render-progress screen, i, *post-comments-first-free-addr
  var post-comments-ah/eax: (addr handle array int) <- get post, comments
  var post-comments/eax: (addr array int) <- lookup *post-comments-ah
  var y/ecx: int <- copy 2/search-space-ver
  y <- add 1/item-padding-ver
  {
    compare i, 0
    break-if-<
    compare y, screen-height
    break-if->=
    var item-index-addr/eax: (addr int) <- index post-comments, i
    var item-index/eax: int <- copy *item-index-addr
    var item-offset/eax: (offset item) <- compute-offset items-data, item-index
    var curr-item/eax: (addr item) <- index items-data, item-offset
    y <- render-item screen, curr-item, users, show-cursor?, y, screen-height
    # cursor always at top item
    copy-to show-cursor?, 0/false
    i <- decrement
    loop
  }
  # finally render the parent -- though we'll never focus on it
  y <- render-item screen, post, users, 0/no-cursor, y, screen-height
}

# side-effect: mutates cursor position
fn render-progress screen: (addr screen), curr: int, max: int {
  set-cursor-position 0/screen, 0x70/x 0/y
  var top-index/eax: int <- copy max
  top-index <- subtract curr  # happy accident: 1-based
  draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen screen, top-index, 7/fg 0/bg
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, "/", 7/fg 0/bg
  draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen screen, max, 7/fg 0/bg
}

fn render-search-input screen: (addr screen), _env: (addr environment) {
  var env/esi: (addr environment) <- copy _env
  var cursor-in-search?/ecx: (addr boolean) <- get env, cursor-in-search?
  set-cursor-position 0/screen, 0x22/x=search-position-x 1/y
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, "search ", 7/fg 0/bg
  var search-terms-ah/eax: (addr handle gap-buffer) <- get env, search-terms
  var search-terms/eax: (addr gap-buffer) <- lookup *search-terms-ah
  rewind-gap-buffer search-terms
  var x/eax: int <- render-gap-buffer screen, search-terms, 0x2a/x 1/y, *cursor-in-search?, 0xf/fg 0/bg
  {
    compare x, 0x4a/end-search
    break-if->
    var y/ecx: int <- copy 0
    x, y <- render-grapheme screen, 0x5f/underscore, 0/xmin 1/ymin, 0x80/xmax, 1/ymax, x, 1/y, 0xf/fg 0/bg
    loop
  }
}

# not used in search mode
fn render-menu screen: (addr screen), _env: (addr environment) {
  var env/edi: (addr environment) <- copy _env
  {
    var cursor-in-search?/eax: (addr boolean) <- get env, cursor-in-search?
    compare *cursor-in-search?, 0/false
    break-if-=
    render-search-menu screen, env
    return
  }
  var cursor-in-channels?/eax: (addr boolean) <- get env, cursor-in-channels?
  compare *cursor-in-channels?, 0/false
  {
    break-if-=
    render-channels-menu screen, env
    return
  }
  render-main-menu screen, env
}

fn render-main-menu screen: (addr screen), _env: (addr environment) {
  var width/eax: int <- copy 0
  var y/ecx: int <- copy 0
  width, y <- screen-size screen
  y <- decrement
  set-cursor-position screen, 2/x, y
  {
    var env/edi: (addr environment) <- copy _env
    var num-tabs/edi: (addr int) <- get env, current-tab-index
    compare *num-tabs, 0
    break-if-<=
    draw-text-rightward-from-cursor screen, " Esc ", width, 0/fg 0xf/bg
    draw-text-rightward-from-cursor screen, " go back  ", width, 0xf/fg, 0/bg
  }
  draw-text-rightward-from-cursor screen, " Enter ", width, 0/fg 0xf/bg
  draw-text-rightward-from-cursor screen, " go to thread  ", width, 0xf/fg, 0/bg
  draw-text-rightward-from-cursor screen, " / ", width, 0/fg 0xf/bg
  draw-text-rightward-from-cursor screen, " search  ", width, 0xf/fg, 0/bg
  draw-text-rightward-from-cursor screen, " Tab ", width, 0/fg 0xf/bg
  draw-text-rightward-from-cursor screen, " go to channels  ", width, 0xf/fg, 0/bg
  draw-text-rightward-from-cursor screen, " ^b ", width, 0/fg 0xf/bg
  draw-text-rightward-from-cursor screen, " << page  ", width, 0xf/fg, 0/bg
  draw-text-rightward-from-cursor screen, " ^f ", width, 0/fg 0xf/bg
  draw-text-rightward-from-cursor screen, " page >>  ", width, 0xf/fg, 0/bg
}

fn render-channels-menu screen: (addr screen), _env: (addr environment) {
  var width/eax: int <- copy 0
  var y/ecx: int <- copy 0
  width, y <- screen-size screen
  y <- decrement
  set-cursor-position screen, 2/x, y
  {
    var env/edi: (addr environment) <- copy _env
    var num-tabs/edi: (addr int) <- get env, current-tab-index
    compare *num-tabs, 0
    break-if-<=
    draw-text-rightward-from-cursor screen, " Esc ", width, 0/fg 0xf/bg
    draw-text-rightward-from-cursor screen, " go back  ", width, 0xf/fg, 0/bg
  }
  draw-text-rightward-from-cursor screen, " / ", width, 0/fg 0xf/bg
  draw-text-rightward-from-cursor screen, " search  ", width, 0xf/fg, 0/bg
  draw-text-rightward-from-cursor screen, " Tab ", width, 0/fg 0xf/bg
  draw-text-rightward-from-cursor screen, " go to items  ", width, 0xf/fg, 0/bg
  draw-text-rightward-from-cursor screen, " Enter ", width, 0/fg 0xf/bg
  draw-text-rightward-from-cursor screen, " select  ", width, 0xf/fg, 0/bg
}

fn render-search-menu screen: (addr screen), _env: (addr environment) {
  var width/eax: int <- copy 0
  var y/ecx: int <- copy 0
  width, y <- screen-size screen
  y <- decrement
  set-cursor-position screen, 2/x, y
  draw-text-rightward-from-cursor screen, " Esc ", width, 0/fg 0xf/bg
  draw-text-rightward-from-cursor screen, " cancel  ", width, 0xf/fg, 0/bg
  draw-text-rightward-from-cursor screen, " Enter ", width, 0/fg 0xf/bg
  draw-text-rightward-from-cursor screen, " select  ", width, 0xf/fg, 0/bg
  draw-text-rightward-from-cursor screen, " ^a ", width, 0/fg, 0xf/bg
  draw-text-rightward-from-cursor screen, " <<  ", width, 0xf/fg, 0/bg
  draw-text-rightward-from-cursor screen, " ^b ", width, 0/fg, 0xf/bg
  draw-text-rightward-from-cursor screen, " <word  ", width, 0xf/fg, 0/bg
  draw-text-rightward-from-cursor screen, " ^f ", width, 0/fg, 0xf/bg
  draw-text-rightward-from-cursor screen, " word>  ", width, 0xf/fg, 0/bg
  draw-text-rightward-from-cursor screen, " ^e ", width, 0/fg, 0xf/bg
  draw-text-rightward-from-cursor screen, " >>  ", width, 0xf/fg, 0/bg
  draw-text-rightward-from-cursor screen, " ^u ", width, 0/fg, 0xf/bg
  draw-text-rightward-from-cursor screen, " clear  ", width, 0xf/fg, 0/bg
}

fn render-item screen: (addr screen), _item: (addr item), _users: (addr array user), show-cursor?: boolean, y: int, screen-height: int -> _/ecx: int {
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
  {
    var author-real-name-ah/eax: (addr handle array byte) <- get author, real-name
    var author-real-name/eax: (addr array byte) <- lookup *author-real-name-ah
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
  var text-y/eax: int <- render-slack-message screen, text, show-cursor?, y, screen-height
  # flush
  add-to y, 6/avatar-space-ver
  compare y, text-y
  {
    break-if-<
    return y
  }
  return text-y
}

fn render-slack-message screen: (addr screen), text: (addr array byte), highlight?: boolean, ymin: int, ymax: int -> _/eax: int {
  var x/eax: int <- copy 0x20/main-panel-hor
  x <- add 0x10/avatar-space-hor
  var y/ecx: int <- copy ymin
  y <- add 1/author-name-padding-ver
  $render-slack-message:draw: {
    compare highlight?, 0/false
    {
      break-if-=
      x, y <- draw-json-text-wrapping-right-then-down screen, text, x y, 0x70/xmax=post-right-coord ymax, x y, 0/fg 7/bg
      break $render-slack-message:draw
    }
    x, y <- draw-json-text-wrapping-right-then-down screen, text, x y, 0x70/xmax=post-right-coord ymax, x y, 7/fg 0/bg
  }
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
# https://www.json.org/json-en.html
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

fn update-environment _env: (addr environment), key: byte, users: (addr array user), channels: (addr array channel), items: (addr item-list) {
  var env/edi: (addr environment) <- copy _env
  # first dispatch to search mode if necessary
  {
    var cursor-in-search?/eax: (addr boolean) <- get env, cursor-in-search?
    compare *cursor-in-search?, 0/false
    break-if-=
    update-search env, key, users, channels, items
    return
  }
  {
    compare key, 0x2f/slash
    break-if-!=
    # enter search mode
    var cursor-in-search?/eax: (addr boolean) <- get env, cursor-in-search?
    copy-to *cursor-in-search?, 1/true
    # do one more repaint
    var dirty?/eax: (addr boolean) <- get env, dirty?
    copy-to *dirty?, 1/true
    return
  }
  {
    compare key, 0x1b/esc
    break-if-!=
    # back in history
    previous-tab env
    return
  }
  var cursor-in-channels?/eax: (addr boolean) <- get env, cursor-in-channels?
  {
    compare key, 9/tab
    break-if-!=
    # toggle cursor between main panel and channels nav
    not *cursor-in-channels?
    return
  }
  {
    compare *cursor-in-channels?, 0/false
    break-if-!=
    update-main-panel env, key, users, channels, items
    return
  }
  {
    compare *cursor-in-channels?, 0/false
    break-if-=
    update-channels-nav env, key, users, channels, items
    return
  }
}

fn update-main-panel env: (addr environment), key: byte, users: (addr array user), channels: (addr array channel), items: (addr item-list) {
  {
    compare key, 0xa/newline
    break-if-!=
    new-thread-tab env, users, channels, items
    return
  }
  {
    compare key, 0x81/down-arrow
    break-if-!=
    next-item env, users, channels, items
    return
  }
  {
    compare key, 0x82/up-arrow
    break-if-!=
    previous-item env, users, channels, items
    return
  }
  {
    compare key, 6/ctrl-f
    break-if-!=
    page-down env, users, channels, items
    return
  }
  {
    compare key, 2/ctrl-b
    break-if-!=
    page-up env, users, channels, items
    return
  }
}

# TODO: clamp cursor within bounds
fn update-channels-nav _env: (addr environment), key: byte, users: (addr array user), channels: (addr array channel), items: (addr item-list) {
  var env/edi: (addr environment) <- copy _env
  var channel-cursor-index/eax: (addr int) <- get env, channel-cursor-index
  {
    compare key, 0x81/down-arrow
    break-if-!=
    increment *channel-cursor-index
    return
  }
  {
    compare key, 0x82/up-arrow
    break-if-!=
    decrement *channel-cursor-index
    return
  }
  {
    compare key, 0xa/newline
    break-if-!=
    new-channel-tab env, *channel-cursor-index, channels
    var cursor-in-channels?/eax: (addr boolean) <- get env, cursor-in-channels?
    copy-to *cursor-in-channels?, 0/false
    return
  }
}

fn update-search _env: (addr environment), key: byte, users: (addr array user), channels: (addr array channel), items: (addr item-list) {
  var env/edi: (addr environment) <- copy _env
  var cursor-in-search?/eax: (addr boolean) <- get env, cursor-in-search?
  {
    compare key 0x1b/esc
    break-if-!=
    # get out of search mode
    copy-to *cursor-in-search?, 0/false
    return
  }
  {
    compare key, 0xa/newline
    break-if-!=
    # perform a search, then get out of search mode
    new-search-tab env, items
    copy-to *cursor-in-search?, 0/false
    return
  }
  # otherwise delegate
  var search-terms-ah/eax: (addr handle gap-buffer) <- get env, search-terms
  var search-terms/eax: (addr gap-buffer) <- lookup *search-terms-ah
  var g/ecx: grapheme <- copy key
  edit-gap-buffer search-terms, g
}

fn new-thread-tab _env: (addr environment), users: (addr array user), channels: (addr array channel), _items: (addr item-list) {
  var env/edi: (addr environment) <- copy _env
  var current-tab-index-a/ecx: (addr int) <- get env, current-tab-index
  var tabs-ah/eax: (addr handle array tab) <- get env, tabs
  var tabs/eax: (addr array tab) <- lookup *tabs-ah
  var current-tab-index/ecx: int <- copy *current-tab-index-a
  var current-tab-offset/ecx: (offset tab) <- compute-offset tabs, current-tab-index
  var current-tab/ecx: (addr tab) <- index tabs, current-tab-offset
  var item-index/esi: int <- item-index current-tab, channels
  var post-index/ecx: int <- post-index _items, item-index
  var current-tab-index-addr/eax: (addr int) <- get env, current-tab-index
  increment *current-tab-index-addr
  var current-tab-index/edx: int <- copy *current-tab-index-addr
  var tabs-ah/eax: (addr handle array tab) <- get env, tabs
  var tabs/eax: (addr array tab) <- lookup *tabs-ah
  var max-tabs/ebx: int <- length tabs
  compare current-tab-index, max-tabs
  {
    compare current-tab-index, max-tabs
    break-if-<
    abort "history overflow; grow max-history (we should probably improve this)"
  }
  var current-tab-offset/edi: (offset tab) <- compute-offset tabs, current-tab-index
  var current-tab/edi: (addr tab) <- index tabs, current-tab-offset
  clear-object current-tab
  var current-tab-type/eax: (addr int) <- get current-tab, type
  copy-to *current-tab, 3/thread
  var current-tab-root-index/eax: (addr int) <- get current-tab, root-index
  copy-to *current-tab-root-index, post-index
  var items/eax: (addr item-list) <- copy _items
  var items-data-ah/eax: (addr handle array item) <- get items, data
  var items-data/eax: (addr array item) <- lookup *items-data-ah
  var offset/ecx: (offset item) <- compute-offset items-data, post-index
  var post/eax: (addr item) <- index items-data, offset
  var post-comments-first-free-addr/ecx: (addr int) <- get post, comments-first-free
  # terminology:
  #   post-comment-index = index of a comment in a post's comment array
  #   comment-index = index of a comment in the global item list
  var final-post-comment-index/ecx: int <- copy *post-comments-first-free-addr
  final-post-comment-index <- decrement
  var post-comments-ah/eax: (addr handle array int) <- get post, comments
  var post-comments/eax: (addr array int) <- lookup *post-comments-ah
  # look for item-index in post-comments[0..final-post-comment-index]
  var curr-post-comment-index/edx: int <- copy final-post-comment-index
  {
    compare curr-post-comment-index, 0
    {
      break-if->=
      # if we didn't find the current item in a post's comments, it must be
      # the parent post itself which isn't in the comment list but hackily
      # rendered at the bottom. Just render the whole comment list.
      var tab-item-index-addr/edi: (addr int) <- get current-tab, item-index
      copy-to *tab-item-index-addr, curr-post-comment-index
      return
    }
    var curr-comment-index/ecx: (addr int) <- index post-comments, curr-post-comment-index
    compare *curr-comment-index, item-index
    {
      break-if-!=
      # item-index found
      var tab-item-index-addr/edi: (addr int) <- get current-tab, item-index
      copy-to *tab-item-index-addr, curr-post-comment-index
      return
    }
    curr-post-comment-index <- decrement
    loop
  }
  abort "new-thread-tab: should never leave previous loop without returning"
}

fn item-index _tab: (addr tab), _channels: (addr array channel) -> _/esi: int {
  var tab/esi: (addr tab) <- copy _tab
  var tab-type/eax: (addr int) <- get tab, type
  {
    compare *tab-type, 0/all-items
    break-if-!=
    var tab-item-index/eax: (addr int) <- get tab, item-index
    return *tab-item-index
  }
  {
    compare *tab-type, 1/channel
    break-if-!=
    var channel-index-addr/eax: (addr int) <- get tab, channel-index
    var channel-index/eax: int <- copy *channel-index-addr
    var channels/ecx: (addr array channel) <- copy _channels
    var channel-offset/eax: (offset channel) <- compute-offset channels, channel-index
    var current-channel/eax: (addr channel) <- index channels, channel-offset
    var current-channel-posts-ah/eax: (addr handle array int) <- get current-channel, posts
    var current-channel-posts/eax: (addr array int) <- lookup *current-channel-posts-ah
    var channel-item-index-addr/ecx: (addr int) <- get tab, item-index
    var channel-item-index/ecx: int <- copy *channel-item-index-addr
    var channel-item-index/eax: (addr int) <- index current-channel-posts, channel-item-index
    return *channel-item-index
  }
  {
    compare *tab-type, 2/search
    break-if-!=
    var tab-search-items-ah/eax: (addr handle array int) <- get tab, search-items
    var tab-search-items/eax: (addr array int) <- lookup *tab-search-items-ah
    var tab-search-items-index-addr/ecx: (addr int) <- get tab, item-index
    var tab-search-items-index/ecx: int <- copy *tab-search-items-index-addr
    var src/eax: (addr int) <- index tab-search-items, tab-search-items-index
    return *src
  }
  abort "item-index: unknown tab type"
  return -1
}

fn post-index _items: (addr item-list), item-index: int -> _/ecx: int {
  var items/eax: (addr item-list) <- copy _items
  var items-data-ah/eax: (addr handle array item) <- get items, data
  var items-data/eax: (addr array item) <- lookup *items-data-ah
  var index/ecx: int <- copy item-index
  var offset/ecx: (offset item) <- compute-offset items-data, index
  var item/eax: (addr item) <- index items-data, offset
  var parent/eax: (addr int) <- get item, parent
  compare *parent, 0
  {
    break-if-=
    return *parent
  }
  return item-index
}

fn new-channel-tab _env: (addr environment), channel-index: int, _channels: (addr array channel) {
  var env/edi: (addr environment) <- copy _env
  var current-tab-index-addr/eax: (addr int) <- get env, current-tab-index
  increment *current-tab-index-addr
  var current-tab-index/ecx: int <- copy *current-tab-index-addr
  var tabs-ah/eax: (addr handle array tab) <- get env, tabs
  var tabs/eax: (addr array tab) <- lookup *tabs-ah
  var max-tabs/edx: int <- length tabs
  compare current-tab-index, max-tabs
  {
    compare current-tab-index, max-tabs
    break-if-<
    abort "history overflow; grow max-history (we should probably improve this)"
  }
  var current-tab-offset/ecx: (offset tab) <- compute-offset tabs, current-tab-index
  var current-tab/ecx: (addr tab) <- index tabs, current-tab-offset
  clear-object current-tab
  var current-tab-type/eax: (addr int) <- get current-tab, type
  copy-to *current-tab, 1/channel
  var current-tab-channel-index/eax: (addr int) <- get current-tab, channel-index
  var curr-channel-index/edx: int <- copy channel-index
  copy-to *current-tab-channel-index, curr-channel-index
  var channels/esi: (addr array channel) <- copy _channels
  var curr-channel-offset/eax: (offset channel) <- compute-offset channels, curr-channel-index
  var curr-channel/eax: (addr channel) <- index channels, curr-channel-offset
  var curr-channel-posts-first-free-addr/eax: (addr int) <- get curr-channel, posts-first-free
  var curr-channel-final-post-index/eax: int <- copy *curr-channel-posts-first-free-addr
  curr-channel-final-post-index <- decrement
  var dest/edi: (addr int) <- get current-tab, item-index
  copy-to *dest, curr-channel-final-post-index
}

fn new-search-tab _env: (addr environment), items: (addr item-list) {
  var env/edi: (addr environment) <- copy _env
  var current-tab-index-addr/eax: (addr int) <- get env, current-tab-index
  increment *current-tab-index-addr
  var current-tab-index/ecx: int <- copy *current-tab-index-addr
  var tabs-ah/eax: (addr handle array tab) <- get env, tabs
  var tabs/eax: (addr array tab) <- lookup *tabs-ah
  var max-tabs/edx: int <- length tabs
  compare current-tab-index, max-tabs
  {
    compare current-tab-index, max-tabs
    break-if-<
    abort "history overflow; grow max-history (we should probably improve this)"
  }
  var current-tab-offset/ecx: (offset tab) <- compute-offset tabs, current-tab-index
  var current-tab/ecx: (addr tab) <- index tabs, current-tab-offset
  clear-object current-tab
  var current-tab-type/eax: (addr int) <- get current-tab, type
  copy-to *current-tab, 2/search
  var current-tab-search-terms-ah/edx: (addr handle gap-buffer) <- get current-tab, search-terms
  allocate current-tab-search-terms-ah
  var current-tab-search-terms/eax: (addr gap-buffer) <- lookup *current-tab-search-terms-ah
  initialize-gap-buffer current-tab-search-terms, 0x30/search-capacity
  var search-terms-ah/ebx: (addr handle gap-buffer) <- get env, search-terms
  copy-gap-buffer search-terms-ah, current-tab-search-terms-ah
  var search-terms/eax: (addr gap-buffer) <- lookup *search-terms-ah
  search-items current-tab, items, search-terms
}

fn search-items _tab: (addr tab), _items: (addr item-list), search-terms: (addr gap-buffer) {
  var tab/edi: (addr tab) <- copy _tab
  var tab-items-first-free-addr/esi: (addr int) <- get tab, search-items-first-free
  var tab-items-ah/eax: (addr handle array int) <- get tab, search-items
  populate tab-items-ah, 0x100/max-search-results
  var _tab-items/eax: (addr array int) <- lookup *tab-items-ah
  var tab-items/edi: (addr array int) <- copy _tab-items
  # preprocess search-terms
  var search-terms-stream-storage: (stream byte 0x100)
  var search-terms-stream-addr/ecx: (addr stream byte) <- address search-terms-stream-storage
  emit-gap-buffer search-terms, search-terms-stream-addr
  var search-terms-text-h: (handle array byte)
  var search-terms-text-ah/eax: (addr handle array byte) <- address search-terms-text-h
  stream-to-array search-terms-stream-addr, search-terms-text-ah
  var tmp/eax: (addr array byte) <- lookup *search-terms-text-ah
  var search-terms-text: (addr array byte)
  copy-to search-terms-text, tmp
  #
  var items/ecx: (addr item-list) <- copy _items
  var items-data-ah/eax: (addr handle array item) <- get items, data
  var _items-data/eax: (addr array item) <- lookup *items-data-ah
  var items-data/ebx: (addr array item) <- copy _items-data
  var items-data-first-free-a/edx: (addr int) <- get items, data-first-free
  var i/ecx: int <- copy 0
  {
    compare i, *items-data-first-free-a
    break-if->=
    var curr-offset/eax: (offset item) <- compute-offset items-data, i
    var curr-item/eax: (addr item) <- index items-data, curr-offset
    var found?/eax: boolean <- search-terms-match? curr-item, search-terms-text
    compare found?, 0/false
    {
      break-if-=
      var tab-items-first-free/eax: int <- copy *tab-items-first-free-addr
      compare tab-items-first-free, 0x100/max-search-results
      break-if->=
      var dest/eax: (addr int) <- index tab-items, tab-items-first-free
      copy-to *dest, i
      increment *tab-items-first-free-addr
    }
    i <- increment
    loop
  }
  var tab/edi: (addr tab) <- copy _tab
  var tab-item-index-addr/edi: (addr int) <- get tab, item-index
  var tab-items-first-free/eax: int <- copy *tab-items-first-free-addr
  tab-items-first-free <- decrement
  copy-to *tab-item-index-addr, tab-items-first-free
}

fn search-terms-match? _item: (addr item), search-terms: (addr array byte) -> _/eax: boolean {
  var item/esi: (addr item) <- copy _item
  var item-text-ah/eax: (addr handle array byte) <- get item, text
  var item-text/eax: (addr array byte) <- lookup *item-text-ah
  var i/ecx: int <- copy 0
  var max/edx: int <- length item-text
  var search-terms2/ebx: (addr array byte) <- copy search-terms
  var slen/ebx: int <- length search-terms2
  max <- subtract slen
  {
    compare i, max
    break-if->
    var found?/eax: boolean <- substring-match? item-text, search-terms, i
    compare found?, 0/false
    {
      break-if-=
      return 1/true
    }
    i <- increment
    loop
  }
  return 0/false
}

fn substring-match? _s: (addr array byte), _pat: (addr array byte), start: int -> _/eax: boolean {
  var s/esi: (addr array byte) <- copy _s
  var pat/edi: (addr array byte) <- copy _pat
  var s-idx/edx: int <- copy start
  var pat-idx/ebx: int <- copy 0
  var pat-len: int
  var tmp/eax: int <- length pat
  copy-to pat-len, tmp
  {
    compare pat-idx, pat-len
    break-if->=
    var s-ab/eax: (addr byte) <- index s, s-idx
    var s-b/eax: byte <- copy-byte *s-ab
    var pat-ab/ecx: (addr byte) <- index pat, pat-idx
    var pat-b/ecx: byte <- copy-byte *pat-ab
    compare s-b, pat-b
    {
      break-if-=
      return 0/false
    }
    s-idx <- increment
    pat-idx <- increment
    loop
  }
  return 1/true
}

fn previous-tab _env: (addr environment) {
  var env/edi: (addr environment) <- copy _env
  var current-tab-index-addr/ecx: (addr int) <- get env, current-tab-index
  compare *current-tab-index-addr, 0
  {
    break-if-<=
    decrement *current-tab-index-addr
    # if necessary restore search state
    var tabs-ah/eax: (addr handle array tab) <- get env, tabs
    var tabs/eax: (addr array tab) <- lookup *tabs-ah
    var current-tab-index/ecx: int <- copy *current-tab-index-addr
    var current-tab-offset/ecx: (offset tab) <- compute-offset tabs, current-tab-index
    var current-tab/ecx: (addr tab) <- index tabs, current-tab-offset
    var current-tab-type/eax: (addr int) <- get current-tab, type
    compare *current-tab-type, 2/search
    break-if-!=
    var current-tab-search-terms-ah/ecx: (addr handle gap-buffer) <- get current-tab, search-terms
    var search-terms-ah/edx: (addr handle gap-buffer) <- get env, search-terms
    var search-terms/eax: (addr gap-buffer) <- lookup *search-terms-ah
    clear-gap-buffer search-terms
    copy-gap-buffer current-tab-search-terms-ah, search-terms-ah
  }
}

fn next-item _env: (addr environment), users: (addr array user), channels: (addr array channel), _items: (addr item-list) {
  var env/edi: (addr environment) <- copy _env
  var tabs-ah/eax: (addr handle array tab) <- get env, tabs
  var _tabs/eax: (addr array tab) <- lookup *tabs-ah
  var tabs/edx: (addr array tab) <- copy _tabs
  var current-tab-index-a/eax: (addr int) <- get env, current-tab-index
  var current-tab-index/eax: int <- copy *current-tab-index-a
  var current-tab-offset/eax: (offset tab) <- compute-offset tabs, current-tab-index
  var current-tab/edx: (addr tab) <- index tabs, current-tab-offset
  var dest/eax: (addr int) <- get current-tab, item-index
  compare *dest, 0
  break-if-<=
  decrement *dest
}

fn previous-item _env: (addr environment), users: (addr array user), _channels: (addr array channel), _items: (addr item-list) {
  var env/edi: (addr environment) <- copy _env
  var tabs-ah/eax: (addr handle array tab) <- get env, tabs
  var _tabs/eax: (addr array tab) <- lookup *tabs-ah
  var tabs/edx: (addr array tab) <- copy _tabs
  var current-tab-index-a/eax: (addr int) <- get env, current-tab-index
  var current-tab-index/eax: int <- copy *current-tab-index-a
  var current-tab-offset/eax: (offset tab) <- compute-offset tabs, current-tab-index
  var current-tab/edx: (addr tab) <- index tabs, current-tab-offset
  var current-tab-type/eax: (addr int) <- get current-tab, type
  compare *current-tab-type, 0/all-items
  {
    break-if-!=
    var items/esi: (addr item-list) <- copy _items
    var items-data-first-free-a/ecx: (addr int) <- get items, data-first-free
    var final-item-index/ecx: int <- copy *items-data-first-free-a
    final-item-index <- decrement
    var dest/eax: (addr int) <- get current-tab, item-index
    compare *dest, final-item-index
    break-if->=
    increment *dest
    return
  }
  compare *current-tab-type, 1/channel
  {
    break-if-!=
    var current-channel-index-addr/eax: (addr int) <- get current-tab, channel-index
    var current-channel-index/eax: int <- copy *current-channel-index-addr
    var channels/esi: (addr array channel) <- copy _channels
    var current-channel-offset/eax: (offset channel) <- compute-offset channels, current-channel-index
    var current-channel/eax: (addr channel) <- index channels, current-channel-offset
    var current-channel-posts-first-free-addr/eax: (addr int) <- get current-channel, posts-first-free
    var final-item-index/ecx: int <- copy *current-channel-posts-first-free-addr
    final-item-index <- decrement
    var dest/eax: (addr int) <- get current-tab, item-index
    compare *dest, final-item-index
    break-if->=
    increment *dest
    return
  }
  compare *current-tab-type, 2/search
  {
    break-if-!=
    var current-tab-search-items-first-free-addr/eax: (addr int) <- get current-tab, search-items-first-free
    var final-item-index/ecx: int <- copy *current-tab-search-items-first-free-addr
    final-item-index <- decrement
    var dest/eax: (addr int) <- get current-tab, item-index
    compare *dest, final-item-index
    break-if->=
    increment *dest
    return
  }
  compare *current-tab-type, 3/thread
  {
    break-if-!=
    var items/eax: (addr item-list) <- copy _items
    var items-data-ah/eax: (addr handle array item) <- get items, data
    var _items-data/eax: (addr array item) <- lookup *items-data-ah
    var items-data/esi: (addr array item) <- copy _items-data
    var current-tab-root-index-addr/eax: (addr int) <- get current-tab, root-index
    var current-tab-root-index/eax: int <- copy *current-tab-root-index-addr
    var current-tab-root-offset/eax: (offset item) <- compute-offset items-data, current-tab-root-index
    var post/eax: (addr item) <- index items-data, current-tab-root-offset
    var post-comments-first-free-addr/ecx: (addr int) <- get post, comments-first-free
    var final-item-index/ecx: int <- copy *post-comments-first-free-addr
    final-item-index <- decrement
    var dest/eax: (addr int) <- get current-tab, item-index
    compare *dest, final-item-index
    break-if->=
    increment *dest
    return
  }
}

fn page-down _env: (addr environment), users: (addr array user), channels: (addr array channel), items: (addr item-list) {
  var env/edi: (addr environment) <- copy _env
  var tabs-ah/eax: (addr handle array tab) <- get env, tabs
  var _tabs/eax: (addr array tab) <- lookup *tabs-ah
  var tabs/ecx: (addr array tab) <- copy _tabs
  var current-tab-index-a/eax: (addr int) <- get env, current-tab-index
  var current-tab-index/eax: int <- copy *current-tab-index-a
  var current-tab-offset/eax: (offset tab) <- compute-offset tabs, current-tab-index
  var current-tab/edx: (addr tab) <- index tabs, current-tab-offset
  var current-tab-type/eax: (addr int) <- get current-tab, type
  compare *current-tab-type, 0/all-items
  {
    break-if-!=
    all-items-page-down current-tab, users, channels, items
    return
  }
  compare *current-tab-type, 1/channel
  {
    break-if-!=
    channel-page-down current-tab, users, channels, items
    return
  }
  compare *current-tab-type, 2/search
  {
    break-if-!=
    search-page-down current-tab, users, channels, items
    return
  }
  compare *current-tab-type, 3/thread
  {
    break-if-!=
    thread-page-down current-tab, users, channels, items
    return
  }
}

fn all-items-page-down _current-tab: (addr tab), users: (addr array user), channels: (addr array channel), _items: (addr item-list) {
  var items/esi: (addr item-list) <- copy _items
  var items-data-ah/eax: (addr handle array item) <- get items, data
  var _items-data/eax: (addr array item) <- lookup *items-data-ah
  var items-data/ebx: (addr array item) <- copy _items-data
  var current-tab/eax: (addr tab) <- copy _current-tab
  var current-tab-item-index-addr/edi: (addr int) <- get current-tab, item-index
  var new-item-index/ecx: int <- copy *current-tab-item-index-addr
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
    y <- add h
    new-item-index <- decrement
    loop
  }
  new-item-index <- increment
  {
    # HACK: make sure we make forward progress even if a single post takes up
    # the whole screen.
    # We can't see the rest of that single post at the moment. But at least we
    # can go past it.
    compare new-item-index, *current-tab-item-index-addr
    break-if-!=
    # Don't make "forward progress" past post 0.
    compare new-item-index, 0
    break-if-=
    new-item-index <- decrement
  }
  copy-to *current-tab-item-index-addr, new-item-index
}

fn channel-page-down _current-tab: (addr tab), users: (addr array user), _channels: (addr array channel), _items: (addr item-list) {
  var current-tab/edi: (addr tab) <- copy _current-tab
  var current-channel-index-addr/eax: (addr int) <- get current-tab, channel-index
  var current-channel-index/eax: int <- copy *current-channel-index-addr
  var channels/esi: (addr array channel) <- copy _channels
  var current-channel-offset/eax: (offset channel) <- compute-offset channels, current-channel-index
  var current-channel/esi: (addr channel) <- index channels, current-channel-offset
  var current-channel-posts-ah/eax: (addr handle array int) <- get current-channel, posts
  var _current-channel-posts/eax: (addr array int) <- lookup *current-channel-posts-ah
  var current-channel-posts/esi: (addr array int) <- copy _current-channel-posts
  var items/eax: (addr item-list) <- copy _items
  var items-data-ah/eax: (addr handle array item) <- get items, data
  var _items-data/eax: (addr array item) <- lookup *items-data-ah
  var items-data/ebx: (addr array item) <- copy _items-data
  var current-tab-item-index-addr/edi: (addr int) <- get current-tab, item-index
  var new-tab-item-index/ecx: int <- copy *current-tab-item-index-addr
  var y/edx: int <- copy 2
  {
    compare new-tab-item-index, 0
    break-if-<
    compare y, 0x28/screen-height-minus-menu
    break-if->=
    var current-item-index-addr/eax: (addr int) <- index current-channel-posts, new-tab-item-index
    var current-item-index/eax: int <- copy *current-item-index-addr
    var offset/eax: (offset item) <- compute-offset items-data, current-item-index
    var item/eax: (addr item) <- index items-data, offset
    var item-text-ah/eax: (addr handle array byte) <- get item, text
    var item-text/eax: (addr array byte) <- lookup *item-text-ah
    var h/eax: int <- estimate-height item-text
    y <- add h
    new-tab-item-index <- decrement
    loop
  }
  new-tab-item-index <- increment
  {
    # HACK: make sure we make forward progress even if a single post takes up
    # the whole screen.
    # We can't see the rest of that single post at the moment. But at least we
    # can go past it.
    compare new-tab-item-index, *current-tab-item-index-addr
    break-if-!=
    # Don't make "forward progress" past post 0.
    compare new-tab-item-index, 0
    break-if-=
    new-tab-item-index <- decrement
  }
  copy-to *current-tab-item-index-addr, new-tab-item-index
}

fn search-page-down _current-tab: (addr tab), users: (addr array user), channels: (addr array channel), _items: (addr item-list) {
  var current-tab/edi: (addr tab) <- copy _current-tab
  var current-tab-search-items-ah/eax: (addr handle array int) <- get current-tab, search-items
  var _current-tab-search-items/eax: (addr array int) <- lookup *current-tab-search-items-ah
  var current-tab-search-items/esi: (addr array int) <- copy _current-tab-search-items
  var items/eax: (addr item-list) <- copy _items
  var items-data-ah/eax: (addr handle array item) <- get items, data
  var _items-data/eax: (addr array item) <- lookup *items-data-ah
  var items-data/ebx: (addr array item) <- copy _items-data
  var current-tab-item-index-addr/edi: (addr int) <- get current-tab, item-index
  var new-tab-item-index/ecx: int <- copy *current-tab-item-index-addr
  var y/edx: int <- copy 2
  {
    compare new-tab-item-index, 0
    break-if-<
    compare y, 0x28/screen-height-minus-menu
    break-if->=
    var current-item-index-addr/eax: (addr int) <- index current-tab-search-items, new-tab-item-index
    var current-item-index/eax: int <- copy *current-item-index-addr
    var offset/eax: (offset item) <- compute-offset items-data, current-item-index
    var item/eax: (addr item) <- index items-data, offset
    var item-text-ah/eax: (addr handle array byte) <- get item, text
    var item-text/eax: (addr array byte) <- lookup *item-text-ah
    var h/eax: int <- estimate-height item-text
    y <- add h
    new-tab-item-index <- decrement
    loop
  }
  new-tab-item-index <- increment
  {
    # HACK: make sure we make forward progress even if a single post takes up
    # the whole screen.
    # We can't see the rest of that single post at the moment. But at least we
    # can go past it.
    compare new-tab-item-index, *current-tab-item-index-addr
    break-if-!=
    # Don't make "forward progress" past post 0.
    compare new-tab-item-index, 0
    break-if-=
    new-tab-item-index <- decrement
  }
  copy-to *current-tab-item-index-addr, new-tab-item-index
}

fn thread-page-down _current-tab: (addr tab), users: (addr array user), channels: (addr array channel), _items: (addr item-list) {
  var current-tab/edi: (addr tab) <- copy _current-tab
  var items/eax: (addr item-list) <- copy _items
  var items-data-ah/eax: (addr handle array item) <- get items, data
  var _items-data/eax: (addr array item) <- lookup *items-data-ah
  var items-data/esi: (addr array item) <- copy _items-data
  var current-tab-root-index-addr/eax: (addr int) <- get current-tab, root-index
  var current-tab-root-index/eax: int <- copy *current-tab-root-index-addr
  var current-tab-root-offset/eax: (offset item) <- compute-offset items-data, current-tab-root-index
  var post/eax: (addr item) <- index items-data, current-tab-root-offset
  var post-comments-ah/eax: (addr handle array int) <- get post, comments
  var _post-comments/eax: (addr array int) <- lookup *post-comments-ah
  var post-comments/ebx: (addr array int) <- copy _post-comments
  var current-tab-item-index-addr/edi: (addr int) <- get current-tab, item-index
  var new-tab-item-index/ecx: int <- copy *current-tab-item-index-addr
  var y/edx: int <- copy 2
  {
    compare new-tab-item-index, 0
    break-if-<
    compare y, 0x28/screen-height-minus-menu
    break-if->=
    var current-item-index-addr/eax: (addr int) <- index post-comments, new-tab-item-index
    var current-item-index/eax: int <- copy *current-item-index-addr
    var offset/eax: (offset item) <- compute-offset items-data, current-item-index
    var item/eax: (addr item) <- index items-data, offset
    var item-text-ah/eax: (addr handle array byte) <- get item, text
    var item-text/eax: (addr array byte) <- lookup *item-text-ah
    var h/eax: int <- estimate-height item-text
    y <- add h
    new-tab-item-index <- decrement
    loop
  }
  new-tab-item-index <- increment
  {
    # HACK: make sure we make forward progress even if a single post takes up
    # the whole screen.
    # We can't see the rest of that single post at the moment. But at least we
    # can go past it.
    compare new-tab-item-index, *current-tab-item-index-addr
    break-if-!=
    # Don't make "forward progress" past post 0.
    compare new-tab-item-index, 0
    break-if-=
    new-tab-item-index <- decrement
  }
  copy-to *current-tab-item-index-addr, new-tab-item-index
}

fn page-up _env: (addr environment), users: (addr array user), channels: (addr array channel), items: (addr item-list) {
  var env/edi: (addr environment) <- copy _env
  var tabs-ah/eax: (addr handle array tab) <- get env, tabs
  var _tabs/eax: (addr array tab) <- lookup *tabs-ah
  var tabs/ecx: (addr array tab) <- copy _tabs
  var current-tab-index-a/eax: (addr int) <- get env, current-tab-index
  var current-tab-index/eax: int <- copy *current-tab-index-a
  var current-tab-offset/eax: (offset tab) <- compute-offset tabs, current-tab-index
  var current-tab/edx: (addr tab) <- index tabs, current-tab-offset
  var current-tab-type/eax: (addr int) <- get current-tab, type
  compare *current-tab-type, 0/all-items
  {
    break-if-!=
    all-items-page-up current-tab, users, channels, items
    return
  }
  compare *current-tab-type, 1/channel
  {
    break-if-!=
    channel-page-up current-tab, users, channels, items
    return
  }
  compare *current-tab-type, 2/search
  {
    break-if-!=
    search-page-up current-tab, users, channels, items
    return
  }
  compare *current-tab-type, 3/thread
  {
    break-if-!=
    thread-page-up current-tab, users, channels, items
    return
  }
}

fn all-items-page-up _current-tab: (addr tab), users: (addr array user), channels: (addr array channel), _items: (addr item-list) {
  var items/esi: (addr item-list) <- copy _items
  var items-data-ah/eax: (addr handle array item) <- get items, data
  var _items-data/eax: (addr array item) <- lookup *items-data-ah
  var items-data/ebx: (addr array item) <- copy _items-data
  var items-data-first-free-a/eax: (addr int) <- get items, data-first-free
  var final-item-index/esi: int <- copy *items-data-first-free-a
  final-item-index <- decrement
  var current-tab/eax: (addr tab) <- copy _current-tab
  var current-tab-item-index-addr/edi: (addr int) <- get current-tab, item-index
  var new-item-index/ecx: int <- copy *current-tab-item-index-addr
  var y/edx: int <- copy 2
  {
    compare new-item-index, final-item-index
    break-if->
    compare y, 0x28/screen-height-minus-menu
    break-if->=
    var offset/eax: (offset item) <- compute-offset items-data, new-item-index
    var item/eax: (addr item) <- index items-data, offset
    var item-text-ah/eax: (addr handle array byte) <- get item, text
    var item-text/eax: (addr array byte) <- lookup *item-text-ah
    var h/eax: int <- estimate-height item-text
    y <- add h
    new-item-index <- increment
    loop
  }
  new-item-index <- decrement
  copy-to *current-tab-item-index-addr, new-item-index
}

fn channel-page-up _current-tab: (addr tab), users: (addr array user), _channels: (addr array channel), _items: (addr item-list) {
  var current-tab/edi: (addr tab) <- copy _current-tab
  var current-channel-index-addr/eax: (addr int) <- get current-tab, channel-index
  var current-channel-index/eax: int <- copy *current-channel-index-addr
  var channels/esi: (addr array channel) <- copy _channels
  var current-channel-offset/eax: (offset channel) <- compute-offset channels, current-channel-index
  var current-channel/esi: (addr channel) <- index channels, current-channel-offset
  var current-channel-posts-first-free-addr/eax: (addr int) <- get current-channel, posts-first-free
  var tmp/eax: int <- copy *current-channel-posts-first-free-addr
  var final-tab-post-index: int
  copy-to final-tab-post-index, tmp
  decrement final-tab-post-index
  var current-channel-posts-ah/eax: (addr handle array int) <- get current-channel, posts
  var _current-channel-posts/eax: (addr array int) <- lookup *current-channel-posts-ah
  var current-channel-posts/esi: (addr array int) <- copy _current-channel-posts
  var items/esi: (addr item-list) <- copy _items
  var items-data-ah/eax: (addr handle array item) <- get items, data
  var _items-data/eax: (addr array item) <- lookup *items-data-ah
  var items-data/ebx: (addr array item) <- copy _items-data
  var current-tab-item-index-addr/edi: (addr int) <- get current-tab, item-index
  var new-tab-item-index/ecx: int <- copy *current-tab-item-index-addr
  var y/edx: int <- copy 2
  {
    compare new-tab-item-index, final-tab-post-index
    break-if->
    compare y, 0x28/screen-height-minus-menu
    break-if->=
    var offset/eax: (offset item) <- compute-offset items-data, new-tab-item-index
    var item/eax: (addr item) <- index items-data, offset
    var item-text-ah/eax: (addr handle array byte) <- get item, text
    var item-text/eax: (addr array byte) <- lookup *item-text-ah
    var h/eax: int <- estimate-height item-text
    y <- add h
    new-tab-item-index <- increment
    loop
  }
  new-tab-item-index <- decrement
  copy-to *current-tab-item-index-addr, new-tab-item-index
}

fn search-page-up _current-tab: (addr tab), users: (addr array user), channels: (addr array channel), _items: (addr item-list) {
  var current-tab/edi: (addr tab) <- copy _current-tab
  var current-tab-search-items-first-free-addr/eax: (addr int) <- get current-tab, search-items-first-free
  var final-tab-post-index: int
  var tmp/eax: int <- copy *current-tab-search-items-first-free-addr
  copy-to final-tab-post-index, tmp
  decrement final-tab-post-index
  var current-tab-search-items-ah/eax: (addr handle array int) <- get current-tab, search-items
  var _current-tab-search-items/eax: (addr array int) <- lookup *current-tab-search-items-ah
  var current-tab-search-items/esi: (addr array int) <- copy _current-tab-search-items
  var items/eax: (addr item-list) <- copy _items
  var items-data-ah/eax: (addr handle array item) <- get items, data
  var _items-data/eax: (addr array item) <- lookup *items-data-ah
  var items-data/ebx: (addr array item) <- copy _items-data
  var current-tab-item-index-addr/edi: (addr int) <- get current-tab, item-index
  var new-tab-item-index/ecx: int <- copy *current-tab-item-index-addr
  var y/edx: int <- copy 2
  {
    compare new-tab-item-index, final-tab-post-index
    break-if->
    compare y, 0x28/screen-height-minus-menu
    break-if->=
    var current-item-index-addr/eax: (addr int) <- index current-tab-search-items, new-tab-item-index
    var current-item-index/eax: int <- copy *current-item-index-addr
    var offset/eax: (offset item) <- compute-offset items-data, current-item-index
    var item/eax: (addr item) <- index items-data, offset
    var item-text-ah/eax: (addr handle array byte) <- get item, text
    var item-text/eax: (addr array byte) <- lookup *item-text-ah
    var h/eax: int <- estimate-height item-text
    y <- add h
    new-tab-item-index <- increment
    loop
  }
  new-tab-item-index <- decrement
  copy-to *current-tab-item-index-addr, new-tab-item-index
}

fn thread-page-up _current-tab: (addr tab), users: (addr array user), channels: (addr array channel), _items: (addr item-list) {
  var current-tab/edi: (addr tab) <- copy _current-tab
  var items/eax: (addr item-list) <- copy _items
  var items-data-ah/eax: (addr handle array item) <- get items, data
  var _items-data/eax: (addr array item) <- lookup *items-data-ah
  var items-data/esi: (addr array item) <- copy _items-data
  var current-tab-root-index-addr/eax: (addr int) <- get current-tab, root-index
  var current-tab-root-index/eax: int <- copy *current-tab-root-index-addr
  var current-tab-root-offset/eax: (offset item) <- compute-offset items-data, current-tab-root-index
  var post/eax: (addr item) <- index items-data, current-tab-root-offset
  var post-comments-first-free-addr/ecx: (addr int) <- get post, comments-first-free
  var post-comments-ah/eax: (addr handle array int) <- get post, comments
  var _post-comments/eax: (addr array int) <- lookup *post-comments-ah
  var post-comments/ebx: (addr array int) <- copy _post-comments
  var final-tab-comment-index: int
  {
    var tmp/eax: int <- copy *post-comments-first-free-addr
    tmp <- decrement
    copy-to final-tab-comment-index, tmp
  }
  var current-tab-item-index-addr/edi: (addr int) <- get current-tab, item-index
  var new-tab-item-index/ecx: int <- copy *current-tab-item-index-addr
  var y/edx: int <- copy 2
  {
    compare new-tab-item-index, final-tab-comment-index
    break-if->
    compare y, 0x28/screen-height-minus-menu
    break-if->=
    var current-item-index-addr/eax: (addr int) <- index post-comments, new-tab-item-index
    var current-item-index/eax: int <- copy *current-item-index-addr
    var offset/eax: (offset item) <- compute-offset items-data, current-item-index
    var item/eax: (addr item) <- index items-data, offset
    var item-text-ah/eax: (addr handle array byte) <- get item, text
    var item-text/eax: (addr array byte) <- lookup *item-text-ah
    var h/eax: int <- estimate-height item-text
    y <- add h
    new-tab-item-index <- increment
    loop
  }
  new-tab-item-index <- decrement
  copy-to *current-tab-item-index-addr, new-tab-item-index
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
