#lang racket/base
;; For legal info, see file "info.rkt"

(require racket/cmdline
         racket/date
         "charterm.rkt")

(define (%charterm:string-pad-or-truncate str width)
  (let ((len (string-length str)))
    (cond ((= len width) str)
          ((< len width) (string-append str (make-string (- width len) #\space)))
          (else (substring str 0 width)))))

(define (%charterm:bytes-pad-or-truncate bstr width)
  (let ((len (bytes-length bstr)))
    (cond ((= len width) bstr)
          ((< len width)
           (let ((new-bstr (make-bytes width 32)))
             (bytes-copy! new-bstr 0 bstr)
             new-bstr))
          (else (subbytes bstr 0 width)))))

(define-struct %charterm:demo-input
  (x y width bytes used cursor)
  #:mutable)

(define (%charterm:make-demo-input x y width bstr)
  (let ((new-bstr (%charterm:bytes-pad-or-truncate bstr width))
        (used     (min (bytes-length bstr) width)))
    (make-%charterm:demo-input x
                               y
                               width
                               new-bstr
                               used
                               used)))

(define (%charterm:demo-input-redraw di)
  (charterm-cursor (%charterm:demo-input-x di)
                   (%charterm:demo-input-y di))
  (charterm-normal)
  (charterm-underline)
  (charterm-display (%charterm:demo-input-bytes di)
                    #:width (%charterm:demo-input-width di))
  (charterm-normal))

(define (%charterm:demo-input-put-cursor di)
  ;; Note: Commented-out debugging code:
  ;;
  ;; (and #t
  ;;      (begin (charterm-normal)
  ;;             (charterm-cursor (+ (%charterm:demo-input-x     di)
  ;;                                   (%charterm:demo-input-width di)
  ;;                                   1)
  ;;                                (%charterm:demo-input-y di))
  ;;             (charterm-display #" cursor: "
  ;;                               (%charterm:demo-input-cursor di)
  ;;                               #" used: "
  ;;                               (%charterm:demo-input-used di))
  ;;             (charterm-clear-line-right)))
  (charterm-cursor (+ (%charterm:demo-input-x      di)
                      (%charterm:demo-input-cursor di))
                   (%charterm:demo-input-y di)))

(define (%charterm:demo-input-cursor-left di)
  (let ((cursor (%charterm:demo-input-cursor di)))
    (if (zero? cursor)
        (begin (charterm-bell)
               (%charterm:demo-input-put-cursor di))
        (begin (set-%charterm:demo-input-cursor! di (- cursor 1))
               (%charterm:demo-input-put-cursor di)))))

(define (%charterm:demo-input-cursor-right di)
  (let ((cursor (%charterm:demo-input-cursor di)))
    (if (= cursor (%charterm:demo-input-used di))
        (begin (charterm-bell)
               (%charterm:demo-input-put-cursor di))
        (begin (set-%charterm:demo-input-cursor! di (+ cursor 1))
               (%charterm:demo-input-put-cursor di)))))

(define (%charterm:demo-input-backspace di)
  (let ((cursor (%charterm:demo-input-cursor di)))
    (if (zero? cursor)
        (begin (charterm-bell)
               (%charterm:demo-input-put-cursor di))
        (let ((bstr (%charterm:demo-input-bytes di))
              (used (%charterm:demo-input-used di)))
          ;; TODO: test beginning/end of buffer, of used, of width
          (bytes-copy! bstr (- cursor 1) bstr cursor used)
          (bytes-set! bstr (- used 1) 32)
          (set-%charterm:demo-input-used! di (- used 1))
          (set-%charterm:demo-input-cursor! di (- cursor 1))
          (%charterm:demo-input-redraw di)
          (%charterm:demo-input-put-cursor di)))))

(define (%charterm:demo-input-delete di)
  (let ((cursor (%charterm:demo-input-cursor di))
        (used   (%charterm:demo-input-used   di)))
    (if (= cursor used)
        (begin (charterm-bell)
               (%charterm:demo-input-put-cursor di))
        (let ((bstr (%charterm:demo-input-bytes di)))
          (or (= cursor used)
              (bytes-copy! bstr cursor bstr (+ 1 cursor) used))
          (bytes-set! bstr (- used 1) 32)
          (set-%charterm:demo-input-used! di (- used 1))
          (%charterm:demo-input-redraw     di)
          (%charterm:demo-input-put-cursor di)))))

(define (%charterm:demo-input-insert-byte di new-byte)
  (let ((used  (%charterm:demo-input-used  di))
        (width (%charterm:demo-input-width di)))
    (if (= used width)
        (begin (charterm-bell)
               (%charterm:demo-input-put-cursor di))
        (let ((bstr   (%charterm:demo-input-bytes  di))
              (cursor (%charterm:demo-input-cursor di)))
          (or (= cursor used)
              (bytes-copy! bstr (+ cursor 1) bstr cursor used))
          (bytes-set! bstr cursor new-byte)
          (set-%charterm:demo-input-used! di (+ 1 used))
          (set-%charterm:demo-input-cursor! di (+ cursor 1))
          (%charterm:demo-input-redraw di)
          (%charterm:demo-input-put-cursor di)))))

(provide charterm-demo)
(define (charterm-demo #:tty     (tty     #f)
                       #:escape? (escape? #t))
  (let ((data-row 4)
        (di       (%charterm:make-demo-input 10 2 18 #"Hello, world!")))
    (with-charterm
     (let ((ct (current-charterm)))
       (let/ec done-ec
         (let loop-remember-read-screen-size ((last-read-col-count 0)
                                              (last-read-row-count 0))

           (let loop-maybe-check-screen-size ()
             (let*-values (((read-col-count read-row-count)
                            (if (or (equal? 0 last-read-col-count)
                                    (equal? 0 last-read-row-count)
                                    (not (charterm-byte-ready?)))
                                (charterm-screen-size)
                                (values last-read-col-count
                                        last-read-row-count)))
                           ((read-screen-size? col-count row-count)
                            (if (and read-col-count read-row-count)
                                (values #t
                                        read-col-count
                                        read-row-count)
                                (values #f
                                        (or read-col-count 80)
                                        (or read-row-count 24))))
                           ((read-screen-size-changed?)
                            (not (and (equal? read-col-count
                                              last-read-col-count)
                                      (equal? read-row-count
                                              last-read-row-count))))
                           ((clock-col)
                            (let ((clock-col (- col-count 8)))
                              (if (< clock-col 15)
                                  #f
                                  clock-col))))
               ;; Did screen size change?
               (if read-screen-size-changed?

                   ;; Screen size changed.
                   (begin (charterm-clear-screen)
                          (charterm-cursor 1 1)
                          (charterm-inverse)
                          (charterm-display (%charterm:string-pad-or-truncate " charterm Demo"
                                                                              col-count))
                          (charterm-normal)

                          (charterm-cursor 1 2)
                          (charterm-inverse)
                          (charterm-display #" Input: ")
                          (charterm-normal)
                          (%charterm:demo-input-redraw di)

                          (charterm-cursor 1 data-row)
                          (if escape?
                               (begin
                                 (charterm-display "To quit, press ")
                                 (charterm-bold)
                                 (charterm-display "Esc")
                                 (charterm-normal)
                                 (charterm-display "."))
                               (charterm-display "There is no escape from this demo."))
                               
                          (charterm-cursor 1 data-row)
                          (charterm-insert-line)
                          (charterm-display "termvar ")
                          (charterm-bold)
                          (charterm-display (charterm-termvar ct))
                          (charterm-normal)
                          (charterm-display ", protocol ")
                          (charterm-bold)
                          (charterm-display (charterm-protocol ct))
                          (charterm-normal)
                          (charterm-display ", keydec ")
                          (charterm-bold)
                          (charterm-display (charterm-keydec-id (charterm-keydec ct)))
                          (charterm-normal)

                          (charterm-cursor 1 data-row)
                          (charterm-insert-line)
                          (charterm-display #"Screen size: ")
                          (charterm-bold)
                          (charterm-display col-count)
                          (charterm-normal)
                          (charterm-display #" x ")
                          (charterm-bold)
                          (charterm-display row-count)
                          (charterm-normal)
                          (or read-screen-size?
                              (charterm-display #" (guessing; terminal would not tell us)"))

                          (charterm-cursor 1 data-row)
                          (charterm-insert-line)
                          (charterm-display #"Widths:")
                          (for-each (lambda (bytes)
                                      (charterm-display #" [")
                                      (charterm-underline)
                                      (charterm-display bytes #:width 3)
                                      (charterm-normal)
                                      (charterm-display #"]"))
                                    '(#"" #"a" #"ab" #"abc" #"abcd"))

                          ;; (and (eq? 'wy50 (charterm-protocol ct))
                          ;;      (begin
                          ;;        (charterm-cursor 1 data-row)
                          ;;        (charterm-insert-line)
                          ;;        (charterm-display #"Wyse WY-50 delete character: ab*c\010\010\eW")))

                          (loop-remember-read-screen-size read-col-count
                                                          read-row-count))
                   ;; Screen size didn't change (or we didn't check).
                   (begin
                     (and clock-col
                          (begin (charterm-inverse)
                                 (charterm-cursor clock-col 1)
                                 (charterm-display (parameterize ((date-display-format 'iso-8601))
                                                     (substring (date->string (current-date) #t)
                                                                11)))
                                 (charterm-normal)))

                     (let loop-fast-next-key ()
                       (%charterm:demo-input-put-cursor di)
                       (let ((keyinfo (charterm-read-keyinfo #:timeout 1)))
                         (if keyinfo
                             (let ((keycode (charterm-keyinfo-keycode keyinfo)))
                               (charterm-cursor 1 data-row)
                               (charterm-insert-line)
                               (charterm-display "Read key: ")
                               (charterm-bold)
                               (charterm-display (or (charterm-keyinfo-keylabel keyinfo) "???"))
                               (charterm-normal)
                               (charterm-display (format " ~S"
                                                         `(,(charterm-keyinfo-keyset-id    keyinfo)
                                                           ,(charterm-keyinfo-bytelang     keyinfo)
                                                           ,(charterm-keyinfo-bytelist     keyinfo)
                                                           ,@(charterm-keyinfo-all-keycodes keyinfo))))
                               (if (char? keycode)
                                   (let ((key-num (char->integer keycode)))
                                     (if (<= 32 key-num 126)
                                         (begin (%charterm:demo-input-insert-byte di key-num)
                                                (loop-fast-next-key))
                                         (loop-fast-next-key)))
                                   (case keycode
                                     ((left)
                                      (%charterm:demo-input-cursor-left di)
                                      (loop-fast-next-key))
                                     ((right)
                                      (%charterm:demo-input-cursor-right di)
                                      (loop-fast-next-key))
                                     ((backspace)
                                      (%charterm:demo-input-backspace di)
                                      (loop-fast-next-key))
                                     ((delete)
                                      (%charterm:demo-input-delete di)
                                      (loop-fast-next-key))
                                     ((escape)
                                      (if escape?
                                          (begin
                                            (charterm-clear-screen)
                                            (charterm-display "You have escaped the charterm demo!")
                                            (charterm-newline)
                                            (done-ec))
                                          (loop-fast-next-key)))
                                     (else (loop-fast-next-key)))))
                             (begin
                               ;; (charterm-display "Timeout.")
                               (loop-maybe-check-screen-size)))))))))))))))

(provide main)
(define (main . args)
  ;; TODO: Accept TTY as an argument.
  (let ((tty     #f)
        (escape? #t))
    (command-line #:program "(charterm Demo)"
                  #:once-each
                  (("--tty" "-t") arg "The TTY to use (default: /dev/tty)." (set! tty arg))
                  #:once-any
                  (("--escape"    "-e") "Esc key quits program (default)." (set! escape? #t))
                  (("--no-escape" "-n") "Esc key does not quit program."   (set! escape? #f)))
    (charterm-demo #:tty     tty
                   #:escape? escape?)))
