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
#sig allocate ad: (addr allocation-descriptor), n: int, out: (addr handle _)
#sig allocate-raw ad: (addr allocation-descriptor), n: int, out: (addr handle _)
sig lookup h: (handle _T) -> _/eax: (addr _T)
sig handle-equal? a: (handle _T), b: (handle _T) -> _/eax: boolean
sig copy-handle src: (handle _T), dest: (addr handle _T)
#sig allocate-region ad: (addr allocation-descriptor), n: int, out: (addr handle allocation-descriptor)
#sig allocate-array ad: (addr allocation-descriptor), n: int, out: (addr handle _)
sig copy-array ad: (addr allocation-descriptor), src: (addr array _T), out: (addr handle array _T)
#sig zero-out start: (addr byte), size: int
sig stream-empty? s: (addr stream _) -> _/eax: boolean
