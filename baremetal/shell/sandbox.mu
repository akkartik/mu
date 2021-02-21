type sandbox {
  data: (handle gap-buffer)
}

fn initialize-sandbox _self: (addr sandbox) {
  var self/esi: (addr sandbox) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, data
  allocate data-ah
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  initialize-gap-buffer data, 0x1000/4KB
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

fn add-grapheme-to-sandbox _self: (addr sandbox), c: grapheme {
  var self/esi: (addr sandbox) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  add-grapheme-at-gap data, c
}

fn render-sandbox screen: (addr screen), _self: (addr sandbox), x: int, y: int {
  var self/esi: (addr sandbox) <- copy _self
  var data-ah/eax: (addr handle gap-buffer) <- get self, data
  var data/eax: (addr gap-buffer) <- lookup *data-ah
  var dummy/eax: int <- render-gap-buffer screen, data, x, y, 1/true
}

fn edit-sandbox self: (addr sandbox), key: byte {
  var g/edx: grapheme <- copy key
  add-grapheme-to-sandbox self, g
}
