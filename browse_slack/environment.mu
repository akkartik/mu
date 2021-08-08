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

fn render-environment env: (addr environment), users: (addr array user), channels: (addr array channel), items: (addr array item) {
}

fn update-environment env: (addr environment), key: byte {
}
