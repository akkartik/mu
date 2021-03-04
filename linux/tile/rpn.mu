fn evaluate functions: (addr handle function), bindings: (addr table), scratch: (addr line), end: (addr word), out: (addr value-stack) {
  var line/eax: (addr line) <- copy scratch
  var word-ah/eax: (addr handle word) <- get line, data
  var curr/eax: (addr word) <- lookup *word-ah
  var curr-stream-storage: (stream byte 0x10)
  var curr-stream/edi: (addr stream byte) <- address curr-stream-storage
  clear-value-stack out
  $evaluate:loop: {
    # precondition (should never hit)
    compare curr, 0
    break-if-=
    # update curr-stream
    emit-word curr, curr-stream
#?     print-string-to-real-screen "eval: "
#?     print-stream-to-real-screen curr-stream
#?     print-string-to-real-screen "\n"
    $evaluate:process-word: {
      ### if curr-stream is an operator, perform it
      ## numbers
      {
        var is-add?/eax: boolean <- stream-data-equal? curr-stream, "+"
        compare is-add?, 0
        break-if-=
        var _b/xmm0: float <- pop-number-from-value-stack out
        var b/xmm1: float <- copy _b
        var a/xmm0: float <- pop-number-from-value-stack out
        a <- add b
        push-number-to-value-stack out, a
        break $evaluate:process-word
      }
      {
        var is-sub?/eax: boolean <- stream-data-equal? curr-stream, "-"
        compare is-sub?, 0
        break-if-=
        var _b/xmm0: float <- pop-number-from-value-stack out
        var b/xmm1: float <- copy _b
        var a/xmm0: float <- pop-number-from-value-stack out
        a <- subtract b
        push-number-to-value-stack out, a
        break $evaluate:process-word
      }
      {
        var is-mul?/eax: boolean <- stream-data-equal? curr-stream, "*"
        compare is-mul?, 0
        break-if-=
        var _b/xmm0: float <- pop-number-from-value-stack out
        var b/xmm1: float <- copy _b
        var a/xmm0: float <- pop-number-from-value-stack out
        a <- multiply b
        push-number-to-value-stack out, a
        break $evaluate:process-word
      }
      {
        var is-div?/eax: boolean <- stream-data-equal? curr-stream, "/"
        compare is-div?, 0
        break-if-=
        var _b/xmm0: float <- pop-number-from-value-stack out
        var b/xmm1: float <- copy _b
        var a/xmm0: float <- pop-number-from-value-stack out
        a <- divide b
        push-number-to-value-stack out, a
        break $evaluate:process-word
      }
      {
        var is-sqrt?/eax: boolean <- stream-data-equal? curr-stream, "sqrt"
        compare is-sqrt?, 0
        break-if-=
        var a/xmm0: float <- pop-number-from-value-stack out
        a <- square-root a
        push-number-to-value-stack out, a
        break $evaluate:process-word
      }
      ## strings/arrays
      {
        var is-len?/eax: boolean <- stream-data-equal? curr-stream, "len"
        compare is-len?, 0
        break-if-=
#?         print-string 0, "is len\n"
        # pop target-val from out
        var out2/esi: (addr value-stack) <- copy out
        var top-addr/ecx: (addr int) <- get out2, top
        compare *top-addr, 0
        break-if-<=
#?         print-string 0, "stack has stuff\n"
        var data-ah/eax: (addr handle array value) <- get out2, data
        var data/eax: (addr array value) <- lookup *data-ah
        var top/edx: int <- copy *top-addr
        top <- decrement
        var dest-offset/edx: (offset value) <- compute-offset data, top
        var target-val/edx: (addr value) <- index data, dest-offset
        # check target-val is a string or array
        var target-type-addr/eax: (addr int) <- get target-val, type
        compare *target-type-addr, 1/string
        {
          break-if-!=
          # compute length
          var src-ah/eax: (addr handle array byte) <- get target-val, text-data
          var src/eax: (addr array byte) <- lookup *src-ah
          var result/ebx: int <- length src
          var result-f/xmm0: float <- convert result
          # save result into target-val
          var type-addr/eax: (addr int) <- get target-val, type
          copy-to *type-addr, 0/int
          var target-string-ah/eax: (addr handle array byte) <- get target-val, text-data
          clear-object target-string-ah
          var target/eax: (addr float) <- get target-val, number-data
          copy-to *target, result-f
          break $evaluate:process-word
        }
        compare *target-type-addr, 2/array
        {
          break-if-!=
          # compute length
          var src-ah/eax: (addr handle array value) <- get target-val, array-data
          var src/eax: (addr array value) <- lookup *src-ah
          var result/ebx: int <- length src
          var result-f/xmm0: float <- convert result
          # save result into target-val
          var type-addr/eax: (addr int) <- get target-val, type
          copy-to *type-addr, 0/int
          var target-array-ah/eax: (addr handle array value) <- get target-val, array-data
          clear-object target-array-ah
          var target/eax: (addr float) <- get target-val, number-data
          copy-to *target, result-f
          break $evaluate:process-word
        }
      }
      ## files
      {
        var is-open?/eax: boolean <- stream-data-equal? curr-stream, "open"
        compare is-open?, 0
        break-if-=
        # pop target-val from out
        var out2/esi: (addr value-stack) <- copy out
        var top-addr/ecx: (addr int) <- get out2, top
        compare *top-addr, 0
        break-if-<=
        var data-ah/eax: (addr handle array value) <- get out2, data
        var data/eax: (addr array value) <- lookup *data-ah
        var top/edx: int <- copy *top-addr
        top <- decrement
        var dest-offset/edx: (offset value) <- compute-offset data, top
        var target-val/edx: (addr value) <- index data, dest-offset
        # check target-val is a string
        var target-type-addr/eax: (addr int) <- get target-val, type
        compare *target-type-addr, 1/string
        break-if-!=
        # open target-val as a filename and save the handle in target-val
        var src-ah/eax: (addr handle array byte) <- get target-val, text-data
        var src/eax: (addr array byte) <- lookup *src-ah
        var result-ah/ecx: (addr handle buffered-file) <- get target-val, file-data
        open src, 0, result-ah  # write? = false
        # save result into target-val
        var type-addr/eax: (addr int) <- get target-val, type
        copy-to *type-addr, 3/file
        var target-string-ah/eax: (addr handle array byte) <- get target-val, text-data
        var filename-ah/ecx: (addr handle array byte) <- get target-val, filename
        copy-object target-string-ah, filename-ah
        clear-object target-string-ah
        break $evaluate:process-word
      }
      {
        var is-read?/eax: boolean <- stream-data-equal? curr-stream, "read"
        compare is-read?, 0
        break-if-=
        # pop target-val from out
        var out2/esi: (addr value-stack) <- copy out
        var top-addr/ecx: (addr int) <- get out2, top
        compare *top-addr, 0
        break-if-<=
        var data-ah/eax: (addr handle array value) <- get out2, data
        var data/eax: (addr array value) <- lookup *data-ah
        var top/edx: int <- copy *top-addr
        top <- decrement
        var dest-offset/edx: (offset value) <- compute-offset data, top
        var target-val/edx: (addr value) <- index data, dest-offset
        # check target-val is a file
        var target-type-addr/eax: (addr int) <- get target-val, type
        compare *target-type-addr, 3/file
        break-if-!=
        # read a line from the file and save in target-val
        # read target-val as a filename and save the handle in target-val
        var file-ah/eax: (addr handle buffered-file) <- get target-val, file-data
        var file/eax: (addr buffered-file) <- lookup *file-ah
        var s: (stream byte 0x100)
        var s-addr/ecx: (addr stream byte) <- address s
        read-line-buffered file, s-addr
        var target/eax: (addr handle array byte) <- get target-val, text-data
        stream-to-array s-addr, target
        # save result into target-val
        var type-addr/eax: (addr int) <- get target-val, type
        copy-to *type-addr, 1/string
        var target-file-ah/eax: (addr handle buffered-file) <- get target-val, file-data
        clear-object target-file-ah
        break $evaluate:process-word
      }
      {
        var is-slurp?/eax: boolean <- stream-data-equal? curr-stream, "slurp"
        compare is-slurp?, 0
        break-if-=
        # pop target-val from out
        var out2/esi: (addr value-stack) <- copy out
        var top-addr/ecx: (addr int) <- get out2, top
        compare *top-addr, 0
        break-if-<=
        var data-ah/eax: (addr handle array value) <- get out2, data
        var data/eax: (addr array value) <- lookup *data-ah
        var top/edx: int <- copy *top-addr
        top <- decrement
        var dest-offset/edx: (offset value) <- compute-offset data, top
        var target-val/edx: (addr value) <- index data, dest-offset
        # check target-val is a file
        var target-type-addr/eax: (addr int) <- get target-val, type
        compare *target-type-addr, 3/file
        break-if-!=
        # slurp all contents from file and save in target-val
        # read target-val as a filename and save the handle in target-val
        var file-ah/eax: (addr handle buffered-file) <- get target-val, file-data
        var file/eax: (addr buffered-file) <- lookup *file-ah
        var s: (stream byte 0x100)
        var s-addr/ecx: (addr stream byte) <- address s
        slurp file, s-addr
        var target/eax: (addr handle array byte) <- get target-val, text-data
        stream-to-array s-addr, target
        # save result into target-val
        var type-addr/eax: (addr int) <- get target-val, type
        copy-to *type-addr, 1/string
        var target-file-ah/eax: (addr handle buffered-file) <- get target-val, file-data
        clear-object target-file-ah
        break $evaluate:process-word
      }
      {
        var is-lines?/eax: boolean <- stream-data-equal? curr-stream, "lines"
        compare is-lines?, 0
        break-if-=
        # pop target-val from out
        var out2/esi: (addr value-stack) <- copy out
        var top-addr/ecx: (addr int) <- get out2, top
        compare *top-addr, 0
        break-if-<=
        var data-ah/eax: (addr handle array value) <- get out2, data
        var data/eax: (addr array value) <- lookup *data-ah
        var top/edx: int <- copy *top-addr
        top <- decrement
        var dest-offset/edx: (offset value) <- compute-offset data, top
        var target-val/edx: (addr value) <- index data, dest-offset
        # check target-val is a file
        var target-type-addr/eax: (addr int) <- get target-val, type
        compare *target-type-addr, 3/file
        break-if-!=
        # read all lines from file and save as an array of strings in target-val
        # read target-val as a filename and save the handle in target-val
        var file-ah/eax: (addr handle buffered-file) <- get target-val, file-data
        var file/eax: (addr buffered-file) <- lookup *file-ah
        var s: (stream byte 0x100)
        var s-addr/ecx: (addr stream byte) <- address s
        slurp file, s-addr
        var tmp-ah/eax: (addr handle array byte) <- get target-val, text-data
        stream-to-array s-addr, tmp-ah
        var tmp/eax: (addr array byte) <- lookup *tmp-ah
#?         enable-screen-type-mode
#?         print-string 0, tmp
        var h: (handle array (handle array byte))
        {
          var ah/edx: (addr handle array (handle array byte)) <- address h
          split-string tmp, 0xa, ah
        }
        var target/eax: (addr handle array value) <- get target-val, array-data
        save-lines h, target
        # save result into target-val
        var type-addr/eax: (addr int) <- get target-val, type
        copy-to *type-addr, 2/array
        var target-file-ah/eax: (addr handle buffered-file) <- get target-val, file-data
        var empty-file: (handle buffered-file)
        copy-handle empty-file, target-file-ah
        var target-text-ah/eax: (addr handle array byte) <- get target-val, text-data
        var empty-text: (handle array byte)
        copy-handle empty-text, target-text-ah
        break $evaluate:process-word
      }
      ## screens
      {
        var is-fake-screen?/eax: boolean <- stream-data-equal? curr-stream, "fake-screen"
        compare is-fake-screen?, 0
        break-if-=
        var out2/esi: (addr value-stack) <- copy out
        var top-addr/ecx: (addr int) <- get out2, top
        compare *top-addr, 0
        break-if-<=
        # pop width and height from out
        var nrows-f/xmm0: float <- pop-number-from-value-stack out2
        var nrows/edx: int <- convert nrows-f
        var ncols-f/xmm0: float <- pop-number-from-value-stack out2
        var ncols/ebx: int <- convert ncols-f
        # define a new screen with those dimensions
        var screen-h: (handle screen)
        var screen-ah/eax: (addr handle screen) <- address screen-h
        allocate screen-ah
        var screen/eax: (addr screen) <- lookup screen-h
        initialize-screen screen, nrows, ncols
        # push screen to stack
        var data-ah/eax: (addr handle array value) <- get out2, data
        var data/eax: (addr array value) <- lookup *data-ah
        var top/edx: int <- copy *top-addr
        increment *top-addr
        var dest-offset/edx: (offset value) <- compute-offset data, top
        var target-val/edx: (addr value) <- index data, dest-offset
        var type/eax: (addr int) <- get target-val, type
        copy-to *type, 4/screen
        var dest/eax: (addr handle screen) <- get target-val, screen-data
        copy-handle screen-h, dest
        break $evaluate:process-word
      }
      {
        var is-print?/eax: boolean <- stream-data-equal? curr-stream, "print"
        compare is-print?, 0
        break-if-=
        var out2/esi: (addr value-stack) <- copy out
        var top-addr/ecx: (addr int) <- get out2, top
        compare *top-addr, 0
        break-if-<=
        # pop string from out
        var top-addr/ecx: (addr int) <- get out2, top
        compare *top-addr, 0
        break-if-<=
        decrement *top-addr
        var data-ah/eax: (addr handle array value) <- get out2, data
        var _data/eax: (addr array value) <- lookup *data-ah
        var data/edi: (addr array value) <- copy _data
        var top/eax: int <- copy *top-addr
        var dest-offset/edx: (offset value) <- compute-offset data, top
        var s/esi: (addr value) <- index data, dest-offset
        # select target screen from top of out (but don't pop it)
        compare *top-addr, 0
        break-if-<=
        var top/eax: int <- copy *top-addr
        top <- decrement
        var dest-offset/edx: (offset value) <- compute-offset data, top
        var target-val/edx: (addr value) <- index data, dest-offset
        var type/eax: (addr int) <- get target-val, type
        compare *type, 4/screen
        break-if-!=
        # print string to target screen
        var dest-ah/eax: (addr handle screen) <- get target-val, screen-data
        var dest/eax: (addr screen) <- lookup *dest-ah
        var r/ecx: (addr int) <- get dest, cursor-row
        var c/edx: (addr int) <- get dest, cursor-col
        render-value-at dest, *r, *c, s, 0
        break $evaluate:process-word
      }
      {
        var is-move?/eax: boolean <- stream-data-equal? curr-stream, "move"
        compare is-move?, 0
        break-if-=
        var out2/esi: (addr value-stack) <- copy out
        # pop args
        var r-f/xmm0: float <- pop-number-from-value-stack out2
        var r/ecx: int <- convert r-f
        var c-f/xmm0: float <- pop-number-from-value-stack out2
        var c/edx: int <- convert c-f
        # select screen from top of out (but don't pop it)
        var top-addr/ebx: (addr int) <- get out2, top
        compare *top-addr, 0
        break-if-<=
        var data-ah/eax: (addr handle array value) <- get out2, data
        var _data/eax: (addr array value) <- lookup *data-ah
        var data/edi: (addr array value) <- copy _data
        var top/eax: int <- copy *top-addr
        top <- decrement
        var target-offset/eax: (offset value) <- compute-offset data, top
        var target-val/ebx: (addr value) <- index data, target-offset
        var type/eax: (addr int) <- get target-val, type
        compare *type, 4/screen
        break-if-!=
        var target-ah/eax: (addr handle screen) <- get target-val, screen-data
        var target/eax: (addr screen) <- lookup *target-ah
        move-cursor target, r, c
        break $evaluate:process-word
      }
      {
        var is-up?/eax: boolean <- stream-data-equal? curr-stream, "up"
        compare is-up?, 0
        break-if-=
        var out2/esi: (addr value-stack) <- copy out
        var top-addr/ebx: (addr int) <- get out2, top
        compare *top-addr, 0
        break-if-<=
        # pop args
        var d-f/xmm0: float <- pop-number-from-value-stack out2
        var d/ecx: int <- convert d-f
        # select screen from top of out (but don't pop it)
        compare *top-addr, 0
        break-if-<=
        var data-ah/eax: (addr handle array value) <- get out2, data
        var _data/eax: (addr array value) <- lookup *data-ah
        var data/edi: (addr array value) <- copy _data
        var top/eax: int <- copy *top-addr
        top <- decrement
        var target-offset/eax: (offset value) <- compute-offset data, top
        var target-val/ebx: (addr value) <- index data, target-offset
        var type/eax: (addr int) <- get target-val, type
        compare *type, 4/screen
        break-if-!=
        var target-ah/eax: (addr handle screen) <- get target-val, screen-data
        var _target/eax: (addr screen) <- lookup *target-ah
        var target/edi: (addr screen) <- copy _target
        var r/edx: (addr int) <- get target, cursor-row
        var c/eax: (addr int) <- get target, cursor-col
        var col/eax: int <- copy *c
        {
          compare d, 0
          break-if-<=
          compare *r, 1
          break-if-<=
          print-string target "│"
          decrement *r
          move-cursor target, *r, col
          d <- decrement
          loop
        }
        break $evaluate:process-word
      }
      {
        var is-down?/eax: boolean <- stream-data-equal? curr-stream, "down"
        compare is-down?, 0
        break-if-=
        var out2/esi: (addr value-stack) <- copy out
        var top-addr/ebx: (addr int) <- get out2, top
        compare *top-addr, 0
        break-if-<=
        # pop args
        var d-f/xmm0: float <- pop-number-from-value-stack out2
        var d/ecx: int <- convert d-f
        # select screen from top of out (but don't pop it)
        compare *top-addr, 0
        break-if-<=
        var data-ah/eax: (addr handle array value) <- get out2, data
        var _data/eax: (addr array value) <- lookup *data-ah
        var data/edi: (addr array value) <- copy _data
        var top/eax: int <- copy *top-addr
        top <- decrement
        var target-offset/eax: (offset value) <- compute-offset data, top
        var target-val/ebx: (addr value) <- index data, target-offset
        var type/eax: (addr int) <- get target-val, type
        compare *type, 4/screen
        break-if-!=
        var target-ah/eax: (addr handle screen) <- get target-val, screen-data
        var _target/eax: (addr screen) <- lookup *target-ah
        var target/edi: (addr screen) <- copy _target
        var bound-a/ebx: (addr int) <- get target, num-rows
        var bound/ebx: int <- copy *bound-a
        var r/edx: (addr int) <- get target, cursor-row
        var c/eax: (addr int) <- get target, cursor-col
        var col/eax: int <- copy *c
        {
          compare d, 0
          break-if-<=
          compare *r, bound
          break-if->=
          print-string target "│"
          increment *r
          move-cursor target, *r, col
          d <- decrement
          loop
        }
        break $evaluate:process-word
      }
      {
        var is-left?/eax: boolean <- stream-data-equal? curr-stream, "left"
        compare is-left?, 0
        break-if-=
        var out2/esi: (addr value-stack) <- copy out
        var top-addr/ebx: (addr int) <- get out2, top
        compare *top-addr, 0
        break-if-<=
        # pop args
        var d-f/xmm0: float <- pop-number-from-value-stack out2
        var d/ecx: int <- convert d-f
        # select screen from top of out (but don't pop it)
        compare *top-addr, 0
        break-if-<=
        var data-ah/eax: (addr handle array value) <- get out2, data
        var _data/eax: (addr array value) <- lookup *data-ah
        var data/edi: (addr array value) <- copy _data
        var top/eax: int <- copy *top-addr
        top <- decrement
        var target-offset/eax: (offset value) <- compute-offset data, top
        var target-val/ebx: (addr value) <- index data, target-offset
        var type/eax: (addr int) <- get target-val, type
        compare *type, 4/screen
        break-if-!=
        var target-ah/eax: (addr handle screen) <- get target-val, screen-data
        var _target/eax: (addr screen) <- lookup *target-ah
        var target/edi: (addr screen) <- copy _target
        var c/edx: (addr int) <- get target, cursor-col
        var r/eax: (addr int) <- get target, cursor-row
        var row/eax: int <- copy *r
        {
          compare d, 0
          break-if-<=
          compare *c, 1
          break-if-<=
          print-string target "─"
          decrement *c
          decrement *c  # second one to undo the print above
          move-cursor target, row, *c
          d <- decrement
          loop
        }
        break $evaluate:process-word
      }
      {
        var is-right?/eax: boolean <- stream-data-equal? curr-stream, "right"
        compare is-right?, 0
        break-if-=
        var out2/esi: (addr value-stack) <- copy out
        var top-addr/ebx: (addr int) <- get out2, top
        compare *top-addr, 0
        break-if-<=
        # pop args
        var _d/xmm0: float <- pop-number-from-value-stack out2
        var d/ecx: int <- convert _d
        # select screen from top of out (but don't pop it)
        compare *top-addr, 0
        break-if-<=
        var data-ah/eax: (addr handle array value) <- get out2, data
        var _data/eax: (addr array value) <- lookup *data-ah
        var data/edi: (addr array value) <- copy _data
        var top/eax: int <- copy *top-addr
        top <- decrement
        var target-offset/eax: (offset value) <- compute-offset data, top
        var target-val/ebx: (addr value) <- index data, target-offset
        var type/eax: (addr int) <- get target-val, type
        compare *type, 4/screen
        break-if-!=
        var target-ah/eax: (addr handle screen) <- get target-val, screen-data
        var _target/eax: (addr screen) <- lookup *target-ah
        var target/edi: (addr screen) <- copy _target
        var bound-a/ebx: (addr int) <- get target, num-rows
        var bound/ebx: int <- copy *bound-a
        var c/edx: (addr int) <- get target, cursor-col
        var r/eax: (addr int) <- get target, cursor-row
        var row/eax: int <- copy *r
        {
          compare d, 0
          break-if-<=
          compare *c, bound
          break-if->=
          print-string target "─"
          # no increment; the print took care of it
          move-cursor target, row, *c
          d <- decrement
          loop
        }
        break $evaluate:process-word
      }
      ## HACKS: we're trying to avoid turning this into Forth
      {
        var is-dup?/eax: boolean <- stream-data-equal? curr-stream, "dup"
        compare is-dup?, 0
        break-if-=
        # read src-val from out
        var out2/esi: (addr value-stack) <- copy out
        var top-addr/ecx: (addr int) <- get out2, top
        compare *top-addr, 0
        break-if-<=
        var data-ah/eax: (addr handle array value) <- get out2, data
        var data/eax: (addr array value) <- lookup *data-ah
        var top/ecx: int <- copy *top-addr
        top <- decrement
        var offset/edx: (offset value) <- compute-offset data, top
        var src-val/edx: (addr value) <- index data, offset
        # push a copy of it
        top <- increment
        var offset/ebx: (offset value) <- compute-offset data, top
        var target-val/ebx: (addr value) <- index data, offset
        copy-object src-val, target-val
        # commit
        var top-addr/ecx: (addr int) <- get out2, top
        increment *top-addr
        break $evaluate:process-word
      }
      {
        var is-swap?/eax: boolean <- stream-data-equal? curr-stream, "swap"
        compare is-swap?, 0
        break-if-=
        # read top-val from out
        var out2/esi: (addr value-stack) <- copy out
        var top-addr/ecx: (addr int) <- get out2, top
        compare *top-addr, 0
        break-if-<=
        var data-ah/eax: (addr handle array value) <- get out2, data
        var data/eax: (addr array value) <- lookup *data-ah
        var top/ecx: int <- copy *top-addr
        top <- decrement
        var offset/edx: (offset value) <- compute-offset data, top
        var top-val/edx: (addr value) <- index data, offset
        # read next val from out
        top <- decrement
        var offset/ebx: (offset value) <- compute-offset data, top
        var pen-top-val/ebx: (addr value) <- index data, offset
        # swap
        var tmp: value
        var tmp-a/eax: (addr value) <- address tmp
        copy-object top-val, tmp-a
        copy-object pen-top-val, top-val
        copy-object tmp-a, pen-top-val
        break $evaluate:process-word
      }
      ### if curr-stream defines a binding, save top of stack to bindings
      {
        var done?/eax: boolean <- stream-empty? curr-stream
        compare done?, 0/false
        break-if-!=
        var new-byte/eax: byte <- read-byte curr-stream
        compare new-byte, 0x3d/=
        break-if-!=
        # pop target-val from out
        var out2/esi: (addr value-stack) <- copy out
        var top-addr/ecx: (addr int) <- get out2, top
        compare *top-addr, 0
        break-if-<=
        var data-ah/eax: (addr handle array value) <- get out2, data
        var data/eax: (addr array value) <- lookup *data-ah
        var top/edx: int <- copy *top-addr
        top <- decrement
        var dest-offset/edx: (offset value) <- compute-offset data, top
        var target-val/edx: (addr value) <- index data, dest-offset
        # create binding from curr-stream to target-val
        var key-h: (handle array byte)
        var key/ecx: (addr handle array byte) <- address key-h
        stream-to-array curr-stream, key
        bind-in-table bindings, key, target-val
        break $evaluate:process-word
      }
      rewind-stream curr-stream
      ### if curr-stream is a known function name, call it appropriately
      {
        var callee-h: (handle function)
        var callee-ah/eax: (addr handle function) <- address callee-h
        find-function functions, curr-stream, callee-ah
        var callee/eax: (addr function) <- lookup *callee-ah
        compare callee, 0
        break-if-=
        perform-call callee, out, functions
        break $evaluate:process-word
      }
      ### if it's a name, push its value
      {
        compare bindings, 0
        break-if-=
        var tmp: (handle array byte)
        var curr-string-ah/edx: (addr handle array byte) <- address tmp
        stream-to-array curr-stream, curr-string-ah  # unfortunate leak
        var curr-string/eax: (addr array byte) <- lookup *curr-string-ah
        var val-storage: (handle value)
        var val-ah/edi: (addr handle value) <- address val-storage
        lookup-binding bindings, curr-string, val-ah
        var val/eax: (addr value) <- lookup *val-ah
        compare val, 0
        break-if-=
        push-value-stack out, val
        break $evaluate:process-word
      }
      ### if the word starts with a quote and ends with a quote, turn it into a string
      {
        var start/eax: byte <- stream-first curr-stream
        compare start, 0x22/double-quote
        break-if-!=
        var end/eax: byte <- stream-final curr-stream
        compare end, 0x22/double-quote
        break-if-!=
        var h: (handle array byte)
        var s/eax: (addr handle array byte) <- address h
        unquote-stream-to-array curr-stream, s  # leak
        push-string-to-value-stack out, *s
        break $evaluate:process-word
      }
      ### if the word starts with a '[' and ends with a ']', turn it into an array
      {
        var start/eax: byte <- stream-first curr-stream
        compare start, 0x5b/[
        break-if-!=
        var end/eax: byte <- stream-final curr-stream
        compare end, 0x5d/]
        break-if-!=
        # wastefully create a new input string to strip quotes
        var h: (handle array value)
        var input-ah/eax: (addr handle array byte) <- address h
        unquote-stream-to-array curr-stream, input-ah  # leak
        # wastefully parse input into int-array
        # TODO: support parsing arrays of other types
        var input/eax: (addr array byte) <- lookup *input-ah
        var h2: (handle array int)
        var int-array-ah/esi: (addr handle array int) <- address h2
        parse-array-of-decimal-ints input, int-array-ah  # leak
        var _int-array/eax: (addr array int) <- lookup *int-array-ah
        var int-array/esi: (addr array int) <- copy _int-array
        var len/ebx: int <- length int-array
        # push value-array of same size as int-array
        var h3: (handle array value)
        var value-array-ah/eax: (addr handle array value) <- address h3
        populate value-array-ah, len
        push-array-to-value-stack out, *value-array-ah
        # copy int-array into value-array
        var _value-array/eax: (addr array value) <- lookup *value-array-ah
        var value-array/edi: (addr array value) <- copy _value-array
        var i/eax: int <- copy 0
        {
          compare i, len
          break-if->=
          var src-addr/ecx: (addr int) <- index int-array, i
          var src/ecx: int <- copy *src-addr
          var src-f/xmm0: float <- convert src
          var dest-offset/edx: (offset value) <- compute-offset value-array, i
          var dest-val/edx: (addr value) <- index value-array, dest-offset
          var dest/edx: (addr float) <- get dest-val, number-data
          copy-to *dest, src-f
          i <- increment
          loop
        }
        break $evaluate:process-word
      }
      ### otherwise assume it's a literal number and push it
      {
        var n/eax: int <- parse-decimal-int-from-stream curr-stream
        var n-f/xmm0: float <- convert n
        push-number-to-value-stack out, n-f
      }
    }
    # termination check
    compare curr, end
    break-if-=
    # update
    var next-word-ah/edx: (addr handle word) <- get curr, next
    curr <- lookup *next-word-ah
    #
    loop
  }
  # process next line if necessary
  var line/eax: (addr line) <- copy scratch
  var next-line-ah/eax: (addr handle line) <- get line, next
  var next-line/eax: (addr line) <- lookup *next-line-ah
  compare next-line, 0
  break-if-=
  evaluate functions, bindings, next-line, end, out
}

