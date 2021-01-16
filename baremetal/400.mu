# screen
sig pixel-on-real-screen x: int, y: int, color: int
sig draw-grapheme-on-real-screen g: grapheme, x: int, y: int, color: int
sig cursor-position-on-real-screen -> _/eax: int, _/ecx: int
sig set-cursor-position-on-real-screen x: int, y: int

# keyboard
sig read-key kbd: (addr keyboard) -> _/eax: byte

# tests
sig count-test-failure
sig num-test-failures -> _/eax: int

# streams
sig clear-stream f: (addr stream _)
sig rewind-stream f: (addr stream _)
sig write f: (addr stream byte), s: (addr array byte)
sig append-byte f: (addr stream byte), n: int
sig read-byte s: (addr stream byte) -> _/eax: byte
sig stream-empty? s: (addr stream _) -> _/eax: boolean
