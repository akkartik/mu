type channel {
  name: (handle array byte)
  posts: (handle array int)  # item indices
  newest-post-index: int
}

type user {
  id: (handle array byte)
  name: (handle array byte)
  real-name: (handle array byte)
  avatar: image
}

type item {
  id: (handle array byte)
  channel: (handle array byte)
  by: int  # user index
  text: (handle array byte)
  parent: int  # item index
  comments: (handle array int)
  newest-comment-index: int
}

# globals:
#   users: (handle array user)
#   channels: (handle array channel)
#   items: (handle array item)
#
# flows:
#   channel -> posts
#   user -> posts|comments
#   post -> comments
#   comment -> post|comments
#   keywords -> posts|comments

# static buffer sizes in this program:
#   data-size
#   data-size-in-sectors
#   num-channels
#   num-users
#   num-items
#   num-comments
#   message-text-limit
#   channel-capacity

fn main screen: (addr screen), keyboard: (addr keyboard), data-disk: (addr disk) {
  # load entire disk contents to a single enormous stream
  var s-h: (handle stream byte)  # the stream is too large to put on the stack
  var s-ah/eax: (addr handle stream byte) <- address s-h
  populate-stream s-ah, 0x4000000/data-size
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, "loading data disk..", 3/fg 0/bg
  var _s/eax: (addr stream byte) <- lookup *s-ah
  var s/ebx: (addr stream byte) <- copy _s
  load-sectors data-disk, 0/lba, 0x400/sectors, s  # large enough for test_data
#?   load-sectors data-disk, 0/lba, 0x20000/data-size-in-sectors, s  # largest size tested; _slow_
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, "done", 3/fg 0/bg
  # parse global data structures out of the stream
  var users-h: (handle array user)
  var users-ah/eax: (addr handle array user) <- address users-h
  populate users-ah, 0x800/num-users
  var _users/eax: (addr array user) <- lookup *users-ah
  var users/edi: (addr array user) <- copy _users
  var channels-h: (handle array channel)
  var channels-ah/eax: (addr handle array channel) <- address channels-h
  populate channels-ah, 0x20/num-channels
  var _channels/eax: (addr array channel) <- lookup *channels-ah
  var channels/esi: (addr array channel) <- copy _channels
  var items-h: (handle array item)
  var items-ah/eax: (addr handle array item) <- address items-h
  populate items-ah, 0x10000/num-items
  var _items/eax: (addr array item) <- lookup *items-ah
  var items/edx: (addr array item) <- copy _items
  parse s, users, channels, items
  # render
  var env-storage: environment
  var env/ebx: (addr environment) <- address env-storage
  {
    render-environment env, users, channels, items
    {
      var key/eax: byte <- read-key keyboard
      compare key, 0
      loop-if-=
      update-environment env, key
    }
    loop
  }
}

fn parse in: (addr stream byte), users: (addr array user), channels: (addr array channel), items: (addr array item) {
  # 'in' consists of a long, flat sequence of records surrounded by parens
  var record-storage: (stream byte 0x18000)
  var record/ecx: (addr stream byte) <- address record-storage
  var user-idx/edx: int <- copy 0
  var item-idx/ebx: int <- copy 0
  {
    var done?/eax: boolean <- stream-empty? in
    compare done?, 0/false
    break-if-!=
    var c/eax: byte <- peek-byte in
    compare c, 0
    break-if-=
    set-cursor-position 0/screen, 0x20 0x20
    draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, user-idx, 3/fg 0/bg
    draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen, item-idx, 4/fg 0/bg
    clear-stream record
    parse-record in, record
    var user?/eax: boolean <- user-record? record
    {
      compare user?, 0/false
      break-if-=
      parse-user record, users, user-idx
      user-idx <- increment
    }
    {
      compare user?, 0/false
      break-if-!=
      parse-item record, channels, items, item-idx
      item-idx <- increment
    }
    loop
  }
}

fn parse-record in: (addr stream byte), out: (addr stream byte) {
  var paren/eax: byte <- read-byte in
  compare paren, 0x28/open-paren
  {
    break-if-=
    set-cursor-position 0/screen, 0x20 0x10
    var c/eax: int <- copy paren
    draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen 0/screen c, 5/fg 0/bg
    abort "parse-record: ("
  }
  var paren-int/eax: int <- copy paren
  append-byte out, paren-int
  {
    {
      var eof?/eax: boolean <- stream-empty? in
      compare eof?, 0/false
      break-if-=
      abort "parse-record: truncated"
    }
    var c/eax: byte <- read-byte in
    {
      var c-int/eax: int <- copy c
      append-byte out, c-int
    }
    compare c, 0x29/close-paren
    break-if-=
    compare c, 0x22/double-quote
    {
      break-if-!=
      slurp-json-string in, out
    }
    loop
  }
  skip-chars-matching-whitespace in
}