fn test-evaluate {
  var line-storage: line
  var line/esi: (addr line) <- address line-storage
  var first-word-ah/eax: (addr handle word) <- get line-storage, data
  allocate-word-with first-word-ah, "3"
  append-word-with *first-word-ah, "=a"
  var next-line-ah/eax: (addr handle line) <- get line-storage, next
  allocate next-line-ah
  var next-line/eax: (addr line) <- lookup *next-line-ah
  var first-word-ah/eax: (addr handle word) <- get next-line, data
  allocate-word-with first-word-ah, "a"
  var functions-storage: (handle function)
  var functions/ecx: (addr handle function) <- address functions-storage
  var table-storage: table
  var table/ebx: (addr table) <- address table-storage
  initialize-table table, 0x10
  var stack-storage: value-stack
  var stack/edi: (addr value-stack) <- address stack-storage
  initialize-value-stack stack, 0x10
  evaluate functions, table, line, 0, stack
  var x-f/xmm0: float <- pop-number-from-value-stack stack
  var x/eax: int <- convert x-f
  check-ints-equal x, 3, "F - test-evaluate"
}

fn find-function first: (addr handle function), name: (addr stream byte), out: (addr handle function) {
  var curr/esi: (addr handle function) <- copy first
  $find-function:loop: {
    var _f/eax: (addr function) <- lookup *curr
    var f/ecx: (addr function) <- copy _f
    compare f, 0
    break-if-=
    var curr-name-ah/eax: (addr handle array byte) <- get f, name
    var curr-name/eax: (addr array byte) <- lookup *curr-name-ah
    var done?/eax: boolean <- stream-data-equal? name, curr-name
    compare done?, 0/false
    {
      break-if-=
      copy-handle *curr, out
      break $find-function:loop
    }
    curr <- get f, next
    loop
  }
}

