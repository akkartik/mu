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

# I try to put all the static buffer sizes in this function.
fn main screen: (addr screen), keyboard: (addr keyboard), data-disk: (addr disk) {
  # load entire disk contents to a single enormous stream
  var s-h: (handle stream byte)  # the stream is too large to put on the stack
  var s-ah/eax: (addr handle stream byte) <- address s-h
  populate-stream s-ah, 0x4000000
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, "loading data disk..", 3/fg 0/bg
  var _s/eax: (addr stream byte) <- lookup *s-ah
  var s/ebx: (addr stream byte) <- copy _s
  load-sectors data-disk, 0/lba, 0x400/sectors, s  # large enough for test_data
#?   load-sectors data-disk, 0/lba, 0x20000/sectors, s  # largest size tested; _slow_
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, "done", 3/fg 0/bg
  # parse global data structures out of the stream
  var users-h: (handle array user)
  var users-ah/eax: (addr handle array user) <- address users-h
  populate users-ah, 0x800
  var _users/eax: (addr array user) <- lookup *users-ah
  var users/edi: (addr array user) <- copy _users
  var channels-h: (handle array channel)
  var channels-ah/eax: (addr handle array channel) <- address channels-h
  populate channels-ah, 0x20
  var _channels/eax: (addr array channel) <- lookup *channels-ah
  var channels/esi: (addr array channel) <- copy _channels
  var items-h: (handle array item)
  var items-ah/eax: (addr handle array item) <- address items-h
  populate items-ah, 0x10000
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

fn parse-item record: (addr stream byte), channels: (addr array channel), items: (addr array item), item-idx: int {
  rewind-stream record
  var paren/eax: byte <- read-byte record
  compare paren, 0x28/open-paren
  {
    break-if-=
    abort "parse-item: ("
  }
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