fn user-record? record: (addr stream byte) -> _/eax: boolean {
  rewind-stream record
  var c/eax: byte <- read-byte record  # skip paren
  var c/eax: byte <- read-byte record  # skip double quote
  var c/eax: byte <- read-byte record
  compare c, 0x55/U
  {
    break-if-!=
    return 1/true
  }
  rewind-stream record
  return 0/false
}

fn parse-user record: (addr stream byte), _users: (addr array user), user-idx: int {
  var users/esi: (addr array user) <- copy _users
  var offset/eax: (offset user) <- compute-offset users, user-idx
  var user/esi: (addr user) <- index users, offset
  #
  var s-storage: (stream byte 0x40)
  var s/ecx: (addr stream byte) <- address s-storage
  #
  rewind-stream record
  var paren/eax: byte <- read-byte record
  compare paren, 0x28/open-paren
  {
    break-if-=
    abort "parse-user: ("
  }
  # user id
  skip-chars-matching-whitespace record
  var double-quote/eax: byte <- read-byte record
  compare double-quote, 0x22/double-quote
  {
    break-if-=
    abort "parse-user: id"
  }
  next-json-string record, s
  var dest/eax: (addr handle array byte) <- get user, id
  stream-to-array s, dest
  # user name
  skip-chars-matching-whitespace record
  var double-quote/eax: byte <- read-byte record
  compare double-quote, 0x22/double-quote
  {
    break-if-=
    abort "parse-user: name"
  }
  clear-stream s
  next-json-string record, s
  var dest/eax: (addr handle array byte) <- get user, name
  stream-to-array s, dest
  # real name
  skip-chars-matching-whitespace record
  var double-quote/eax: byte <- read-byte record
  compare double-quote, 0x22/double-quote
  {
    break-if-=
    abort "parse-user: real-name"
  }
  clear-stream s
  next-json-string record, s
  var dest/eax: (addr handle array byte) <- get user, real-name
  stream-to-array s, dest
  # avatar
  skip-chars-matching-whitespace record
  var open-bracket/eax: byte <- read-byte record
  compare open-bracket, 0x5b/open-bracket
  {
    break-if-=
    abort "parse-user: avatar"
  }
  skip-chars-matching-whitespace record
  var c/eax: byte <- peek-byte record
  {
    compare c, 0x5d/close-bracket
    break-if-=
    var dest/eax: (addr image) <- get user, avatar
    initialize-image dest, record
  }
}