fn perform-call _callee: (addr function), caller-stack: (addr value-stack), functions: (addr handle function) {
  var callee/ecx: (addr function) <- copy _callee
  # create bindings for args
  var table-storage: table
  var table/esi: (addr table) <- address table-storage
  initialize-table table, 0x10
  bind-args callee, caller-stack, table
  # obtain body
  var body-ah/eax: (addr handle line) <- get callee, body
  var body/eax: (addr line) <- lookup *body-ah
  # perform call
  var stack-storage: value-stack
  var stack/edi: (addr value-stack) <- address stack-storage
  initialize-value-stack stack, 0x10
#?   print-string-to-real-screen "about to enter recursive eval\n"
  evaluate functions, table, body, 0, stack
#?   print-string-to-real-screen "exited recursive eval\n"
  # pop target-val from out
  var top-addr/ecx: (addr int) <- get stack, top
  compare *top-addr, 0
  break-if-<=
  var data-ah/eax: (addr handle array value) <- get stack, data
  var data/eax: (addr array value) <- lookup *data-ah
  var top/edx: int <- copy *top-addr
  top <- decrement
  var dest-offset/edx: (offset value) <- compute-offset data, top
  var target-val/edx: (addr value) <- index data, dest-offset
  # stitch target-val into caller-stack
  push-value-stack caller-stack, target-val
}

