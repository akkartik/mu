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
sig timer-counter -> _/eax: int
sig read-key kbd: (addr keyboard) -> _/eax: byte
sig read-ata-disk disk: (addr disk), lba: int, n: int, out: (addr stream byte)
sig write-ata-disk disk: (addr disk), lba: int, n: int, out: (addr stream byte)
sig read-mouse-event -> _/eax: int, _/ecx: int
sig count-test-failure
sig num-test-failures -> _/eax: int
sig running-tests? -> _/eax: boolean
sig string-equal? s: (addr array byte), benchmark: (addr array byte) -> _/eax: boolean
sig string-starts-with? s: (addr array byte), benchmark: (addr array byte) -> _/eax: boolean
sig check-strings-equal s: (addr array byte), expected: (addr array byte), msg: (addr array byte)
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
sig stream-size f: (addr stream byte) -> _/eax: int
sig space-remaining-in-stream f: (addr stream byte) -> _/eax: int
sig write-stream f: (addr stream byte), s: (addr stream byte)
sig write-stream-immutable f: (addr stream byte), s: (addr stream byte)
sig read-byte s: (addr stream byte) -> _/eax: byte
sig peek-byte s: (addr stream byte) -> _/eax: byte
sig append-byte f: (addr stream byte), n: int  # really just a byte, but I want to pass in literal numbers
sig undo-append-byte f: (addr stream byte)  # take most recent append back out
sig append-byte-hex f: (addr stream byte), n: int  # really just a byte, but I want to pass in literal numbers
sig write-int32-hex f: (addr stream byte), n: int
sig write-int32-hex-bits f: (addr stream byte), n: int, bits: int
sig hex-int? in: (addr slice) -> _/eax: boolean
sig parse-hex-int in: (addr array byte) -> _/eax: int
sig parse-hex-int-from-slice in: (addr slice) -> _/eax: int
sig hex-digit? c: byte -> _/eax: boolean
sig parse-decimal-int in: (addr array byte) -> _/eax: int
sig parse-decimal-int-from-slice in: (addr slice) -> _/eax: int
sig parse-decimal-int-from-stream in: (addr stream byte) -> _/eax: int
sig decimal-size n: int -> _/eax: int
sig lookup h: (handle _T) -> _/eax: (addr _T)
sig handle-equal? a: (handle _T), b: (handle _T) -> _/eax: boolean
sig copy-handle src: (handle _T), dest: (addr handle _T)
sig copy-array ad: (addr allocation-descriptor), src: (addr array _T), out: (addr handle array _T)
sig slice-empty? s: (addr slice) -> _/eax: boolean
sig slice-equal? s: (addr slice), p: (addr array byte) -> _/eax: boolean
sig slice-starts-with? s: (addr slice), head: (addr array byte) -> _/eax: boolean
sig write-slice out: (addr stream byte), s: (addr slice)
sig slice-to-string ad: (addr allocation-descriptor), in: (addr slice), out: (addr handle array byte)
sig write-int32-decimal out: (addr stream byte), n: int
sig decimal-digit? c: code-point-utf8 -> _/eax: boolean
sig to-decimal-digit in: code-point-utf8 -> _/eax: int
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
sig copy-array-object src: (addr array _), dest-ah: (addr handle array _)
sig array-equal? a: (addr array int), b: (addr array int) -> _/eax: boolean
sig parse-array-of-ints s: (addr array byte), out: (addr handle array int)
sig parse-array-of-decimal-ints s: (addr array byte), out: (addr handle array int)
sig check-array-equal a: (addr array int), expected: (addr array byte), msg: (addr array byte)
sig integer-divide a: int, b: int -> _/eax: int, _/edx: int
sig to-code-point in: code-point-utf8 -> _/eax: code-point
sig to-utf8 in: code-point -> _/eax: code-point-utf8
sig read-code-point-utf8 in: (addr stream byte) -> _/eax: code-point-utf8
sig utf8-length g: code-point-utf8 -> _/edx: int
sig shift-left-bytes n: int, k: int -> _/eax: int
sig write-code-point-utf8 out: (addr stream byte), g: code-point-utf8
sig fill-in-rational _out: (addr float), nr: int, dr: int
sig fill-in-sqrt _out: (addr float), n: int
sig rational nr: int, dr: int -> _/xmm0: float
sig scale-down-and-round-up n: int, m: int -> _/ecx: int
sig substring in: (addr array byte), start: int, len: int, out-ah: (addr handle array byte)
sig split-string in: (addr array byte), delim: code-point-utf8, out: (addr handle array (handle array byte))
sig render-float-decimal screen: (addr screen), in: float, precision: int, x: int, y: int, color: int, background-color: int -> _/eax: int
sig write-float-decimal-approximate out: (addr stream byte), in: float, precision: int
sig decimal-digits n: int, _buf: (addr array byte) -> _/eax: int
sig reverse-digits _buf: (addr array byte), n: int
sig double-array-of-decimal-digits _buf: (addr array byte), _n: int -> _/eax: int
sig halve-array-of-decimal-digits _buf: (addr array byte), _n: int, _dp: int -> _/eax: int, _/edx: int
sig _write-float-array-of-decimal-digits out: (addr stream byte), _buf: (addr array byte), n: int, dp: int, precision: int
sig _write-float-array-of-decimal-digits-in-scientific-notation out: (addr stream byte), _buf: (addr array byte), n: int, dp: int, precision: int
sig float-size in: float, precision: int -> _/eax: int
sig initialize-screen _screen: (addr screen), width: int, height: int, pixel-graphics?: boolean
sig screen-size _screen: (addr screen) -> _/eax: int, _/ecx: int
sig draw-code-point _screen: (addr screen), c: code-point, x: int, y: int, color: int, background-color: int -> _/eax: int
sig overlay-code-point _screen: (addr screen), c: code-point, x: int, y: int, color: int, background-color: int -> _/eax: int
sig draw-narrow-code-point-on-fake-screen _screen: (addr screen), c: code-point, x: int, y: int, color: int, background-color: int
sig draw-wide-code-point-on-fake-screen _screen: (addr screen), c: code-point, x: int, y: int, color: int, background-color: int
sig screen-cell-index _screen: (addr screen), x: int, y: int -> _/ecx: int
sig cursor-position _screen: (addr screen) -> _/eax: int, _/ecx: int
sig set-cursor-position _screen: (addr screen), x: int, y: int
sig draw-cursor screen: (addr screen), c: code-point
sig clear-screen _screen: (addr screen)
sig fake-screen-empty? _screen: (addr screen) -> _/eax: boolean
sig clear-rect _screen: (addr screen), xmin: int, ymin: int, xmax: int, ymax: int, background-color: int
sig clear-real-screen
sig clear-rect-on-real-screen xmin: int, ymin: int, xmax: int, ymax: int, background-color: int
sig screen-cell-unused-at? _screen: (addr screen), x: int, y: int -> _/eax: boolean
sig screen-cell-unused-at-index? _screen: (addr screen), _index: int -> _/eax: boolean
sig screen-code-point-at _screen: (addr screen), x: int, y: int -> _/eax: code-point
sig screen-code-point-at-index _screen: (addr screen), _index: int -> _/eax: code-point
sig screen-color-at _screen: (addr screen), x: int, y: int -> _/eax: int
sig screen-color-at-index _screen: (addr screen), _index: int -> _/eax: int
sig screen-background-color-at _screen: (addr screen), x: int, y: int -> _/eax: int
sig screen-background-color-at-index _screen: (addr screen), _index: int -> _/eax: int
sig pixel screen: (addr screen), x: int, y: int, color: int
sig pixel-index _screen: (addr screen), x: int, y: int -> _/ecx: int
sig copy-pixels _screen: (addr screen), target-screen: (addr screen)
sig convert-screen-cells-to-pixels _screen: (addr screen)
sig move-cursor-left screen: (addr screen)
sig move-cursor-right screen: (addr screen)
sig move-cursor-up screen: (addr screen)
sig move-cursor-down screen: (addr screen)
sig move-cursor-to-left-margin-of-next-line screen: (addr screen)
sig draw-code-point-at-cursor-over-full-screen screen: (addr screen), c: code-point, color: int, background-color: int
sig draw-text-rightward screen: (addr screen), text: (addr array byte), x: int, xmax: int, y: int, color: int, background-color: int -> _/eax: int
sig draw-stream-rightward screen: (addr screen), stream: (addr stream byte), x: int, xmax: int, y: int, color: int, background-color: int -> _/eax: int
sig draw-text-rightward-over-full-screen screen: (addr screen), text: (addr array byte), x: int, y: int, color: int, background-color: int -> _/eax: int
sig draw-text-rightward-from-cursor screen: (addr screen), text: (addr array byte), xmax: int, color: int, background-color: int
sig draw-text-rightward-from-cursor-over-full-screen screen: (addr screen), text: (addr array byte), color: int, background-color: int
sig render-code-point screen: (addr screen), c: code-point, xmin: int, ymin: int, xmax: int, ymax: int, x: int, y: int, color: int, background-color: int -> _/eax: int, _/ecx: int
sig draw-text-wrapping-right-then-down screen: (addr screen), _text: (addr array byte), xmin: int, ymin: int, xmax: int, ymax: int, _x: int, _y: int, color: int, background-color: int -> _/eax: int, _/ecx: int
sig draw-stream-wrapping-right-then-down screen: (addr screen), stream: (addr stream byte), xmin: int, ymin: int, xmax: int, ymax: int, x: int, y: int, color: int, background-color: int -> _/eax: int, _/ecx: int
sig draw-stream-wrapping-right-then-down-from-cursor screen: (addr screen), stream: (addr stream byte), xmin: int, ymin: int, xmax: int, ymax: int, color: int, background-color: int
sig draw-stream-wrapping-right-then-down-from-cursor-over-full-screen screen: (addr screen), stream: (addr stream byte), color: int, background-color: int
sig move-cursor-rightward-and-downward screen: (addr screen), xmin: int, xmax: int
sig draw-text-wrapping-right-then-down-over-full-screen screen: (addr screen), text: (addr array byte), x: int, y: int, color: int, background-color: int -> _/eax: int, _/ecx: int
sig draw-text-wrapping-right-then-down-from-cursor screen: (addr screen), text: (addr array byte), xmin: int, ymin: int, xmax: int, ymax: int, color: int, background-color: int
sig draw-text-wrapping-right-then-down-from-cursor-over-full-screen screen: (addr screen), text: (addr array byte), color: int, background-color: int
sig draw-int32-hex-wrapping-right-then-down screen: (addr screen), n: int, xmin: int, ymin: int, xmax: int, ymax: int, x: int, y: int, color: int, background-color: int -> _/eax: int, _/ecx: int
sig draw-int32-hex-wrapping-right-then-down-over-full-screen screen: (addr screen), n: int, x: int, y: int, color: int, background-color: int -> _/eax: int, _/ecx: int
sig draw-int32-hex-wrapping-right-then-down-from-cursor screen: (addr screen), n: int, xmin: int, ymin: int, xmax: int, ymax: int, color: int, background-color: int
sig draw-int32-hex-wrapping-right-then-down-from-cursor-over-full-screen screen: (addr screen), n: int, color: int, background-color: int
sig draw-int32-decimal-wrapping-right-then-down screen: (addr screen), n: int, xmin: int, ymin: int, xmax: int, ymax: int, x: int, y: int, color: int, background-color: int -> _/eax: int, _/ecx: int
sig draw-int32-decimal-wrapping-right-then-down-over-full-screen screen: (addr screen), n: int, x: int, y: int, color: int, background-color: int -> _/eax: int, _/ecx: int
sig draw-int32-decimal-wrapping-right-then-down-from-cursor screen: (addr screen), n: int, xmin: int, ymin: int, xmax: int, ymax: int, color: int, background-color: int
sig draw-int32-decimal-wrapping-right-then-down-from-cursor-over-full-screen screen: (addr screen), n: int, color: int, background-color: int
sig draw-text-downward screen: (addr screen), text: (addr array byte), x: int, y: int, ymax: int, color: int, background-color: int -> _/eax: int
sig draw-stream-downward screen: (addr screen), stream: (addr stream byte), x: int, y: int, ymax: int, color: int, background-color: int -> _/eax: int
sig draw-text-downward-from-cursor screen: (addr screen), text: (addr array byte), ymax: int, color: int, background-color: int
sig draw-text-wrapping-down-then-right screen: (addr screen), text: (addr array byte), xmin: int, ymin: int, xmax: int, ymax: int, _x: int, _y: int, color: int, background-color: int -> _/eax: int, _/ecx: int
sig draw-stream-wrapping-down-then-right screen: (addr screen), stream: (addr stream byte), xmin: int, ymin: int, xmax: int, ymax: int, x: int, y: int, color: int, background-color: int -> _/eax: int, _/ecx: int
sig draw-text-wrapping-down-then-right-over-full-screen screen: (addr screen), text: (addr array byte), x: int, y: int, color: int, background-color: int -> _/eax: int, _/ecx: int
sig draw-text-wrapping-down-then-right-from-cursor screen: (addr screen), text: (addr array byte), xmin: int, ymin: int, xmax: int, ymax: int, color: int, background-color: int
sig draw-text-wrapping-down-then-right-from-cursor-over-full-screen screen: (addr screen), text: (addr array byte), color: int, background-color: int
sig check-ints-equal _a: int, b: int, msg: (addr array byte)
sig check _a: boolean, msg: (addr array byte)
sig check-not _a: boolean, msg: (addr array byte)
sig draw-box-on-real-screen x1: int, y1: int, x2: int, y2: int, color: int
sig draw-horizontal-line-on-real-screen x1: int, x2: int, y: int, color: int
sig draw-vertical-line-on-real-screen x: int, y1: int, y2: int, color: int
sig check-screen-row screen: (addr screen), y: int, expected: (addr array byte), msg: (addr array byte)
sig check-screen-row-from _screen: (addr screen), x: int, y: int, expected: (addr array byte), msg: (addr array byte)
sig check-screen-row-in-color screen: (addr screen), fg: int, y: int, expected: (addr array byte), msg: (addr array byte)
sig check-screen-row-in-color-from _screen: (addr screen), fg: int, y: int, x: int, expected: (addr array byte), msg: (addr array byte)
sig check-screen-row-in-background-color screen: (addr screen), bg: int, y: int, expected: (addr array byte), msg: (addr array byte)
sig check-screen-row-in-background-color-from _screen: (addr screen), bg: int, y: int, x: int, expected: (addr array byte), msg: (addr array byte)
sig check-background-color-in-screen-row screen: (addr screen), bg: int, y: int, expected-bitmap: (addr array byte), msg: (addr array byte)
sig check-background-color-in-screen-row-from _screen: (addr screen), bg: int, y: int, x: int, expected-bitmap: (addr array byte), msg: (addr array byte)
sig nearest-color-euclidean r: int, g: int, b: int -> _/eax: int
sig euclidean-distance-squared r1: int, g1: int, b1: int, r2: int, g2: int, b2: int -> _/eax: int
sig hsl r: int, g: int, b: int -> _/ecx: int, _/edx: int, _/ebx: int
sig nearest-color-euclidean-hsl h: int, s: int, l: int -> _/eax: int
sig euclidean-hsl-squared h1: int, s1: int, l1: int, h2: int, s2: int, l2: int -> _/eax: int
sig maximum a: int, b: int -> _/eax: int
sig minimum a: int, b: int -> _/eax: int
sig abs n: int -> _/eax: int
sig sgn n: int -> _/eax: int
sig shift-left-by n: int, bits: int -> _/eax: int
sig shift-right-by n: int, bits: int -> _/eax: int
sig clear-lowest-bits _n: (addr int), bits: int
sig draw-line screen: (addr screen), x0: int, y0: int, x1: int, y1: int, color: int
sig draw-horizontal-line screen: (addr screen), y: int, x0: int, x1: int, color: int
sig draw-vertical-line screen: (addr screen), x: int, y0: int, y1: int, color: int
sig draw-rect screen: (addr screen), xmin: int, ymin: int, xmax: int, ymax: int, color: int
sig line-point u: float, x0: int, x1: int -> _/eax: int
sig draw-circle screen: (addr screen), cx: int, cy: int, radius: int, color: int
sig draw-disc screen: (addr screen), cx: int, cy: int, radius: int, color: int, border-color: int
sig draw-monotonic-bezier screen: (addr screen), x0: int, y0: int, x1: int, y1: int, x2: int, y2: int, color: int
sig bezier-point u: float, x0: int, x1: int, x2: int -> _/eax: int
sig load-sectors disk: (addr disk), lba: int, n: int, out: (addr stream byte)
sig store-sectors disk: (addr disk), lba: int, n: int, in: (addr stream byte)
sig initialize-image _self: (addr image), in: (addr stream byte)
sig render-image screen: (addr screen), _img: (addr image), xmin: int, ymin: int, width: int, height: int
sig initialize-image-from-pbm _self: (addr image), in: (addr stream byte)
sig render-pbm-image screen: (addr screen), _img: (addr image), xmin: int, ymin: int, width: int, height: int
sig initialize-image-from-pgm _self: (addr image), in: (addr stream byte)
sig render-pgm-image screen: (addr screen), _img: (addr image), xmin: int, ymin: int, width: int, height: int
sig nearest-grey level-255: byte -> _/eax: int
sig dither-pgm-unordered-monochrome _src: (addr image), _dest: (addr image)
sig dither-pgm-unordered _src: (addr image), _dest: (addr image)
sig _diffuse-dithering-error-floyd-steinberg errors: (addr array int), x: int, y: int, width: int, height: int, error: int
sig _accumulate-dithering-error errors: (addr array int), x: int, y: int, width: int, error: int
sig _read-dithering-error _errors: (addr array int), x: int, y: int, width: int -> _/esi: int
sig _write-dithering-error _errors: (addr array int), x: int, y: int, width: int, val: int
sig _read-pgm-buffer _buf: (addr array byte), x: int, y: int, width: int -> _/eax: byte
sig _write-raw-buffer _buf: (addr array byte), x: int, y: int, width: int, val: byte
sig show-errors errors: (addr array int), width: int, height: int, x: int, y: int
sig psd s: (addr array byte), d: int, fg: int, x: int, y: int
sig psx s: (addr array byte), d: int, fg: int, x: int, y: int
sig initialize-image-from-ppm _self: (addr image), in: (addr stream byte)
sig render-ppm-image screen: (addr screen), _img: (addr image), xmin: int, ymin: int, width: int, height: int
sig dither-ppm-unordered _src: (addr image), _dest: (addr image)
sig _ppm-error buf: (addr array byte), x: int, y: int, width: int, channel: int, _scale-f: float -> _/eax: int
sig _error-to-ppm-channel error: int -> _/eax: int
sig _read-ppm-buffer _buf: (addr array byte), x: int, y: int, width: int, channel: int -> _/eax: byte
sig render-raw-image screen: (addr screen), _img: (addr image), xmin: int, ymin: int, width: int, height: int
sig scale-image-height _img: (addr image), width: int -> _/ebx: int
sig next-word-skipping-comments line: (addr stream byte), out: (addr slice)
sig slide-up _a: (addr array int), start: int, end: int, target: int
sig slide-down _a: (addr array int), start: int, end: int, target: int
sig find-slide-down-slot-in-array _a: (addr array int), _val: int -> _/ecx: int
sig check-slide-up before: (addr array byte), start: int, end: int, target: int, after: (addr array byte), msg: (addr array byte)
sig check-slide-down before: (addr array byte), start: int, end: int, target: int, after: (addr array byte), msg: (addr array byte)
sig initialize-grapheme-stack _self: (addr grapheme-stack), n: int
sig clear-grapheme-stack _self: (addr grapheme-stack)
sig grapheme-stack-empty? _self: (addr grapheme-stack) -> _/eax: boolean
sig grapheme-stack-length _self: (addr grapheme-stack) -> _/eax: int
sig push-grapheme-stack _self: (addr grapheme-stack), _val: code-point-utf8
sig pop-grapheme-stack _self: (addr grapheme-stack) -> _/eax: code-point-utf8
sig copy-grapheme-stack _src: (addr grapheme-stack), dest: (addr grapheme-stack)
sig render-stack-from-bottom-wrapping-right-then-down screen: (addr screen), _self: (addr grapheme-stack), xmin: int, ymin: int, xmax: int, ymax: int, _x: int, _y: int, highlight-matching-open-paren?: boolean, open-paren-depth: int, color: int, background-color: int -> _/eax: int, _/ecx: int
sig render-stack-from-bottom screen: (addr screen), self: (addr grapheme-stack), x: int, y: int, highlight-matching-open-paren?: boolean, open-paren-depth: int -> _/eax: int
sig render-stack-from-top-wrapping-right-then-down screen: (addr screen), _self: (addr grapheme-stack), xmin: int, ymin: int, xmax: int, ymax: int, _x: int, _y: int, render-cursor?: boolean, color: int, background-color: int -> _/eax: int, _/ecx: int
sig render-stack-from-top screen: (addr screen), self: (addr grapheme-stack), x: int, y: int, render-cursor?: boolean -> _/eax: int
sig get-matching-close-paren-index _self: (addr grapheme-stack), render-cursor?: boolean -> _/edx: int
sig get-matching-open-paren-index _self: (addr grapheme-stack), control: boolean, depth: int -> _/edx: int
sig prefix-match? _self: (addr grapheme-stack), s: (addr stream byte) -> _/eax: boolean
sig suffix-match? _self: (addr grapheme-stack), s: (addr stream byte) -> _/eax: boolean
sig grapheme-stack-is-decimal-integer? _self: (addr grapheme-stack) -> _/eax: boolean
sig initialize-gap-buffer _self: (addr gap-buffer), capacity: int
sig clear-gap-buffer _self: (addr gap-buffer)
sig gap-buffer-empty? _self: (addr gap-buffer) -> _/eax: boolean
sig gap-buffer-capacity _gap: (addr gap-buffer) -> _/edx: int
sig initialize-gap-buffer-with self: (addr gap-buffer), keys: (addr array byte)
sig load-gap-buffer-from-stream self: (addr gap-buffer), in: (addr stream byte)
sig emit-gap-buffer self: (addr gap-buffer), out: (addr stream byte)
sig append-gap-buffer _self: (addr gap-buffer), out: (addr stream byte)
sig emit-stack-from-bottom _self: (addr grapheme-stack), out: (addr stream byte)
sig emit-stack-from-top _self: (addr grapheme-stack), out: (addr stream byte)
sig word-at-gap _self: (addr gap-buffer), out: (addr stream byte)
sig code-point-utf8-at-gap _self: (addr gap-buffer) -> _/eax: code-point-utf8
sig top-most-word _self: (addr grapheme-stack) -> _/eax: int
sig emit-stack-from-index _self: (addr grapheme-stack), start: int, out: (addr stream byte)
sig emit-stack-to-index _self: (addr grapheme-stack), end: int, out: (addr stream byte)
sig is-ascii-word-code-point-utf8? g: code-point-utf8 -> _/eax: boolean
sig render-gap-buffer-wrapping-right-then-down screen: (addr screen), _gap: (addr gap-buffer), xmin: int, ymin: int, xmax: int, ymax: int, render-cursor?: boolean, color: int, background-color: int -> _/eax: int, _/ecx: int
sig render-gap-buffer screen: (addr screen), gap: (addr gap-buffer), x: int, y: int, render-cursor?: boolean, color: int, background-color: int -> _/eax: int
sig gap-buffer-length _gap: (addr gap-buffer) -> _/eax: int
sig add-code-point-utf8-at-gap _self: (addr gap-buffer), g: code-point-utf8
sig add-code-point-at-gap self: (addr gap-buffer), c: code-point
sig gap-to-start self: (addr gap-buffer)
sig gap-to-end self: (addr gap-buffer)
sig gap-at-start? _self: (addr gap-buffer) -> _/eax: boolean
sig gap-at-end? _self: (addr gap-buffer) -> _/eax: boolean
sig gap-right _self: (addr gap-buffer) -> _/eax: code-point-utf8
sig gap-left _self: (addr gap-buffer) -> _/eax: code-point-utf8
sig index-of-gap _self: (addr gap-buffer) -> _/eax: int
sig first-code-point-utf8-in-gap-buffer _self: (addr gap-buffer) -> _/eax: code-point-utf8
sig code-point-utf8-before-cursor-in-gap-buffer _self: (addr gap-buffer) -> _/eax: code-point-utf8
sig delete-before-gap _self: (addr gap-buffer)
sig pop-after-gap _self: (addr gap-buffer) -> _/eax: code-point-utf8
sig gap-buffer-equal? _self: (addr gap-buffer), s: (addr array byte) -> _/eax: boolean
sig gap-buffers-equal? self: (addr gap-buffer), g: (addr gap-buffer) -> _/eax: boolean
sig gap-index _self: (addr gap-buffer), _n: int -> _/eax: code-point-utf8
sig copy-gap-buffer _src-ah: (addr handle gap-buffer), _dest-ah: (addr handle gap-buffer)
sig gap-buffer-is-decimal-integer? _self: (addr gap-buffer) -> _/eax: boolean
sig highlight-matching-open-paren? _gap: (addr gap-buffer), render-cursor?: boolean -> _/ebx: boolean, _/edi: int
sig rewind-gap-buffer _self: (addr gap-buffer)
sig gap-buffer-scan-done? _self: (addr gap-buffer) -> _/eax: boolean
sig peek-from-gap-buffer _self: (addr gap-buffer) -> _/eax: code-point-utf8
sig read-from-gap-buffer _self: (addr gap-buffer) -> _/eax: code-point-utf8
sig put-back-from-gap-buffer _self: (addr gap-buffer)
sig skip-spaces-from-gap-buffer self: (addr gap-buffer)
sig edit-gap-buffer self: (addr gap-buffer), key: code-point-utf8
sig gap-to-start-of-next-word self: (addr gap-buffer)
sig gap-to-end-of-previous-word self: (addr gap-buffer)
sig gap-to-previous-start-of-line self: (addr gap-buffer)
sig gap-to-next-end-of-line self: (addr gap-buffer)
sig gap-up self: (addr gap-buffer)
sig gap-down self: (addr gap-buffer)
sig count-columns-to-start-of-line self: (addr gap-buffer) -> _/edx: int
sig gap-to-end-of-line self: (addr gap-buffer)
sig parse-float-decimal in: (addr stream byte) -> _/xmm1: float
sig read-line-from-keyboard keyboard: (addr keyboard), out: (addr stream byte), screen: (addr screen), fg: int, bg: int
