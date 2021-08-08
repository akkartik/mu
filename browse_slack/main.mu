type channel {
  id: (handle array byte)
  name: (handle array byte)
  posts: (handle array int)  # item indices
  newest-post-index: int
}

type user {
  id: (handle array byte)
  name: (handle array byte)
  real-name: (handle array byte)
  avatar: (handle image)
}

type item {
  id: (handle array byte)
  channel: (handle array byte)
  by: int  # user index
  text: (handle array byte)
  parent: int  # item index
}

type post {
  root: int  # item index
  comments: (handle array int)  # item indices
}

# globals:
#   users: (handle array user)
#   channels: (handle array channel)
#   items: (handle array item)
#
# flows:
#   channel -> posts
#   user -> posts
#   post -> comments
#   keywords -> posts|comments

# I try to put all the static buffer sizes in this function.
fn main screen: (addr screen), keyboard: (addr keyboard), data-disk: (addr disk) {
  # load entire disk contents to a single enormous stream
  draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen, "loading data disk..", 3/fg 0/bg
  var s-h: (handle stream byte)  # the stream is too large to put on the stack
  var s-ah/eax: (addr handle stream byte) <- address s-h
  populate-stream s-ah, 0x4000000
  var _s/eax: (addr stream byte) <- lookup *s-ah
  var s/ebx: (addr stream byte) <- copy _s
  load-sectors data-disk, 0/lba, 0x20000/sectors, s
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

fn parse s: (addr stream byte), users: (addr array user), channels: (addr array channel), items: (addr array item) {
}