# pop args from the caller-stack and bind them to successive args
# implies: function args are stored in reverse order
fn bind-args _callee: (addr function), _caller-stack: (addr value-stack), table: (addr table) {
  var callee/ecx: (addr function) <- copy _callee
  var curr-arg-ah/eax: (addr handle word) <- get callee, args
  var curr-arg/eax: (addr word) <- lookup *curr-arg-ah
  #
  var curr-key-storage: (handle array byte)
  var curr-key/edx: (addr handle array byte) <- address curr-key-storage
  {
    compare curr-arg, 0
    break-if-=
    # create binding
    word-to-string curr-arg, curr-key
    {
      # pop target-val from caller-stack
      var caller-stack/esi: (addr value-stack) <- copy _caller-stack
      var top-addr/ecx: (addr int) <- get caller-stack, top
      compare *top-addr, 0
      break-if-<=
      decrement *top-addr
      var data-ah/eax: (addr handle array value) <- get caller-stack, data
      var data/eax: (addr array value) <- lookup *data-ah
      var top/ebx: int <- copy *top-addr
      var dest-offset/ebx: (offset value) <- compute-offset data, top
      var target-val/ebx: (addr value) <- index data, dest-offset
      # create binding from curr-key to target-val
      bind-in-table table, curr-key, target-val
    }
    #
    var next-arg-ah/edx: (addr handle word) <- get curr-arg, next
    curr-arg <- lookup *next-arg-ah
    loop
  }
}