fn parse-item record: (addr stream byte), _channels: (addr array channel), _items: (addr array item), item-idx: int {
  var items/esi: (addr array item) <- copy _items
  var offset/eax: (offset item) <- compute-offset items, item-idx
  var item/edi: (addr item) <- index items, offset
  #
  var s-storage: (stream byte 0x40)
  var s/ecx: (addr stream byte) <- address s-storage
  #
  rewind-stream record
  var paren/eax: byte <- read-byte record
  compare paren, 0x28/open-paren
  {
    break-if-=
    abort "parse-item: ("
  }
  # item id
  skip-chars-matching-whitespace record
  var double-quote/eax: byte <- read-byte record
  compare double-quote, 0x22/double-quote
  {
    break-if-=
    abort "parse-item: id"
  }
  next-json-string record, s
  var dest/eax: (addr handle array byte) <- get item, id
  stream-to-array s, dest
  # parent index
  {
    var word-slice-storage: slice
    var word-slice/ecx: (addr slice) <- address word-slice-storage
    next-word record, word-slice
    var src/eax: int <- parse-decimal-int-from-slice word-slice
    compare src, -1
    break-if-=
    var dest/edx: (addr int) <- get item, parent
    copy-to *dest, src
    # cross-link to parent
    var parent-offset/eax: (offset item) <- compute-offset items, src
    var parent-item/esi: (addr item) <- index items, parent-offset
    var parent-comments-ah/ebx: (addr handle array int) <- get parent-item, comments
    var parent-comments/eax: (addr array int) <- lookup *parent-comments-ah
    compare parent-comments, 0
    {
      break-if-!=
      populate parent-comments-ah, 0x200/num-comments
      parent-comments <- lookup *parent-comments-ah
    }
    var parent-newest-comment-index-addr/edi: (addr int) <- get parent-item, newest-comment-index
    var parent-newest-comment-index/edx: int <- copy *parent-newest-comment-index-addr
    var dest/eax: (addr int) <- index parent-comments, parent-newest-comment-index
    var src/ecx: int <- copy item-idx
    copy-to *dest, src
    increment *parent-newest-comment-index-addr
  }
  # channel name
  skip-chars-matching-whitespace record
  var double-quote/eax: byte <- read-byte record
  compare double-quote, 0x22/double-quote
  {
    break-if-=
    abort "parse-item: channel"
  }
  clear-stream s
  next-json-string record, s
  var dest/eax: (addr handle array byte) <- get item, channel
  stream-to-array s, dest
  # cross-link to channels
  {
    var channels/esi: (addr array channel) <- copy _channels
    var channel-index/eax: int <- find-or-insert channels, s
    var channel-offset/eax: (offset channel) <- compute-offset channels, channel-index
    var channel/eax: (addr channel) <- index channels, channel-offset
    var channel-posts-ah/ecx: (addr handle array int) <- get channel, posts
    var channel-newest-post-index-addr/edx: (addr int) <- get channel, newest-post-index
    var channel-newest-post-index/edx: int <- copy *channel-newest-post-index-addr
    var channel-posts/eax: (addr array int) <- lookup *channel-posts-ah
    var dest/eax: (addr int) <- index channel-posts, channel-newest-post-index
  }
  # user index
  {
    var word-slice-storage: slice
    var word-slice/ecx: (addr slice) <- address word-slice-storage
    next-word record, word-slice
    var src/eax: int <- parse-decimal-int-from-slice word-slice
    var dest/edx: (addr int) <- get item, by
    copy-to *dest, src
  }
  # text
  var s-storage: (stream byte 0x4000)  # message-text-limit
  var s/ecx: (addr stream byte) <- address s-storage
  skip-chars-matching-whitespace record
  var double-quote/eax: byte <- read-byte record
  compare double-quote, 0x22/double-quote
  {
    break-if-=
    abort "parse-item: text"
  }
  next-json-string record, s
  var dest/eax: (addr handle array byte) <- get item, text
  stream-to-array s, dest
}

fn find-or-insert _channels: (addr array channel), name: (addr stream byte) -> _/eax: int {
  var channels/esi: (addr array channel) <- copy _channels
  var i/ecx: int <- copy 0
  var max/edx: int <- length channels
  {
    compare i, max
    break-if->=
    var offset/eax: (offset channel) <- compute-offset channels, i
    var curr/ebx: (addr channel) <- index channels, offset
    var curr-name-ah/edi: (addr handle array byte) <- get curr, name
    var curr-name/eax: (addr array byte) <- lookup *curr-name-ah
    {
      compare curr-name, 0
      break-if-!=
      rewind-stream name
      stream-to-array name, curr-name-ah
      var posts-ah/eax: (addr handle array int) <- get curr, posts
      populate posts-ah, 0x8000/channel-capacity
      return i
    }
    var found?/eax: boolean <- stream-data-equal? name, curr-name
    {
      compare found?, 0/false
      break-if-=
      return i
    }
    i <- increment
    loop
  }
  abort "out of channels"
  return -1
}

# includes trailing double quote
fn slurp-json-string in: (addr stream byte), out: (addr stream byte) {
  # open quote is already slurped
  {
    {
      var eof?/eax: boolean <- stream-empty? in
      compare eof?, 0/false
      break-if-=
      abort "slurp-json-string: truncated"
    }
    var c/eax: byte <- read-byte in
    {
      var c-int/eax: int <- copy c
      append-byte out, c-int
    }
    compare c, 0x22/double-quote
    break-if-=
    compare c, 0x5c/backslash
    {
      break-if-!=
      # read next byte raw
      c <- read-byte in
      var c-int/eax: int <- copy c
      append-byte out, c-int
    }
    loop
  }
}

# drops trailing double quote
fn next-json-string in: (addr stream byte), out: (addr stream byte) {
  # open quote is already read
  {
    {
      var eof?/eax: boolean <- stream-empty? in
      compare eof?, 0/false
      break-if-=
      abort "next-json-string: truncated"
    }
    var c/eax: byte <- read-byte in
    compare c, 0x22/double-quote
    break-if-=
    {
      var c-int/eax: int <- copy c
      append-byte out, c-int
    }
    compare c, 0x5c/backslash
    {
      break-if-!=
      # read next byte raw
      c <- read-byte in
      var c-int/eax: int <- copy c
      append-byte out, c-int
    }
    loop
  }
}
