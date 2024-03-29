# screen
sig pixel-on-real-screen x: int, y: int, color: int
sig draw-code-point-on-real-screen c: code-point, x: int, y: int, color: int, background-color: int -> _/eax: int
sig overlay-code-point-on-real-screen c: code-point, x: int, y: int, color: int, background-color: int -> _/eax: int
sig draw-code-point-on-screen-array screen-data: (addr array byte), c: code-point, x: int, y: int, color: int, background-color: int, screen-width: int, screen-height: int -> _/eax: int
sig wide-code-point? c: code-point -> _/eax: boolean
sig combining-code-point? c: code-point -> _/eax: boolean
sig cursor-position-on-real-screen -> _/eax: int, _/ecx: int
sig set-cursor-position-on-real-screen x: int, y: int
sig draw-cursor-on-real-screen c: code-point
sig color-rgb color: int -> _/ecx: int, _/edx: int, _/ebx: int

# timer
sig timer-counter -> _/eax: int

# keyboard
sig read-key kbd: (addr keyboard) -> _/eax: byte

# disk
sig read-ata-disk disk: (addr disk), lba: int, n: int, out: (addr stream byte)
sig write-ata-disk disk: (addr disk), lba: int, n: int, out: (addr stream byte)

# mouse
sig read-mouse-event -> _/eax: int, _/ecx: int

# tests
sig count-test-failure
sig num-test-failures -> _/eax: int
sig running-tests? -> _/eax: boolean

sig string-equal? s: (addr array byte), benchmark: (addr array byte) -> _/eax: boolean
sig string-starts-with? s: (addr array byte), benchmark: (addr array byte) -> _/eax: boolean
sig check-strings-equal s: (addr array byte), expected: (addr array byte), msg: (addr array byte)

# debugging
sig check-stack
sig show-stack-state
sig debug-print x: (addr array byte), fg: int, bg: int
sig debug-print? -> _/eax: boolean
sig turn-on-debug-print
sig turn-off-debug-print
sig abort e: (addr array byte)
sig dump-call-stack
sig heap-bound -> _/eax: int

sig count-event
sig count-of-events -> _/eax: int

# streams
sig clear-stream f: (addr stream _)
sig rewind-stream f: (addr stream _)
sig stream-data-equal? f: (addr stream byte), s: (addr array byte) -> _/eax: boolean
sig streams-data-equal? a: (addr stream byte), b: (addr stream byte) -> _/eax: boolean
sig check-stream-equal f: (addr stream byte), s: (addr array byte), msg: (addr array byte)
sig check-streams-data-equal s: (addr stream _), expected: (addr stream _), msg: (addr array byte)
sig next-stream-line-equal? f: (addr stream byte), s: (addr array byte) -> _/eax: boolean
sig check-next-stream-line-equal f: (addr stream byte), s: (addr array byte), msg: (addr array byte)
sig write f: (addr stream byte), s: (addr array byte)
sig try-write f: (addr stream byte), s: (addr array byte) -> _/eax: boolean
# probably a bad idea; I definitely want to discourage its use for streams of non-bytes
sig stream-size f: (addr stream byte) -> _/eax: int
sig space-remaining-in-stream f: (addr stream byte) -> _/eax: int
sig write-stream f: (addr stream byte), s: (addr stream byte)
sig write-stream-immutable f: (addr stream byte), s: (addr stream byte)
sig read-byte s: (addr stream byte) -> _/eax: byte
sig peek-byte s: (addr stream byte) -> _/eax: byte
sig append-byte f: (addr stream byte), n: int  # really just a byte, but I want to pass in literal numbers
sig undo-append-byte f: (addr stream byte)  # take most recent append back out
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
sig decimal-digit? c: code-point-utf8 -> _/eax: boolean
sig to-decimal-digit in: code-point-utf8 -> _/eax: int
# bad name alert
# next-word really tokenizes
# next-raw-word really reads whitespace-separated words
sig next-word line: (addr stream byte), out: (addr slice)  # merges '#' comments into a single word
sig next-raw-word line: (addr stream byte), out: (addr slice)  # does not merge '#' comments
sig skip-chars-matching in: (addr stream byte), delimiter: byte
sig skip-chars-matching-whitespace in: (addr stream byte)
sig skip-chars-not-matching in: (addr stream byte), delimiter: byte
sig skip-chars-not-matching-whitespace in: (addr stream byte)
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
sig check-array-equal a: (addr array int), expected: (addr array byte), msg: (addr array byte)

sig integer-divide a: int, b: int -> _/eax: int, _/edx: int