# Copy of 'simplify' that just tracks the maximum stack depth needed
# Doesn't actually need to simulate the stack, since every word has a predictable effect.
fn max-stack-depth first-word: (addr word), final-word: (addr word) -> _/edi: int {
  var curr-word/eax: (addr word) <- copy first-word
  var curr-depth/ecx: int <- copy 0
  var result/edi: int <- copy 0
  $max-stack-depth:loop: {
    $max-stack-depth:process-word: {
      # handle operators
      {
        var is-add?/eax: boolean <- word-equal? curr-word, "+"
        compare is-add?, 0
        break-if-=
        curr-depth <- decrement
        break $max-stack-depth:process-word
      }
      {
        var is-sub?/eax: boolean <- word-equal? curr-word, "-"
        compare is-sub?, 0
        break-if-=
        curr-depth <- decrement
        break $max-stack-depth:process-word
      }
      {
        var is-mul?/eax: boolean <- word-equal? curr-word, "*"
        compare is-mul?, 0
        break-if-=
        curr-depth <- decrement
        break $max-stack-depth:process-word
      }
      # otherwise it's an int (do we need error-checking?)
      curr-depth <- increment
      # update max depth if necessary
      {
        compare curr-depth, result
        break-if-<=
        result <- copy curr-depth
      }
    }
    # if curr-word == final-word break
    compare curr-word, final-word
    break-if-=
    # curr-word = curr-word->next
    var next-word-ah/edx: (addr handle word) <- get curr-word, next
    curr-word <- lookup *next-word-ah
    #
    loop
  }
  return result
}
