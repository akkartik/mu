# screen
sig pixel-on-real-screen x: int, y: int, color: int
sig draw-grapheme-on-real-screen g: grapheme, x: int, y: int, color: int, background-color: int
sig cursor-position-on-real-screen -> _/eax: int, _/ecx: int
sig set-cursor-position-on-real-screen x: int, y: int
sig draw-cursor-on-real-screen g: grapheme

# keyboard
sig read-key kbd: (addr keyboard) -> _/eax: byte

# disk
sig load-first-sector-from-primary-bus-secondary-drive out: (addr stream byte)

# tests
sig count-test-failure
sig num-test-failures -> _/eax: int

sig string-equal? s: (addr array byte), benchmark: (addr array byte) -> _/eax: boolean
sig string-starts-with? s: (addr array byte), benchmark: (addr array byte) -> _/eax: boolean
sig check-strings-equal s: (addr array byte), expected: (addr array byte), msg: (addr array byte)

# streams
sig clear-stream f: (addr stream _)
sig rewind-stream f: (addr stream _)
sig stream-data-equal? f: (addr stream byte), s: (addr array byte) -> _/eax: boolean
sig check-stream-equal f: (addr stream byte), s: (addr array byte), msg: (addr array byte)
sig next-stream-line-equal? f: (addr stream byte), s: (addr array byte) -> _/eax: boolean
sig check-next-stream-line-equal f: (addr stream byte), s: (addr array byte), msg: (addr array byte)
sig write f: (addr stream byte), s: (addr array byte)
sig write-stream f: (addr stream byte), s: (addr stream byte)
sig read-byte s: (addr stream byte) -> _/eax: byte
sig append-byte f: (addr stream byte), n: int  # really just a byte, but I want to pass in literal numbers
#sig to-hex-char in/eax: int -> out/eax: int
sig append-byte-hex f: (addr stream byte), n: int  # really just a byte, but I want to pass in literal numbers
sig write-int32-hex f: (addr stream byte), n: int
sig write-int32-hex-bits f: (addr stream byte), n: int, bits: int
sig hex-int? in: (addr slice) -> _/eax: boolean
sig parse-hex-int in: (addr array byte) -> _/eax: int
sig parse-hex-int-from-slice in: (addr slice) -> _/eax: int
#sig parse-hex-int-helper start: (addr byte), end: (addr byte) -> _/eax: int
sig hex-digit? c: byte -> _/eax: boolean
#sig from-hex-char in/eax: byte -> out/eax: nibble
sig parse-decimal-int in: (addr array byte) -> _/eax: int
sig parse-decimal-int-from-slice in: (addr slice) -> _/eax: int
sig parse-decimal-int-from-stream in: (addr stream byte) -> _/eax: int
#sig parse-decimal-int-helper start: (addr byte), end: (addr byte) -> _/eax: int
sig decimal-size n: int -> _/eax: int
#sig allocate ad: (addr allocation-descriptor), n: int, out: (addr handle _)
#sig allocate-raw ad: (addr allocation-descriptor), n: int, out: (addr handle _)
sig lookup h: (handle _T) -> _/eax: (addr _T)
sig handle-equal? a: (handle _T), b: (handle _T) -> _/eax: boolean
sig copy-handle src: (handle _T), dest: (addr handle _T)
#sig allocate-region ad: (addr allocation-descriptor), n: int, out: (addr handle allocation-descriptor)
#sig allocate-array ad: (addr allocation-descriptor), n: int, out: (addr handle _)
sig copy-array ad: (addr allocation-descriptor), src: (addr array _T), out: (addr handle array _T)
#sig zero-out start: (addr byte), size: int
sig slice-empty? s: (addr slice) -> _/eax: boolean
sig slice-equal? s: (addr slice), p: (addr array byte) -> _/eax: boolean
sig slice-starts-with? s: (addr slice), head: (addr array byte) -> _/eax: boolean
sig write-slice out: (addr stream byte), s: (addr slice)
# bad name alert
sig slice-to-string ad: (addr allocation-descriptor), in: (addr slice), out: (addr handle array byte)
sig write-int32-decimal out: (addr stream byte), n: int
sig decimal-digit? c: grapheme -> _/eax: boolean
sig to-decimal-digit in: grapheme -> _/eax: int
# bad name alert
# next-word really tokenizes
# next-raw-word really reads whitespace-separated words
sig next-word line: (addr stream byte), out: (addr slice)  # skips '#' comments
sig next-raw-word line: (addr stream byte), out: (addr slice)  # does not skip '#' comments
sig stream-empty? s: (addr stream _) -> _/eax: boolean
sig stream-full? s: (addr stream _) -> _/eax: boolean
sig stream-to-array in: (addr stream _), out: (addr handle array _)
sig unquote-stream-to-array in: (addr stream _), out: (addr handle array _)
sig stream-first s: (addr stream byte) -> _/eax: byte
sig stream-final s: (addr stream byte) -> _/eax: byte

#sig copy-bytes src: (addr byte), dest: (addr byte), n: int
sig copy-array-object src: (addr array _), dest-ah: (addr handle array _)
sig array-equal? a: (addr array int), b: (addr array int) -> _/eax: boolean
sig parse-array-of-ints s: (addr array byte), out: (addr handle array int)
sig parse-array-of-decimal-ints s: (addr array byte), out: (addr handle array int)
sig check-array-equal a: (addr array int), expected: (addr string), msg: (addr string)

sig integer-divide a: int, b: int -> _/eax: int, _/edx: int
