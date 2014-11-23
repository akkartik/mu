#lang racket/base
;; Copyright (c) Neil Van Dyke.  See file "info.rkt".

(require (for-syntax racket/base
                     racket/syntax)
         racket/system
         (planet neil/mcfly))

(doc (section "Introduction")

     (para "The "
           "CharTerm"
           " package provides a Racket interface for character-cell video
display terminals on Unix-like systems -- such as for "
           (as-index "GNU Screen")
           " and "
           (as-index (code "tmux"))
           " sessions on "
           (index '("cloud server" "server") "cloud servers")
           ", "
           (as-index "XTerm")
           " windows on a workstation desktop, and some older hardware
terminals (even the venerable "
           (as-index "DEC VT100")
           ").  Currently, it implements a subset of features available on most
terminals.")

     (para "This package could be used to implement a status/management console
for a Racket-based server process (perhaps run in GNU Screen or "
           (code "tmux")
           " on a server machine, to be detached and reattached from SSH
sessions), a lightweight user interface for a systems tool, a command-line
REPL, a text editor, creative retro uses of old equipment, and, perhaps most
importantly, a "
           ;; (hyperlink "http://en.wikipedia.org/wiki/Rogue_%28computer_game%29"
           "Rogue-like"
           ;;)
           " application.")

     (para "The "
           "CharTerm"
           " package does not include any native code (such as from "
           (as-index (code "terminfo"))
           ", "
           (as-index (code "termcap"))
           ", "
           (as-index (code "curses"))
           ", or "
           (as-index (code "ncurses"))
           ") in the Racket process,
such as through the Racket FFI or C extensions, so there is less potential for
a problem involving native code to threaten the reliability or security of a
program.  "
           "CharTerm"
           " is implemented in pure Racket code except for executing "
           (code "/bin/stty")
           " for some purposes.  Specifically, "
           (code "/bin/stty")
           " at startup time and shutdown time, to set modes, and (for terminal
types that don't seem to support a screen size report control sequence) when
getting screen size.  Besides security and stability, lower dependence on
native code might also simplify porting to host platforms that don't have those
native code facilities."))

(doc (subsection "Demo")

     (para "For a demonstration, the following command, run from a terminal, should install the "
           "CharTerm"
           " package (if not already installed), and run the demo:")

     (commandline "racket -pm neil/charterm/demo")

     (para "This demo reports what keys you pressed, while letting you edit a
text field, and while displaying a clock.  The clock is updated roughly once
per second, and is not updated during heavy keyboard input, such as when typing
fast.  The demo responds to changing terminal sizes, such as when an XTerm is
window is resized.  It also displays the determined terminal size, and some
small tests of the "
           (racket #:width)
           " argument to "
           (racket charterm-display)
           ".  Exit the demo by pressing the "
           (bold "Esc")
           " key.")

     (para "Note: Although this demo includes an editable text field, as proof
of concept, the current version of "
           "CharTerm"
           " does not provide editable text fields as reusable functionality."))

(doc (subsection "Simple Example")

     (para "Here's your first "
           "CharTerm"
           " program:")

     (RACKETBLOCK
      (UNSYNTAX (code "#lang racket/base"))

      (require (planet neil/charterm))

      (with-charterm
       (charterm-clear-screen)
       (charterm-cursor 10 5)
       (charterm-display "Hello, ")
       (charterm-bold)
       (charterm-display "you")
       (charterm-normal)
       (charterm-display ".")
       (charterm-cursor 1 1)
       (charterm-display "Press a key...")
       (let ((key (charterm-read-key)))
         (charterm-cursor 1 1)
         (charterm-clear-line)
         (printf "You pressed: ~S\r\n" key))))

     (para "Now you're living the dream of the '70s."))

(doc (section "Terminal Diversity")

     (para "Like people, few terminals are exactly the same.")

     (para "Some key (ha) terms (ha) used by "
           "CharTerm"
           " are:")

     (itemlist (item (tech "termvar")
                     " --- a string value like from the Unix-like "
                     (code "TERM")
                     " environment variable, used to determine a default "
                     (tech "protocol")
                     " and "
                     (tech "keydec")
                     ".")

               (item (tech "protocol")
                     " --- how to control the display, query for information, etc.")

               (item (tech "keydec")
                     " --- how to decode key encodings of a particular
terminal.  A keydec is constructed from one or more keysets, can produce "
                     (tech "keycode")
                     "s or "
                     (tech "keyinfo")
                     "s.")

               (item (tech "keyset")
                     " --- a specification of encoding some of the keys in a
particular terminal, including "
                     (tech "keylabel")
                     "s and "
                     (tech "keycode")
                     "s.")

               (item (tech "keylabel")
                     " --- a string for how a key is likely labeled on a
keyboard, such as the DEC VT100 "
                     (bold "PF1")
                     " key would have a keylabel "
                     (racket "PF1")
                     " for a "
                     (tech "keycode")
                     " "
                     (racket 'f1)
                     ".")

               (item (tech "keycode")
                     " --- a value produced by a decoded key,
such as a character for normal printable keys, like "
                     (racket #\a)
                     " and "
                     (racket #\space)
                     ", a symbol for some recognized unprintable keys, like "
                     (racket 'escape)
                     " and "
                     (racket 'f1)
                     ", or possibly a number for unrecognized keys.")

               (item (tech "keyinfo")
                     " --- an object that is used like a "
                     (tech "keycode")
                     ", except
bundles together a keycode and a "
                     (tech "keylabel")
                     ", as well as alternatate keycodes and
information about how the key was decoded (e.g., from which "
                     (tech "keyset")
                     ")."))

     (para "These terms are discussed in the following subsections.")

     (para "CharTerm"
           " is developed with help of original documentation such as that
curated by Paul Williams at "
           (hyperlink "http://vt100.net/" "vt100.net")
           ", various commentary found on the Web, observed behavior with
modern software terminals like XTerm, various emulators for hardware terminals,
and sometimes original hardware terminals.  Thanks to Mark Pearrow for
contributing a TeleVideo 950, and Paul McCabe for a Wyse S50 WinTerm.")

     (para "At time of this writing, the author is looking to acquire a DEC
VT525, circa 1994, for ongoing testing.")

     (para "The author welcomes feedback on useful improvements to "
           "CharTerm"
           "'s support for terminal diversity (no pun).  If you have a terminal
that is sending an escape sequence not recognized by the demo, you can run the
demo with the "
           (Flag "n")
           " (aka "
           (DFlag "no-escape")
           ") argument to see the exact byte sequence:")

     (commandline "racket -pm- neil/charterm/demo -n")

     (para "When "
           (Flag "n")
           " is used, this will be indicated by the bottom-most scrolling line,
rather than saying ``"
           (tt "To quit, press " (bold "Esc") ".")
           "'' instead will say ``"
           (tt "There is no escape from this demo.")
           "'' You will have to kill the process through some other means."))

(doc (subsection "Protocol")

     (para "The first concept "
           "CharTerm"
           " has for distinguishing how to communicate with a terminal is what
is what is called here "
           (deftech "protocol")
           ", which concerns everything except how keyboard keys are decoded.
The following protocols are currently implemented:")

     (itemlist

      (item (deftech (code "ansi") " protocol")
            " --- Terminals approximating ["
            (tech "ANSI X3.64")
            "], which is most terminals in use today, including software ones
like XTerm.  This protocol is the emphasis of this package; the other protocols
are for unusual situations.")

      ;; (item (code "dec-vt100")
      ;;       " --- The DEC VT100 and compatibles that could be considered "
      ;;       (code "ansi")
      ;;       " except don't have insert-line and delete-line.")

      (item (deftech (code "wyse-wy50") " protocol")
            " --- Terminals compatible with the Wyse WY-50.  This support is
based on ["
            (tech "WY-50-QRG")
            "], ["
            (tech "WY-60-UG")
            "], ["
            (tech "wy60")
            "], and ["
            (tech "PowerTerm")
            "].  Note that video attributes are not supported, due to the WY-50's
model of having video attribute changes occupy character cells; you may wish
to run the Wyse terminal in an ANSI or VT100 mode.")

      (item (deftech (code "televideo-925") " protocol")
            " --- Terminals compatible with the TeleVideo 925.  This support is based on ["
            (tech "TVI-925-IUG")
            "] and behavior of ["
            (tech "PowerTerm")
            "].  Note that video attributes are not supported, due to the 925's
model of having video attribute changes occupy character cells; you may wish to
run your TeleVideo terminal in ANSI or VT100 mode, if it has one.")

      (item (deftech (code "ascii") " protocol")
            " --- Terminals that support ASCII but not much else that we know about.")))

(define-syntax (%charterm:protocol-case stx)
  (syntax-case stx (else)
    ((_ ERROR-NAME ACTUAL-PROTO (PART0 PART1 PARTn ...) ...)
     (let loop-clauses ((clause-stxes             (syntax->list #'((PART0 PART1 PARTn ...) ...)))
                        (reverse-out-clause-stxes '())
                        (else-stx                 #f)
                        (need-protos-hash         (make-immutable-hasheq (map (lambda (proto)
                                                                                (cons proto #t))
                                                                              '(ansi
                                                                                televideo-925
                                                                                wyse-wy50)))))
       (if (null? clause-stxes)
           (let ((missing-protos (hash-keys need-protos-hash)))
             (if (or else-stx (null? missing-protos))
                 (quasisyntax/loc stx
                   (let ((actual-proto ACTUAL-PROTO))
                     (case actual-proto
                       #,@(reverse reverse-out-clause-stxes)
                       #,(or else-stx
                             (syntax/loc stx
                               (else (error ERROR-NAME
                                            "unimplemented for protocol: ~S"
                                            actual-proto)))))))
                 (raise-syntax-error '%charterm:protocol-case
                                     (format "missing protocols ~S" missing-protos)
                                     stx)))
           (let* ((clause-stx   (car clause-stxes))
                  (clause-parts (syntax->list clause-stx))
                  (part0-stx    (car clause-parts))
                  (part0-e      (syntax-e part0-stx)))
             (if (eq? 'else part0-e)
                 (if else-stx
                     (raise-syntax-error '%charterm:protocol-case
                                         "else clause multiply defined"
                                         clause-stx
                                         #f
                                         (list else-stx))
                     (loop-clauses (cdr clause-stxes)
                                   reverse-out-clause-stxes
                                   clause-stx
                                   need-protos-hash))
                 (let loop-protos ((proto-stxes      (syntax->list (car (syntax->list clause-stx))))
                                   (need-protos-hash need-protos-hash))
                   (if (null? proto-stxes)
                       (loop-clauses (cdr clause-stxes)
                                     (cons clause-stx reverse-out-clause-stxes)
                                     else-stx
                                     need-protos-hash)
                       (let* ((proto-stx (car proto-stxes))
                              (proto-e   (syntax-e proto-stx)))
                         (if (symbol? proto-e)
                             (if (hash-has-key? need-protos-hash proto-e)
                                 (loop-protos (cdr proto-stxes)
                                              (hash-remove need-protos-hash proto-e))
                                 (raise-syntax-error '%charterm:protocol-case
                                                     "protocol unrecognized or multiply defined"
                                                     proto-stx))
                             (raise-syntax-error '%charterm:protocol-case
                                                 "invalid protocol symbol"
                                                 proto-stx))))))))))))

(define-syntax (%charterm:unimplemented stx)
  (syntax-case stx ()
    ((_ CT ERROR-NAME)
     (syntax/loc stx
       (error ERROR-NAME
              "unimplemented feature for protocol ~S"
              (charterm-protocol CT))))))

(doc (subsection "Key Encoding")

     (para "While most video display control, they seem to vary more by key
encoding.")

     (para "The "
           "CharTerm"
           " author was motivated to increase the sophistication of its
keyboard handling after a series of revelations on the Sunday of the long
weekend in which "
           "CharTerm"
           " was initially written.  The first was discovering that four of the
function keys that had been working fine in "
           (code "rxvt")
           " did not work in XTerm.  Dave Gilbert somewhat demystified this by
pointing out that the original VT100 had only four function keys, which set
into motion an unfortunate series of bad decisions by various developers of
terminal software to be needlessly incompatible with each other.  After
Googling, a horrifying 2005 Web post by Phil Gregory ["
           (tech "Gregory")
           "], which showed that key encoding among XTerm variants was even
worse than one could ever fear.  Even if one already knew how much subtleties
of old terminals varied (e.g., auto-newline behavior, whether an attribute
change consumed a space, etc.), this incompatibility in newer software was
surprising. Then, on a hunch, I tried the Linux Console on a Debian Squeeze
machine, which surely is ANSI, and found, however, that it generated "
           (italic "yet different")
           " byte sequences, for the first "
           (italic "five")
           " (not four) function keys.  Then I compared all to the ["
           (tech "ECMA-48")
           "] standard, which turns out to be nigh-inscrutable, so which might
help explain why everyone became so anti-social.")

     (para "CharTerm"
           " now provides the abstractions of "
           (tech "keysets")
           " and "
           (tech "keydecs")
           " to deal with this diversity in a maintainable way."))

(doc (subsubsection "Keylabel")

     (para "A "
           (deftech "keylabel")
           " is a Racket string for how a key is likely labeled on a particular terminal's keyboard.  Different keyboards may have different keylabels for the same "
           (tech "keycode")
           ".  For example, a VT100 has a "
           (bold "PF1")
           " key (keylabel "
           (racket "PF1")
           ", keycode "
           (racket 'f1)
           "), while many other keyboards would label the key "
           (bold "F1")
           " (keylabel "
           (racket "F1")
           ", keycode "
           (racket 'f1)
           ").  The keylabel currently is most useful for documenting and debugging, although it could later be used when giving instructions to the user, such as knowing whether to tell the user the "
           (bold "Return")
           " key or the "
           (bold "Enter")
           " key; the "
           (bold "Backspace")
           " or the "
           (bold "Rubout")
           " key; etc."))

(doc (subsubsection "Keycode")

     (para "A "
           (deftech "keycode")
           " is a value representing a key read from a terminal, which can be a Racket character, symbol, or number.  Keys corresponding to printable characters have keycodes as Racket characters.  Some keys corresponding to special non-printable characters can have keycodes of Racket symbols, such as "
           (racket 'return)
           ", "
           (racket 'f1)
           ", "
           (racket 'up)
           ", etc."))

;; TODO: Document here all the symbol keycodes we define.

(doc (defproc (charterm-keycode? (x any/c))
         boolean?
       "Predicate for whether or not "
       (racket x)
       " is a valid keycode."))
(provide charterm-keycode?)
(define (charterm-keycode? x)
  (if (or (symbol? x)
          (char? x)
          (exact-nonnegative-integer? x))
      #t
      #f))

(doc (subsubsection "Keyinfo")

     (para "A "
           (deftech "keyinfo")
           " represents a "
           (tech "keycode")
           " for a key, a "
           (tech "keylabel")
           ", and how it is encoded as bytes.  It is represented in Racket as
a "
           (racket charterm-keyinfo)
           " object."))

(define-struct charterm-keyinfo
  (keyset-id
   bytelang
   bytelist
   keylabel
   keycode
   all-keycodes)
  #:transparent)

(doc (defproc (charterm-keyinfo? (x any/c))
         boolean?)
     "Predicate for whether or not "
     (racket x)
     " is a "
     (racket charterm-keyinfo)
     " object.")
(provide charterm-keyinfo?)

(doc (defproc*
         (((charterm-keyinfo-keyset-id    (ki charterm-keyinfo?)) symbol?)
          ((charterm-keyinfo-bytelang     (ki charterm-keyinfo?)) string?)
          ((charterm-keyinfo-bytelist     (ki charterm-keyinfo?)) (listof byte?))
          ((charterm-keyinfo-keylabel     (ki charterm-keyinfo?)) string?)
          ((charterm-keyinfo-keycode      (ki charterm-keyinfo?)) charterm-keycode?)
          ((charterm-keyinfo-all-keycodes (ki charterm-keyinfo?)) (listof charterm-keycode?)))
       (para "Get information from a "
             (racket charterm-keyinfo)
             " object.")))
(provide charterm-keyinfo-keyset-id
         charterm-keyinfo-bytelang
         charterm-keyinfo-bytelist
         charterm-keyinfo-keylabel
         charterm-keyinfo-keycode
         charterm-keyinfo-all-keycodes)

(define %charterm:bytestr-to-byte-hash
  (make-hash
   `(("nul"      . 0)
     ("null"     . 0)
     ("lf"       . 10)
     ("linefeed" . 10)
     ("cr"       . 13)
     ("return"   . 13)
     ("ret"      . 13)
     ("esc"      . 27)
     ("^["       . 27)
     ("sp"       . 32)
     ("space"    . 32)
     ,@(for/list ((n (in-range 1 26)))
         (cons (string #\^ (integer->char (+ 96 n)))
               n))
     ,@(for/list ((n (in-range 1 26)))
         (cons (string-append "ctrl-"
                              (string (integer->char (+ 96 n))))
               n))
     ,@(for/list ((n (in-range 32 127)))
         (cons (string (integer->char n))
               n))
     ,@(for/list ((n (in-range 0 255)))
         (cons (string-append "("
                              (number->string n)
                              ")")
               n)))))

(define (%charterm:bytestr->byte bytestr)
  (hash-ref %charterm:bytestr-to-byte-hash bytestr))

(define (%charterm:bytelang->bytelist bytelang secondary?)
  (let ((bytelist (map %charterm:bytestr->byte
                       (regexp-split #rx" +" bytelang))))
    (if (and secondary? (not (= 1 (length bytelist))))
        (error '%charterm:bytelang->bytelist
               "bytelist for secondary keyset: ~S"
               bytelist)
        bytelist)))

(define (%charterm:keycode->keylabel keycode)
  (cond ((not keycode) #f)
        ((symbol? keycode) (string-titlecase (symbol->string keycode)))
        ((char?   keycode) (string keycode))
        ((number? keycode) (number->string keycode))
        (else (error '%charterm:keycode->keylabel
                     "invalid keycode: ~S"
                     keycode))))

(define (%charterm:keylang->keyinfo keyset-id keylang secondary?)
  (apply (lambda (bytelang . args)
           (let-values (((bytelist)
                         (%charterm:bytelang->bytelist bytelang secondary?))
                        ((keylabel keycode all-keycodes)
                         (let ((keylabel (car args)))
                           (if (or (string? keylabel)
                                   (not keylabel))
                               (values keylabel
                                       (cadr args)
                                       (cdr args))
                               (let ((keycode (car args)))
                                 (values (%charterm:keycode->keylabel keycode)
                                         keycode
                                         args))))))
             (make-charterm-keyinfo keyset-id
                                    bytelang
                                    bytelist
                                    keylabel
                                    keycode
                                    all-keycodes)))
         keylang))

(doc (subsubsection "Keyset")

     (para "A "
           (deftech "keyset")
           " is a specification of keys on a particular keyboard, including their "
           (tech "keylabel")
           ", encoding as bytes, and primary and alternate "
           (tech #:key "keycode" "keycodes")
           ".")

     ;; TODO: Expose ability to construct keysets, once it's finalized.
     (para "The means of constructing a keyset is currently internal to this package."))

(define-struct charterm-keyset
  (id primary-keyinfos secondary-keyinfos)
  #:transparent)

(doc (defproc (charterm-keyset? (x any/c))
         boolean?
       (para "Predicate for whether or not "
             (racket x)
             " is a keyset.")))
(provide charterm-keyset?)

(doc (defproc (charterm-keyset-id (ks charterm-keyset?))
         symbol?)
     (para "Get a symbol identifying the keyset."))
(provide charterm-keyset-id)

;; (define (%charterm:keyinfos? x)
;;   (for/and ((x (in-list x)))
;;     (charterm-keyinfo? x)))
;;
;; (define (%charterm:assert-keyinfos keyinfos)
;;   (or (%charterm:keyinfos? keyinfos)
;;       (error '%charterm:assert-keyinfos
;;              "assertion failed: ~S"
;;              keyinfos)))

(define (make-charterm-keyset-from-keylangs keyset-id
                                            keylangs
                                            (secondary-keylangs '()))
  (let ((primary-keyinfos   (map (lambda (keylang)
                                   (%charterm:keylang->keyinfo keyset-id keylang #f))
                                 keylangs))
        (secondary-keyinfos (map (lambda (keylang)
                                   (%charterm:keylang->keyinfo keyset-id keylang #t))
                                 secondary-keylangs)))
    ;; (%charterm:assert-keyinfos primary-keyinfos)
    ;; (%charterm:assert-keyinfos secondary-keyinfos)
    (charterm-keyset keyset-id
                     primary-keyinfos
                     secondary-keyinfos)))

(doc (defthing charterm-ascii-keyset charterm-keyset?
       (para "From the old ["
             (tech "ASCII")
             "] standard.  When defining a "
             (tech "keydec")
             ", this is good to have as a final keyset, after the others.")))
(define charterm-ascii-keyset
  (let ((keylangs
         `(("(0)"   "NUL"       nul             null)
           ("(1)"   "Ctrl-A"    ctrl-a          start-of-heading soh)
           ("(2)"   "Ctrl-B"    ctrl-b          start-of-text stx)
           ("(3)"   "Ctrl-C"    ctrl-c          end-of-text etx)
           ("(4)"   "Ctrl-D"    ctrl-d          end-of-transmission eot)
           ("(5)"   "Ctrl-E"    ctrl-e          enquiry enq)
           ("(6)"   "Ctrl-F"    ctrl-f          acknowledge ack)
           ("(7)"   "Ctrl-G"    ctrl-g          bell bel)
           ("(8)"   "Backspace" backspace       ctrl-h bs)
           ("(9)"   "Tab"       tab             ctrl-i horizontal-tab ht)
           ("(10)"  "Linefeed"  linefeed        ctrl-j line-feed lf)
           ("(11)"  "Ctrl-K"    ctrl-k          vertical-tab vt)
           ("(12)"  "Ctrl-L"    ctrl-l          formfeed form-feed ff)
           ("(13)"  "Return"    return          ctrl-m carriage-return cr)
           ("(14)"  "Ctrl-N"    ctrl-n          shift-out so)
           ("(15)"  "Ctrl-O"    ctrl-o          shift-in si)
           ("(16)"  "Ctrl-P"    ctrl-p          data-link-escape dle)
           ("(17)"  "Ctrl-Q"    ctrl-q          device-control-1 dc1)
           ("(18)"  "Ctrl-R"    ctrl-r          device-control-2 dc2)
           ("(19)"  "Ctrl-S"    ctrl-s          device-control-3 dc3)
           ("(20)"  "Ctrl-T"    ctrl-t          device-control-4 dc4)
           ("(21)"  "Ctrl-U"    ctrl-u          negative-acknowledgement nak)
           ("(22)"  "Ctrl-V"    ctrl-v          synchronous-idle syn)
           ("(23)"  "Ctrl-W"    ctrl-w          end-of-transmission-block etb)
           ("(24)"  "Ctrl-X"    ctrl-x          cancel can)
           ("(25)"  "Ctrl-Y"    ctrl-y          end-of-medium em)
           ("(26)"  "Ctrl-Z"    ctrl-z          substitute sub)
           ("(27)"  "Esc"       escape          esc)
           ("(28)"  "FS"        file-separator  fs)
           ("(29)"  "GS"        group-separator gs)
           ("(30)"  "RS"        record-separtor rs)
           ("(31)"  "US"        unit-separator  us)
           ("(32)"  "Space"     #\space         space sp)
           ("(127)" "Delete"    delete          del)
           ,@(for/list ((n (in-range 32 127)))
               (let ((c (integer->char n)))
                 (list (string-append "(" (number->string n) ")")
                       (string c)
                       c))))))
    (make-charterm-keyset-from-keylangs
     'ascii
     keylangs
     keylangs)))

(doc (defthing charterm-dec-vt100-keyset charterm-keyset?
       (para "From the DEC VT100.  This currently defines the four function
keys (labeled on the keyboard, "
             (bold "PF1")
             " through "
             (bold "PF4")
             ") as "
             (racket 'f1)
             " through "
             (racket 'f4)
             ", and the arrow keys.  ["
             (tech "VT100-UG")
             "] and ["
             (tech "PowerTerm")
             "] were used as references.")))
(provide charterm-dec-vt100-keyset)
(define  charterm-dec-vt100-keyset
  (make-charterm-keyset-from-keylangs
   'dec-vt100
   '(("esc O P" "PF1" f1)
     ("esc O Q" "PF2" f2)
     ("esc O R" "PF3" f3)
     ("esc O S" "PF4" f4)

     ("esc [ A" up)
     ("esc [ B" down)
     ("esc [ C" right)
     ("esc [ D" left)
     
     ;; Note: PowerTerm does not map PC key F1 like VT100, etc.  It maps all
     ;; the PC F keys to other sequences that are like the VT220.
     )))

(doc (defthing charterm-dec-vt220-keyset charterm-keyset?
       (para "From the DEC VT220.  This currently defines function keys "
             (bold "F1")
             " through "
             (bold "F20")
             ".")))
(provide charterm-dec-vt220-keyset)
(define  charterm-dec-vt220-keyset
  (make-charterm-keyset-from-keylangs
   'dec-vt220
   '(
     ("esc [ 1 1 ~" f1)
     ("esc [ 1 2 ~" f2)
     ("esc [ 1 3 ~" f3)
     ("esc [ 1 4 ~" f4)
     ("esc [ 1 5 ~" f5)
     ("esc [ 1 7 ~" f6)
     ("esc [ 1 8 ~" f7)
     ("esc [ 1 9 ~" f8)
     ("esc [ 2 0 ~" f9)
     ("esc [ 2 1 ~" f10)
     ("esc [ 2 3 ~" f11)
     ("esc [ 2 4 ~" f12)
     ("esc [ 2 5 ~" f13)
     ("esc [ 2 6 ~" f14)
     ("esc [ 2 8 ~" f15)
     ("esc [ 2 9 ~" f16)
     ("esc [ 3 1 ~" f17)
     ("esc [ 3 2 ~" f18)
     ("esc [ 3 3 ~" f19)
     ("esc [ 3 4 ~" f20)

     ;; TODO: Make the keylang expand to both "esc [" and "(155)" CSI or
     ;; whatever.
     
     ("(155) 1 1 ~" f1)
     ("(155) 1 2 ~" f2)
     ("(155) 1 3 ~" f3)
     ("(155) 1 4 ~" f4)
     ("(155) 1 5 ~" f5)
     ("(155) 1 7 ~" f6)
     ("(155) 1 8 ~" f7)
     ("(155) 1 9 ~" f8)
     ("(155) 2 0 ~" f9)
     ("(155) 2 1 ~" f10)
     ("(155) 2 3 ~" f11)
     ("(155) 2 4 ~" f12)
     ("(155) 2 5 ~" f13)
     ("(155) 2 6 ~" f14)
     ("(155) 2 8 ~" f15)
     ("(155) 2 9 ~" f16)
     ("(155) 3 1 ~" f17)
     ("(155) 3 2 ~" f18)
     ("(155) 3 3 ~" f19)
     ("(155) 3 4 ~" f20)

     )))

(doc (defthing charterm-screen-keyset charterm-keyset?
       (para "From the "
             (hyperlink "http://en.wikipedia.org/wiki/GNU_Screen"
                        "GNU Screen")
             " terminal multiplexer, according to ["
             (tech "Gregory")
             "].  Also used by "
             (hyperlink "http://en.wikipedia.org/wiki/Tmux"
                        (code "tmux"))
             ".")))
(provide charterm-screen-keyset)
(define  charterm-screen-keyset
  (make-charterm-keyset-from-keylangs
   'screen
   '(("esc O P"     f1)
     ("esc O Q"     f2)
     ("esc O R"     f3)
     ("esc O S"     f4)
     ("esc [ 1 5 ~" f5)
     ("esc [ 1 7 ~" f6)
     ("esc [ 1 8 ~" f7)
     ("esc [ 1 9 ~" f8)
     ("esc [ 2 0 ~" f9)
     ("esc [ 2 1 ~" f10)
     ("esc [ 2 3 ~" f11)
     ("esc [ 2 4 ~" f12)

     ("esc [ 3 ~" "Delete" delete del)
     ("esc [ 7 ~" "Home" home)
     ("esc [ 8 ~" "End"  end)
     
     ("(127)" "Backspace" backspace)
     )))

(doc (defthing charterm-linux-keyset charterm-keyset?
       (para "From the Linux console.  Currently defines function keys "
             (bold "F1")
             " through "
             (bold "F5")
             " only, since the rest will be inherited from other keysets.")))
(provide charterm-linux-keyset)
(define charterm-linux-keyset
  (make-charterm-keyset-from-keylangs
   'linux
   '(("esc [ [ A" f1)
     ("esc [ [ B" f2)
     ("esc [ [ C" f3)
     ("esc [ [ D" f4)
     ("esc [ [ E" f5))))

(doc (defthing charterm-xterm-x11r6-keyset charterm-keyset?
       (para "From the XTerm in X11R6, according to ["
             (tech "Gregory")
             "].")))
(provide charterm-xterm-x11r6-keyset)
(define  charterm-xterm-x11r6-keyset
  (make-charterm-keyset-from-keylangs
   'xterm-x11r6
   '(("esc [ 1 1 ~"     f1)
     ("esc [ 1 2 ~"     f2)
     ("esc [ 1 3 ~"     f3)
     ("esc [ 1 4 ~"     f4)
     ("esc [ 1 5 ~"     f5)
     ("esc [ 1 7 ~"     f6)
     ("esc [ 1 8 ~"     f7)
     ("esc [ 1 9 ~"     f8)
     ("esc [ 2 0 ~"     f9)
     ("esc [ 2 1 ~"     f10)
     ("esc [ 2 3 ~"     f11)
     ("esc [ 2 4 ~"     f12)
     ("esc [ 1 1 ; 2 ~" f13)
     ("esc [ 1 2 ; 2 ~" f14)
     ("esc [ 1 3 ; 2 ~" f15)
     ("esc [ 1 4 ; 2 ~" f16)
     ("esc [ 1 5 ; 2 ~" f17)
     ("esc [ 1 7 ; 2 ~" f18)
     ("esc [ 1 8 ; 2 ~" f19)
     ("esc [ 1 9 ; 2 ~" f20)
     ("esc [ 2 0 ; 2 ~" f21)
     ("esc [ 2 1 ; 2 ~" f22)
     ("esc [ 2 3 ; 2 ~" f23)
     ("esc [ 2 4 ; 2 ~" f24)
     ("esc [ 1 1 ; 5 ~" f25)
     ("esc [ 1 2 ; 5 ~" f26)
     ("esc [ 1 3 ; 5 ~" f27)
     ("esc [ 1 4 ; 5 ~" f28)
     ("esc [ 1 5 ; 5 ~" f29)
     ("esc [ 1 7 ; 5 ~" f30)
     ("esc [ 1 8 ; 5 ~" f31)
     ("esc [ 1 9 ; 5 ~" f32)
     ("esc [ 2 0 ; 5 ~" f33)
     ("esc [ 2 1 ; 5 ~" f34)
     ("esc [ 2 3 ; 5 ~" f35)
     ("esc [ 2 4 ; 5 ~" f36)
     ("esc [ 1 1 ; 6 ~" f37)
     ("esc [ 1 2 ; 6 ~" f38)
     ("esc [ 1 3 ; 6 ~" f39)
     ("esc [ 1 4 ; 6 ~" f40)
     ("esc [ 1 5 ; 6 ~" f41)
     ("esc [ 1 7 ; 6 ~" f42)
     ("esc [ 1 8 ; 6 ~" f43)
     ("esc [ 1 9 ; 6 ~" f44)
     ("esc [ 2 0 ; 6 ~" f45)
     ("esc [ 2 1 ; 6 ~" f46)
     ("esc [ 2 3 ; 6 ~" f47)
     ("esc [ 2 4 ; 6 ~" f48))))

(doc (defthing charterm-xterm-xfree86-keyset charterm-keyset?
       (para "From the XFree86 XTerm, according to ["
             (tech "Gregory")
             "].")))
(provide charterm-xterm-xfree86-keyset)
(define  charterm-xterm-xfree86-keyset
  (make-charterm-keyset-from-keylangs
   'xterm-xfree86
   '(("esc O P"         f1)
     ("esc O Q"         f2)
     ("esc O R"         f3)
     ("esc O S"         f4)
     ("esc [ 1 5 ~"     f5)
     ("esc [ 1 7 ~"     f6)
     ("esc [ 1 8 ~"     f7)
     ("esc [ 1 9 ~"     f8)
     ("esc [ 2 0 ~"     f9)
     ("esc [ 2 1 ~"     f10)
     ("esc [ 2 3 ~"     f11)
     ("esc [ 2 4 ~"     f12)
     ("esc O 2 P"       f13)
     ("esc O 2 Q"       f14)
     ("esc O 2 R"       f15)
     ("esc O 2 S"       f16)
     ("esc [ 1 5 ; 2 ~" f17)
     ("esc [ 1 7 ; 2 ~" f18)
     ("esc [ 1 8 ; 2 ~" f19)
     ("esc [ 1 9 ; 2 ~" f20)
     ("esc [ 2 0 ; 2 ~" f21)
     ("esc [ 2 1 ; 2 ~" f22)
     ("esc [ 2 3 ; 2 ~" f23)
     ("esc [ 2 4 ; 2 ~" f24)
     ("esc O 5 P"       f25)
     ("esc O 5 Q"       f26)
     ("esc O 5 R"       f27)
     ("esc O 5 S"       f28)
     ("esc [ 1 5 ; 5 ~" f29)
     ("esc [ 1 7 ; 5 ~" f30)
     ("esc [ 1 8 ; 5 ~" f31)
     ("esc [ 1 9 ; 5 ~" f32)
     ("esc [ 2 0 ; 5 ~" f33)
     ("esc [ 2 1 ; 5 ~" f34)
     ("esc [ 2 3 ; 5 ~" f35)
     ("esc [ 2 4 ; 5 ~" f36)
     ("esc O 6 P"       f37)
     ("esc O 6 Q"       f38)
     ("esc O 6 R"       f39)
     ("esc O 6 S"       f40)
     ("esc [ 1 5 ; 6 ~" f41)
     ("esc [ 1 7 ; 6 ~" f42)
     ("esc [ 1 8 ; 6 ~" f43)
     ("esc [ 1 9 ; 6 ~" f44)
     ("esc [ 2 0 ; 6 ~" f45)
     ("esc [ 2 1 ; 6 ~" f46)
     ("esc [ 2 3 ; 6 ~" f47)
     ("esc [ 2 4 ; 6 ~" f48))))

(doc (defthing charterm-xterm-new-keyset charterm-keyset?
       (para "From the current "
             (code "xterm-new")
             ", often called simply "
             (code "xterm")
             ", as developed by Thomas E. Dickey, and documented in ["
             (tech "XTerm-ctlseqs")
             "].  Several also came from decompiling a "
             (code "terminfo")
             " entry.  Thanks to Dickey for his emailed help.")))
(provide charterm-xterm-new-keyset)
(define  charterm-xterm-new-keyset
  (make-charterm-keyset-from-keylangs
   'xterm-new
   '(

     ;; CSI = "esc ["
     ;; SS3 = "esc O"

     ("esc [ A" up)
     ("esc [ B" down)
     ("esc [ C" right)
     ("esc [ D" left)
     ("esc [ H" home)
     ("esc [ F" end)

     ;; The following came from decompiling an xterm terminfo
     ("esc O A" up)
     ("esc O B" down)
     ("esc O C" right)
     ("esc O D" left)
     ("esc O H" home)
     ("esc O F" end)

     ("esc O P" f1)
     ("esc O Q" f2)
     ("esc O R" f3)
     ("esc O S" f4)
     ("esc [ 1 5 ~" f5)
     ("esc [ 1 7 ~" f6)
     ("esc [ 1 8 ~" f7)
     ("esc [ 1 9 ~" f8)
     ("esc [ 2 0 ~" f9)
     ("esc [ 2 1 ~" f10)
     ("esc [ 2 3 ~" f11)
     ("esc [ 2 4 ~" f12)

     ("esc O I" tab kp-tab)
     ("esc O M" "Enter" return enter kp-return kp-enter)
     ("esc O P" "PF1" f1 kp-f1)
     ("esc O Q" "PF2" f2 kp-f2)
     ("esc O R" "PF3" f3 kp-f3)
     ("esc O S" "PF4" f4 kp-f4)
     ("esc [ 3 ~" "Delete" delete del kp-delete)
     ("esc [ 2 ~" "Insert" insert ins kp-insert)
     ("esc O F"   "End" end kp-end)
     ("esc [ B" "Down" down kp-down)
     ("esc [ 6 ~" "PgDn" pgdn kp-pgdn)
     ("esc [ D" "Left" left kp-left)
     ("esc [ E" "Begin" begin kp-begin)
     ("esc [ C" "Right" right kp-right)
     ("esc O H" "Home" home kp-home)
     ("esc [ A" "Up" up kp-up)
     ("esc [ 5 ~" "PgUp" pgup kp-pgup)

     ("esc [ 1 1 ~" "F1" f1)
     ("esc [ 1 2 ~" "F2" f2)
     ("esc [ 1 3 ~" "F3" f3)
     ("esc [ 1 4 ~" "F4" f4)

     ;; TODO: continue working on this from dickey's xterm control sequences doc

     )))

(doc (defthing charterm-rxvt-keyset charterm-keyset?
       (para "From the "
             (hyperlink "http://en.wikipedia.org/wiki/Rxvt"
                        (code "rxvt"))
             " terminal emulator.  These come from ["
             (tech "Gregory")
             "], and
currently define function keys "
             (racket 'f1)
             " through "
             (racket 'f44)
             ".")))
(define charterm-rxvt-keyset
  (make-charterm-keyset-from-keylangs
   'rxvt
   '(("esc [ 1 1 ~" f1)
     ("esc [ 1 2 ~" f2)
     ("esc [ 1 3 ~" f3)
     ("esc [ 1 4 ~" f4)
     ("esc [ 1 5 ~" f5)
     ("esc [ 1 7 ~" f6)
     ("esc [ 1 8 ~" f7)
     ("esc [ 1 9 ~" f8)
     ("esc [ 2 0 ~" f9)
     ("esc [ 2 1 ~" f10)
     ("esc [ 2 3 ~" shift-f1  f11) ;; TODO: These shift- and ctrl- are actually from termvar xterm in an rxvt
     ("esc [ 2 4 ~" shift-f2  f12)
     ("esc [ 2 5 ~" shift-f3  f13)
     ("esc [ 2 6 ~" shift-f4  f14)
     ("esc [ 2 8 ~" shift-f5  f15)
     ("esc [ 2 9 ~" shift-f6  f16)
     ("esc [ 3 1 ~" shift-f7  f17)
     ("esc [ 3 2 ~" shift-f8  f18)
     ("esc [ 3 3 ~" shift-f9  f19)
     ("esc [ 3 4 ~" shift-f10 f20)
     ("esc [ 2 3 $" shift-f11 f21)
     ("esc [ 2 4 $" shift-f12 f22)
     ("esc [ 1 1 ^" ctrl-f1   f23)
     ("esc [ 1 2 ^" ctrl-f2   f24)
     ("esc [ 1 3 ^" ctrl-f3   f25)
     ("esc [ 1 4 ^" ctrl-f4   f26)
     ("esc [ 1 5 ^" ctrl-f5   f27)
     ("esc [ 1 7 ^" ctrl-f6   f28)
     ("esc [ 1 8 ^" ctrl-f7   f29)
     ("esc [ 1 9 ^" ctrl-f8   f30)
     ("esc [ 2 0 ^" ctrl-f9   f31)
     ("esc [ 2 1 ^" ctrl-f10  f32)
     ("esc [ 2 3 ^" ctrl-f11  f33)
     ("esc [ 2 4 ^" ctrl-f12  f34)
     ("esc [ 2 5 ^" f35)
     ("esc [ 2 6 ^" f36)
     ("esc [ 2 8 ^" f37)
     ("esc [ 2 9 ^" f38)
     ("esc [ 3 1 ^" f39)
     ("esc [ 3 2 ^" f40)
     ("esc [ 3 3 ^" f41)
     ("esc [ 3 4 ^" f42)
     ("esc [ 2 3 @" f43)
     ("esc [ 2 4 @" f44)
     ("(127)" "Backspace" backspace) ; Override one from "ascii" keyset.
     ;; TODO: actually, these arrow keys were observed in rxvt with termvar xterm.  which keyset should they be in?
     ("esc [ A"     "Up" up)
     ("esc [ B"     "Down" down)
     ("esc [ C"     "Right" right)
     ("esc [ D"     "Left" left)
     ("esc [ 5 ~"   "PgUp" pgup page-up)
     ("esc [ 6 ~"   "PgDn" pgdn page-down)
     ("esc [ 7 ~"   "Home" home)
     ("esc [ 8 ~"   "End"  end)
     ("esc [ 3 ~"   "Delete" delete del)
     ("esc [ 2 ~"   "Insert" insert ins)
     )))

(doc (defthing charterm-wyse-wy50-keyset charterm-keyset?
       (para "From the Wyse WY-50, based on ["
             (tech "WY-50-QRG")
             "] and looking at photos of WY-50 keyboard, and tested in ["
             (tech "wy60")
             "] and ["
             (tech "PowerTerm")
             "].  The shifted function keys are provided as both "
             (racket 'shift-f1)
             " through "
             (racket 'shift-16)
             ", and "
             (racket 'f17)
             " through "
             (racket 'f31)
             ".")))
(provide charterm-wyse-wy50-keyset)
(define  charterm-wyse-wy50-keyset
  (make-charterm-keyset-from-keylangs
   'wyse-wy50
   '(("^a @ cr"  f1)
     ("^a A cr"  f2)
     ("^a B cr"  f3)
     ("^a C cr"  f4)
     ("^a D cr"  f5)
     ("^a E cr"  f6)
     ("^a F cr"  f7)
     ("^a G cr"  f8)
     ("^a H cr"  f9)
     ("^a I cr"  f10)
     ("^a J cr"  f11)
     ("^a K cr"  f12)
     ("^a L cr"  f13)
     ("^a M cr"  f14)
     ("^a N cr"  f15)
     ("^a O cr"  f16)
     ("^a ` cr"  "Shift-F1" shift-f1 f17)
     ("^a a cr"  "Shift-F2" shift-f2 f18)
     ("^a b cr"  "Shift-F3" shift-f3 f19)
     ("^a c cr"  "Shift-F4" shift-f4 f20)
     ("^a d cr"  "Shift-F5" shift-f5 f21)
     ("^a e cr"  "Shift-F6" shift-f6 f22)
     ("^a f cr"  "Shift-F7" shift-f7 f23)
     ("^a g cr"  "Shift-F8" shift-f8 f24)
     ("^a h cr"  "Shift-F9" shift-f9 f25)
     ("^a i cr"  "Shift-F10" shift-f10 f26)
     ("^a j cr"  "Shift-F11" shift-f11 f27)
     ("^a k cr"  "Shift-F12" shift-f12 f28)
     ("^a l cr"  "Shift-F13" shift-f13 f29)
     ("^a m cr"  "Shift-F14" shift-f14 f30)
     ("^a n cr"  "Shift-F15" shift-f15 f31)
     ("^a o cr"  "Shift-F16" shift-f16 f32)
     ("ctrl-h"   "Left" left)
     ("linefeed" "Down" down)
     ("(11)"     "Up" up)
     ("(12)"     "Right" right)
     ("esc W"    "DEL Char" delete)
     ("esc Q"    "INS Char" insert-char)
     ("esc q"    "Ins" insert ins)
     ("esc T"    "CLR Line" clear-line)
     ("esc r"    "Repl" repl)
     ("esc R"    "DEL Line" delete-line)
     ("esc J"    "PAGE Prev" pgup page-up)
     ("esc K"    "PAGE Next" pgdn page-down)
     ("esc P"    "Print" print)
     ("esc Y"    "CLR Screen" clear-screen)
     ("(30)"     "Home" home record-separator rs)
     ("(13)"     "Return" return)
     ("(127)"    "Shift-Backspace" backspace shift-backspace)
     )))

(doc (defthing charterm-televideo-925-keyset charterm-keyset?
       (para "From the TeleVideo 925, based on ["
             (tech "TVI-925-IUG")
             "], ["
             (tech "PowerTerm")
             "], and from looking at a TeleVideo 950 keyboard.")))
(provide charterm-televideo-925-keyset charterm-keyset?)
(define  charterm-televideo-925-keyset
  (make-charterm-keyset-from-keylangs
   'televideo-925
   '(("ctrl-a @ cr" f1)
     ("ctrl-a A cr" f2)
     ("ctrl-a B cr" f3)
     ("ctrl-a C cr" f4)
     ("ctrl-a D cr" f5)
     ("ctrl-a E cr" f6)
     ("ctrl-a F cr" f7)
     ("ctrl-a G cr" f8)
     ("ctrl-a H cr" f9)
     ("ctrl-a I cr" f10)
     ("ctrl-a J cr" f11)

     ("ctrl-a \\ cr" "SHIFT-F1" shift-f1)
     ("ctrl-a a cr" "SHIFT-F2" shift-f2)
     ("ctrl-a b cr" "SHIFT-F3" shift-f3)
     ("ctrl-a c cr" "SHIFT-F4" shift-f4)
     ("ctrl-a d cr" "SHIFT-F5" shift-f5)
     ("ctrl-a e cr" "SHIFT-F6" shift-f6)
     ("ctrl-a f cr" "SHIFT-F7" shift-f7)
     ("ctrl-a g cr" "SHIFT-F8" shift-f8)
     ("ctrl-a h cr" "SHIFT-F9" shift-f9)
     ("ctrl-a i cr" "SHIFT-F10" shift-f10)
     ("ctrl-a j cr" "SHIFT-F11" shift-f11)

     ("ctrl-k" "Up" up ctrl-k)
     ("ctrl-v" "Down" down ctrl-v)
     ("ctrl-h" "Left" left ctrl-h)
     ("ctrl-l" "Right" right ctrl-l)

     ("esc W" "CHAR DELETE" delete del char-delete)

     ("esc Q" "CHAR INSERT" insert ins char-insert)

     ("esc j" "Reverse Linefeed" reverse-linefeed reverse-lf reverse-line-feed)

     ("esc i" "BACK TAB" backtab back-tab)
     ("ctrl-m" "RETURN" return ctrl-m)
     ("ctrl-j" "LINEFEED" linefeed lf ctrl-j)
     ("(127)" "DEL" delete del)
     ;; ("esc Q" "CHAR INSERT" char-insert char-ins)

     )))

(doc (subsubsection "Keydec")

     (para "A "
           (deftech "keydec")
           " object is a key decoder for a specific variety of terminal, such
as for a specific "
           (tech "termvar")
           ".  A keydec is used to turn received key encodings from a terminal into "
           (tech "keycode")
           " or "
           (tech "keyinfo")
           " values.  A keydec is constructed from a prioritized list of "
           (tech "keyset")
           " objects, with earlier-listed keysets taking priority of
later-listed keysets when there is conflict between them as to how to decode a
particular byte sequence."))

(define (%charterm:make-keytree (alist '()))
  (make-immutable-hasheqv alist))

(define (%charterm:keytree-add-keyinfo-if-can keytree keyinfo)
  (let ((bytelist (charterm-keyinfo-bytelist keyinfo)))
    (let loop-bytelist ((this-byte  (car bytelist))
                        (rest-bytes (cdr bytelist))
                        (node       keytree))
      (cond ((hash? node)
             (cond ((hash-ref node this-byte #f)
                    => (lambda (existing-sub-node)
                         ;; Node has a match for this byte, so do we have another
                         ;; byte and can follow it?
                         (if (null? rest-bytes)
                             ;; Node has a match for this byte, but we have no
                             ;; more bytes, so can't add.
                             node
                             ;; Node has a match for this byte, and we have more
                             ;; bytes, so follow it.
                             (hash-set node
                                       this-byte
                                       (loop-bytelist (car rest-bytes)
                                                      (cdr rest-bytes)
                                                      existing-sub-node)))))
                   (else
                    ;; Node has no match for this byte, so add new path.
                    (hash-set node
                              this-byte
                              (let loop ((rest-bytes rest-bytes))
                                (if (null? rest-bytes)
                                    keyinfo
                                    (%charterm:make-keytree
                                     (cons (cons (car rest-bytes)
                                                 (loop (cdr rest-bytes)))
                                           '()))))))))

            ((charterm-keyinfo? node)
             ;; Node is already a keyinfo, so can't add.
             node)
            (else (error
                   '%charterm:keytree-add-keyinfo-if-can
                   "invalid node ~S with this-byte ~S, rest-bytes ~S, keyinfo ~S"
                   node
                   this-byte
                   rest-bytes
                   keyinfo))))))

(define (%charterm:keytree-add-any-keyinfos-can keytree keyinfos)
  (let loop ((keyinfos keyinfos)
             (keytree  keytree))
    (if (null? keyinfos)
        keytree
        (loop (cdr keyinfos)
              (%charterm:keytree-add-keyinfo-if-can keytree
                                                    (car keyinfos))))))

(define (%charterm:make-keytree-from-keyinfoses keyinfoses)
  (let loop ((keyinfoses keyinfoses)
             (keytree (%charterm:make-keytree)))
    (if (null? keyinfoses)
        keytree
        (let ((keyinfos (car keyinfoses)))
          ;; (and (not (null? keyinfos))
          ;;      (not (charterm-keyinfo? (car keyinfos)))
          ;;      (error '%charterm:make-keytree-from-keyinfoses
          ;;             "bad keyinfos: ~S"
          ;;             keyinfos))
          (loop (cdr keyinfoses)
                (%charterm:keytree-add-any-keyinfos-can keytree
                                                        keyinfos))))))

(doc (defproc (charterm-keydec-id (kd charterm-keydec?))
         symbol?
       (para "Gets the ID symbol of the "
             (tech "keydec")
             " being used.")))
(provide charterm-keydec-id)

(struct charterm-keydec
  (id
   primary-keytree
   secondary-keytree)
  #:transparent)

(define (charterm-make-keydec keydec-id . keysets)
  (charterm-keydec keydec-id
                   (%charterm:make-keytree-from-keyinfoses
                    (map charterm-keyset-primary-keyinfos keysets))
                   (%charterm:make-keytree-from-keyinfoses
                    (map charterm-keyset-secondary-keyinfos keysets))))

(doc (subsubsub*section "ANSI Keydecs"))

(doc (defthing charterm-vt100-keydec charterm-keydec?
       (para (tech "Keydec")
             " for "
             (tech "termvar")
             " "
             (racket "vt100")
             ".")))
(provide charterm-vt100-keydec)
(define  charterm-vt100-keydec
  (charterm-make-keydec 'vt100
                        charterm-dec-vt100-keyset
                        charterm-dec-vt220-keyset
                        charterm-xterm-new-keyset
                        charterm-linux-keyset
                        charterm-rxvt-keyset
                        charterm-xterm-xfree86-keyset
                        charterm-xterm-x11r6-keyset
                        charterm-ascii-keyset))

(doc (defthing charterm-vt220-keydec charterm-keydec?
       (para (tech "Keydec")
             " for "
             (tech "termvar")
             " "
             (racket "vt220")
             ".")))
(provide charterm-vt220-keydec)
(define  charterm-vt220-keydec
  (charterm-make-keydec 'vt220
                        charterm-dec-vt220-keyset
                        charterm-dec-vt100-keyset
                        charterm-ascii-keyset))

(doc (defthing charterm-screen-keydec charterm-keydec?
       (para (tech "Keydec")
             " for "
             (tech "termvar")
             " "
             (racket "screen")
             ".")))
(provide charterm-screen-keydec)
(define  charterm-screen-keydec
  (charterm-make-keydec 'screen
                        charterm-screen-keyset
                        charterm-linux-keyset
                        charterm-dec-vt220-keyset
                        charterm-dec-vt100-keyset
                        charterm-xterm-new-keyset
                        charterm-xterm-xfree86-keyset
                        charterm-xterm-x11r6-keyset
                        charterm-ascii-keyset))

(doc (defthing charterm-linux-keydec charterm-keydec?
       (para (tech "Keydec")
             " for "
             (tech "termvar")
             " "
             (racket "linux")
             ".")))
(provide charterm-linux-keydec)
(define  charterm-linux-keydec
  (charterm-make-keydec 'linux
                        charterm-linux-keyset
                        charterm-dec-vt220-keyset
                        charterm-dec-vt100-keyset
                        charterm-xterm-new-keyset
                        charterm-xterm-xfree86-keyset
                        charterm-xterm-x11r6-keyset
                        charterm-screen-keyset
                        charterm-ascii-keyset))

(doc (defthing charterm-xterm-new-keydec charterm-keydec?
       (para (tech "Keydec")
             " for "
             (tech "termvar")
             " "
             (racket "xterm-new")
             ".")))
(provide charterm-xterm-new-keydec)
(define  charterm-xterm-new-keydec
  (charterm-make-keydec 'xterm-new
                        charterm-xterm-new-keyset
                        charterm-xterm-xfree86-keyset
                        charterm-xterm-x11r6-keyset
                        charterm-rxvt-keyset
                        charterm-dec-vt220-keyset
                        charterm-dec-vt100-keyset
                        charterm-linux-keyset
                        charterm-ascii-keyset))

(doc (defthing charterm-xterm-keydec charterm-keydec?
       (para (tech "Keydec")
             " for "
             (tech "termvar")
             " "
             (racket "xterm")
             ".  Currently same as the keydec for "
             (code "xterm")
             ", except for a different ID.")))
(provide charterm-xterm-keydec)
(define  charterm-xterm-keydec
  (charterm-make-keydec 'xterm
                        charterm-xterm-new-keyset
                        charterm-xterm-xfree86-keyset
                        charterm-xterm-x11r6-keyset
                        charterm-rxvt-keyset
                        charterm-dec-vt220-keyset
                        charterm-dec-vt100-keyset
                        charterm-linux-keyset
                        charterm-ascii-keyset))

(doc (defthing charterm-rxvt-keydec charterm-keydec?
       (para (tech "Keydec")
             " for "
             (tech "termvar")
             " "
             (racket "rxvt")
             ".")))
(provide charterm-rxvt-keydec)
(define  charterm-rxvt-keydec
  (charterm-make-keydec 'rxvt
                        charterm-rxvt-keyset
                        charterm-xterm-new-keyset
                        charterm-xterm-xfree86-keyset
                        charterm-xterm-x11r6-keyset
                        charterm-dec-vt220-keyset
                        charterm-dec-vt100-keyset
                        charterm-linux-keyset
                        charterm-ascii-keyset))

(doc (subsubsub*section "Wyse Keydecs"))

(doc (defthing charterm-wy50-keydec charterm-keydec?
       (para (tech "Keydec")
             " for "
             (tech "termvar")
             " "
             (racket "wy50")
             ".")))
(provide charterm-wy50-keydec)
(define  charterm-wy50-keydec
  (charterm-make-keydec 'wy50
                        charterm-wyse-wy50-keyset
                        charterm-ascii-keyset))

(doc (subsubsub*section "TeleVideo Keydecs"))

(doc (defthing charterm-tvi925-keydec charterm-keydec?
       (para (tech "Keydec")
             " for "
             (tech "termvar")
             " "
             (racket "tvi925")
             ".")))
(provide charterm-tvi925-keydec)
(define  charterm-tvi925-keydec
  (charterm-make-keydec 'tvi925
                        charterm-televideo-925-keyset
                        charterm-ascii-keyset))

(doc (subsubsub*section "ASCII Keydecs"))

(doc (defthing charterm-ascii-keydec charterm-keydec?
       (para (tech "Keydec")
             " for "
             (tech "termvar")
             " "
             (racket "ascii")
             ".")))
(provide charterm-ascii-keydec)
(define  charterm-ascii-keydec
  (charterm-make-keydec 'ascii
                        charterm-ascii-keyset))

(doc (subsubsub*section "Default Keydecs"))

(doc (defthing charterm-ansi-keydec charterm-keydec?
       (para (tech "Keydec")
             " for any presumed ANSI-ish terminal, combining many ANSI-ish "
             (tech "keysets")
             ".")))
(define charterm-ansi-keydec
  (charterm-make-keydec 'ansi
                        charterm-dec-vt220-keyset
                        charterm-dec-vt100-keyset
                        charterm-xterm-new-keyset
                        charterm-linux-keyset
                        charterm-rxvt-keyset
                        charterm-xterm-xfree86-keyset
                        charterm-xterm-x11r6-keyset
                        charterm-ascii-keyset))

(doc (defthing charterm-insane-keydec charterm-keydec?
       (para (tech "Keydec")
             " for the uniquely desperate situation of wanting to possibly have
extensive key decoding for a terminal that might not even be ansi, but be
Wyse, TeleVideo, or some other ASCII.")))
(provide charterm-insane-keydec)
(define  charterm-insane-keydec
  (charterm-make-keydec 'insane
                        charterm-xterm-new-keyset
                        charterm-linux-keyset
                        charterm-dec-vt220-keyset
                        charterm-dec-vt100-keyset
                        charterm-linux-keyset
                        charterm-xterm-xfree86-keyset
                        charterm-xterm-x11r6-keyset
                        charterm-wyse-wy50-keyset
                        charterm-televideo-925-keyset
                        charterm-ascii-keyset))

(doc (subsection "Termvar")

     (para "A "
           (deftech "termvar")
           " is what the "
           (code "charterm")
           " package calls the value of the Unix-like "
           (code "TERM")
           " environment variable.  Each "
           (tech "termvar")
           " has a default "
           (tech "protocol")
           " and "
           (tech "keydec")
           ".  Note, however, that "
           (code "TERM")
           " is not always a precise indicator of the best protocol and keydec,
but by default we work with what we have."))

;; TODO: Document the termvars here?  Move this subsection?

(doc (section (code "charterm") " Object")

     (para "The "
           (racket charterm)
           " object captures the state of a session with a particular terminal.")

     (para "A "
           (racket charterm)
           " object is also a synchronizable event, so it can be used with
procedures such as "
           (racket sync)
           ".  As an event, it becomes ready when there is at least one byte
available for reading from the terminal, and its synchronization result is
itself."))

(doc (defproc (charterm? (x any/c))
         boolean?
       (para "Predicate for whether or not "
             (var x)
             " is a "
             (racket charterm)
             ".")))
(provide charterm?)

(doc (defproc (charterm-termvar (ct charterm?))
         (or/c #f string?))
     (para "Gets the "
           (tech "termvar")
           "."))
(provide charterm-termvar)

(doc (defproc (charterm-protocol (ct charterm?))
         symbol?)
     (para "Gets the "
           (tech "protocol")
           "."))
(provide charterm-protocol)

(doc (defproc (charterm-keydec (ct charterm?))
         symbol?)
     (para "Gets the "
           (tech "keydec")
           "."))
(provide (rename-out (charterm-keydec* charterm-keydec)))

(define-struct charterm
  (tty
   in
   out
   evt
   buf-size
   buf
   (buf-start #:mutable)
   (buf-end #:mutable)
   termvar
   protocol
   keydec*
   (screensize #:mutable))
  #:property prop:evt (struct-field-index evt))

(define (%charterm:protocol-unimplemented error-name ct)
  (error error-name
         "protocol unimplemented: ~S"
         (charterm-protocol ct)))

(define (%charterm:protocol-unreachable error-name ct)
  (error error-name
         "internal error: protocol unreachable: ~S"
         (charterm-protocol ct)))

(define %charterm:stty-minus-f-arg-string
  (case (system-type 'os)
    ((macosx) "-f")
    (else     "-F")))
  
(doc (defparam current-charterm ct (or/c #f charterm?)
       (para "This parameter provides the default "
             (racket charterm)
             " for most of the other procedures.  It is usually set automatically by "
             (racket call-with-charterm)
             ", "
             (racket with-charterm)
             ", "
             (racket open-charterm)
             ", and "
             (racket close-charterm)
             ".")))
(provide current-charterm)
(define current-charterm (make-parameter #f))

(doc (defproc (open-charterm
               (#:tty      tty      (or/c #f path-string?) #f)
               (#:current? current? boolean?               #t))
         charterm?
       (para "Returns an open "
             (racket charterm)
             " object, by opening I/O ports on the terminal device at "
             (racket tty)
             " (or, if "
             (racket #f)
             ", file "
             (filepath "/dev/tty")
             "), and setting raw mode and disabling echo (via "
             (filepath "/bin/stty")
             ").  If "
             (racket current?)
             " is true, the "
             (racket current-charterm)
             " parameter is also set to this object.")))
(provide open-charterm)
(define (open-charterm #:tty      (tty      #f)
                       #:current? (current? #t))
  (let* ((tty (cleanse-path (or tty "/dev/tty")))
         (tty-str  (path->string tty)))
    (or (system* "/bin/stty"
                 %charterm:stty-minus-f-arg-string
                 tty-str
                 "raw"
                 "-echo")
        (error 'open-charterm
               "stty ~S failed"
               tty-str))
    (with-handlers ((exn:fail? (lambda (e)
                                 (with-handlers ((exn:fail? void))
                                   (system* "/bin/stty"
                                            %charterm:stty-minus-f-arg-string
                                            tty-str
                                            "sane"))
                                 (raise e))))
      (let*-values (((in out)   (open-input-output-file tty
                                                        #:exists 'update))
                    ((buf-size) 2048))
        ;; TODO: Do we actually need to turn off buffering?
        (file-stream-buffer-mode in  'none)
        (file-stream-buffer-mode out 'none)
        (let*-values
            (((termvar) (getenv "TERM"))
             ((termvar) (cond ((not termvar) #f)
                              ((equal? "" termvar) #f)
                              (else (string-downcase termvar))))
             ((protocol keydec)
              ;; TODO: Once the patterns have been fleshed out, make the exact
              ;; matches a hash, and optimize the regexps.
              (cond ((not termvar) (values #f #f))
                    ;; Exact Matches:
                    ((equal? "ascii"     termvar) (values 'ascii         charterm-ascii-keydec))
                    ((equal? "dumb"      termvar) (values 'ascii         charterm-ascii-keydec))
                    ((equal? "linux"     termvar) (values 'ansi      charterm-linux-keydec))
                    ((equal? "rxvt"      termvar) (values 'ansi      charterm-rxvt-keydec))
                    ((equal? "screen"    termvar) (values 'ansi      charterm-screen-keydec))
                    ((equal? "tvi925"    termvar) (values 'televideo-925 charterm-tvi925-keydec))
                    ((equal? "tvi950"    termvar) (values 'televideo-925 charterm-tvi925-keydec))
                    ((equal? "vt100"     termvar) (values 'ansi      charterm-vt100-keydec))
                    ((equal? "vt102"     termvar) (values 'ansi      charterm-vt100-keydec))
                    ((equal? "vt220"     termvar) (values 'ansi      charterm-vt220-keydec))
                    ((equal? "wy50"      termvar) (values 'wyse-wy50     charterm-wy50-keydec))
                    ((equal? "wy60"      termvar) (values 'wyse-wy50     charterm-wy50-keydec))
                    ((equal? "wy75"      termvar) (values 'wyse-wy50     charterm-wy50-keydec))
                    ((equal? "wyse50"    termvar) (values 'wyse-wy50     charterm-wy50-keydec))
                    ((equal? "wyse60"    termvar) (values 'wyse-wy50     charterm-wy50-keydec))
                    ((equal? "wyse75"    termvar) (values 'wyse-wy50     charterm-wy50-keydec))
                    ((equal? "xterm"     termvar) (values 'ansi      charterm-xterm-new-keydec))
                    ((equal? "xterm-new" termvar) (values 'ansi      charterm-xterm-new-keydec))
                    ;; ANSI-ish Guesses:
                    ((regexp-match #rx"ansi$"  termvar) (values 'ansi charterm-ansi-keydec))
                    ((regexp-match #rx"^ansi"  termvar) (values 'ansi charterm-ansi-keydec))
                    ((regexp-match #rx"^xterm" termvar) (values 'ansi charterm-xterm-new-keydec))
                    ((regexp-match #rx"^rxvt"  termvar) (values 'ansi charterm-rxvt-keydec))
                    ((regexp-match #rx"^vt"    termvar) (values 'ansi charterm-rxvt-keydec))
                    ;; Non-ANSI Guesses:
                    ((regexp-match #rx"^wy"  termvar) (values 'wyse-wy50     charterm-wy50-keydec))
                    ((regexp-match #rx"^tvi" termvar) (values 'televideo-925 charterm-tvi925-keydec))
                    ;; Default:
                    (else (values #f #f))))
             ((protocol keydec)
              (values (or protocol 'ansi)
                      (or keydec charterm-ansi-keydec))))
          (letrec ((wrapping-evt (wrap-evt in
                                           (lambda (evt) ct)))
                   (ct (make-charterm tty-str               ; tty
                                      in                    ; in
                                      out                   ; out
                                      wrapping-evt          ; evt
                                      buf-size              ; buf-size
                                      (make-bytes buf-size) ; buf
                                      0                     ; buf-start
                                      0                     ; buf-end
                                      termvar               ; termvar
                                      protocol              ; protocol
                                      keydec                ; keydec
                                        ; screensize
                                      (if (and (eq? protocol 'ansi)
                                               (not (member termvar '("screen"))))
                                          'control/stty/none
                                          'stty/none))))
            (and current?
                 (current-charterm ct))
            ct))))))

(doc (defproc (close-charterm (#:charterm ct charterm? (current-charterm)))
         void?
       (para "Closes "
             (racket ct)
             " by closing the I/O ports, and undoing "
             (racket open-charterm)
             "'s changes via "
             (filepath "/bin/stty")
             ".  If "
             (racket current-charterm)
             " is set to "
             (racket ct)
             ", then that parameter will be changed to "
             (racket #f)
             " for good measure.  You might wish to use "
             (racket with-charterm)
             " instead of worrying about calling "
             (racket close-charterm)
             " directly.")
       (para "Note: If you exit your Racket process without properly closing the "
             (racket charterm)
             ", your terminal may be left in a crazy state.  You can fix it with
the command:")
       (commandline "stty sane")))
(provide close-charterm)
(define (close-charterm #:charterm (ct (current-charterm)))
  (with-handlers ((exn:fail? void)) (close-input-port  (charterm-in ct)))
  (with-handlers ((exn:fail? void)) (close-output-port (charterm-out ct)))
  ;; TODO: Set the port fields of the struct to #f?
  (if (with-handlers ((exn:fail? (lambda (e) #f)))
        (system* "/bin/stty"
                 %charterm:stty-minus-f-arg-string
                 (charterm-tty ct)
                 "cooked"
                 "echo"))
      (if (eq? ct (current-charterm))
          (current-charterm #f)
          (void))
      (error 'close-charterm
             "stty failed")))

;; (define (call-with-charterm proc #:tty (tty #f))
;;   (let* ((tty (cleanse-path tty))
;;          (ct  (open-charterm #:tty tty #:current? #f)))
;;     (dynamic-wind
;;       void
;;       (lambda ()
;;         (proc ct))
;;       (lambda ()
;;         (close-charterm #:charterm ct)))))

(doc (defform (with-charterm expr? ...))
     (para "Opens a "
           (racket charterm)
           " and evaluates the body expressions in sequence with "
           (racket current-charterm)
           " set appropriately.  When control jumps out of the body, in a
manner of speaking, the "
           (racket charterm)
           " is closed."))
(provide with-charterm)
(define-syntax (with-charterm stx)
  (syntax-case stx ()
    ((_ BODY0 BODYn ...)
     #'(let ((ct #f))
         (dynamic-wind
           (lambda ()
             (set! ct (open-charterm #:current? #t)))
           (lambda ()
             BODY0 BODYn ...)
           (lambda ()
             (close-charterm #:charterm ct)
             (set! ct #f)))))))

(doc (section "Terminal Information"))

(doc (defproc (charterm-screen-size (#:charterm ct charterm? (current-charterm)))
         (values (or/c #f exact-nonnegative-integer?)
                 (or/c #f exact-nonnegative-integer?))
       (para "Attempts to get the screen size, in character columns and rows.
It may do this through a control sequence or through "
             (code "/bin/stty")
             ".  If unable to get a value, then default of (80,24) is used.")
       (para "The current behavior in this version of "
             (code "charterm")
             " is to adaptively try different methods of getting screen size,
and to remember what worked for the next time this procedure is called for "
             (racket ct)
             ".  For terminals that are identified as "
             (code "screen")
             " by the "
             (code "TERM")
             " environment variable (e.g., terminal emulators like GNU Screen
and "
             (code "tmux")
             "), the current behavior is to not try the control sequence (which
causes a 1-second delay waiting for a terminal response that never arrives),
and to just use "
             (code "stty")
             ".  For all other terminals, the control sequence is tried first, before trying "
             (code "stty")
             ".  If neither the control sequence nor "
             (code "stty")
             " work, then neither method is tried again for "
             (racket ct)
             ", and instead the procedure always returns ("
             (racket #f)
             ", "
             (racket #f)
             ").  This behavior very well might change in future versions of "
             (code "charterm")
             ", and the author welcomes feedback on which methods work with
which terminals.")))
(provide charterm-screen-size)
(define (charterm-screen-size #:charterm (ct (current-charterm)))
  ;; TODO: Make it store screen side in slots of charterm object too.  Then
  ;; create a "with-resizeable-charterm" form that has a resize handler (or
  ;; maybe make the resize handler an argument to "with-charterm".
  (let loop ()
    (case (charterm-screensize ct)
      ((control) (%charterm:screen-size-via-control ct))
      ((stty)    (%charterm:screen-size-via-stty    ct))
      ;; TODO: Instead of (80,24), maybe be sensitive to termvar.
      ((none)    (values 80 24))
      ((control/stty/none)
       (let-values (((cols rows) (%charterm:screen-size-via-control ct)))
         (if (and cols rows)
             (values cols rows)
             (begin (set-charterm-screensize! ct 'stty/none)
                    (loop)))))
      ((stty/none)
       (let-values (((cols rows) (%charterm:screen-size-via-stty ct)))
         (if (and cols rows)
             (values cols rows)
             (begin (set-charterm-screensize! ct 'none)
                    (loop)))))
      (else (error 'charterm-screen-size
                   "invalid screensize ~S"
                   (charterm-screensize ct))))))

(define (%charterm:screen-size-via-control ct)
  (%charterm:protocol-case
   '%charterm:screen-size-via-control
   (charterm-protocol ct)
   ((ansi)
    (%charterm:write-bytes ct #"\e[18t")
    (cond ((%charterm:read-regexp-response ct #rx#"\e\\[8;([0-9]+);([0-9]+)t")
           => (lambda (m)
                (values (%charterm:bytes-ascii->nonnegative-integer (list-ref m 1))
                        (%charterm:bytes-ascii->nonnegative-integer (list-ref m 0)))))
          ;; TODO: We could do "ioctl" "TIOCGWINSZ", but that means FFI.
          ;;
          ;; TODO: We could execute "stty -a" (or perhaps "stty -g") to get
          ;; around doing an FFI call.
          (else (values #f #f))))
   ((wyse-wy50 televideo-925)
    (%charterm:protocol-unreachable '%charterm:screen-size-via-control ct))))

(define (%charterm:screen-size-via-stty ct)
  (let* ((stdout (open-output-bytes))
         (stderr (open-output-bytes))
         (proc   (list-ref (process*/ports stdout
                                           (open-input-bytes #"")
                                           stderr
                                           "/bin/stty"
                                           %charterm:stty-minus-f-arg-string
                                           (charterm-tty ct)
                                           "-a")
                           4))
         (bstr   (begin (proc 'wait)
                        (get-output-bytes stdout))))
    (if (eq? 'done-ok (proc 'status))
        (let-values (((width height)
                      (cond ((regexp-match-positions
                              #rx#"rows +([0-9]+);.*columns +([0-9]+)"
                              bstr)
                             => (lambda (m)
                                  (values (%charterm:bytes-ascii->nonnegative-integer
                                           (subbytes bstr (caaddr m) (cdaddr m)))
                                          (%charterm:bytes-ascii->nonnegative-integer
                                           (subbytes bstr (caadr  m) (cdadr m))))))
                            ((regexp-match-positions
                              #rx#"columns +([0-9]+);.*rows +([0-9]+)"
                              bstr)
                             => (lambda (m)
                                  (values (%charterm:bytes-ascii->nonnegative-integer
                                           (subbytes bstr (caadr  m) (cdadr m)))
                                          (%charterm:bytes-ascii->nonnegative-integer
                                           (subbytes bstr (caaddr m) (cdaddr m))))))
                            (else #f #f))))
          ;; Note: These checks for 0 are for if "stty" returns 0, such as
          ;; seems to happen in the emulator on the Wyse S50 when in SSH rather than Telnet.
          (values (if (zero? width)  #f width)
                  (if (zero? height) #f height)))
        (values #f #f))))

(doc (section "Display Control"))

(define (%charterm:shift-buf ct)
  (let ((buf-start (charterm-buf-start ct))
        (buf-end   (charterm-buf-end   ct)))
    (if (= buf-start buf-end)
        ;; Buffer is empty, so are buf-start and buf-end at 0?
        (if (zero? buf-end)
            (void)
            (begin (set-charterm-buf-start! ct 0)
                   (set-charterm-buf-end!   ct 0)))
        ;; Buffer is not empty, so is buf-start at 0?
        ;;
        ;; TODO: Maybe make this shift only if we need to to free N additional
        ;; bytes at the end?
        (if (zero? buf-start)
            (void)
            (let ((buf (charterm-buf ct)))
              (bytes-copy! buf 0 buf buf-start buf-end)
              (set-charterm-buf-start! ct 0)
              (set-charterm-buf-end!   ct (- buf-end buf-start)))))))

(define (%charterm:read-into-buf/timeout ct timeout)
  (let ((in (charterm-in ct)))
    (let loop ()
      (let ((sync-result (sync/timeout/enable-break timeout in)))
        (cond ((not sync-result) #f)
              ((eq? sync-result in)
               ;; TODO: if buf is empty, then read into start 0!
               (let ((read-result (read-bytes-avail! (charterm-buf      ct)
                                                     in
                                                     (charterm-buf-end  ct)
                                                     (charterm-buf-size ct))))
                 (if (zero? read-result)
                     ;; TODO: If there's a timeout, subtract from it?
                     (loop)
                     (begin (set-charterm-buf-end! ct (+ (charterm-buf-end ct) read-result))
                            read-result))))
              (else (error '%charterm:read-into-buf/timeout
                           "*DEBUG* sync returned ~S"
                           sync-result)))))))

(define (%charterm:read-regexp-response ct rx #:timeout-seconds (timeout-seconds 1.0))
  (let ((in (charterm-in ct)))
    (%charterm:shift-buf ct)
    ;; TODO: Implement timeout better, by checking clock and doing
    ;; sync/timeout, or by setting timer.
    (let loop ((timeout-seconds timeout-seconds))
      (if (= (charterm-buf-end ct) (charterm-buf-size ct))
          (begin
            ;; TODO: Make this an exception instead of #f?
            #f)
          (begin (or (let ((buf       (charterm-buf       ct))
                           (buf-start (charterm-buf-start ct))
                           (buf-end   (charterm-buf-end   ct)))
                       (cond ((regexp-match-positions rx
                                                      buf
                                                      buf-start
                                                      buf-end)
                              => (lambda (m)
                                   ;; TODO: Audit and test some of this buffer
                                   ;; code here and elsewhere.
                                   (let ((match-start (caar m))
                                         (match-end   (cdar m)))
                                     (if (= match-start buf-start)
                                         (set-charterm-buf-start! ct match-end)
                                         (if (= match-end buf-end)
                                             (set-charterm-buf-end! ct match-start)
                                             (begin (bytes-copy! buf
                                                                 match-start
                                                                 buf
                                                                 match-end
                                                                 buf-end)
                                                    (set-charterm-buf-end! ct
                                                                           (+ match-start
                                                                              (- buf-end
                                                                                 match-end)))))))

                                   (map (lambda (pos)
                                          (subbytes buf (car pos) (cdr pos)))
                                        (cdr m))))
                             (else #f)))
                     (if (%charterm:read-into-buf/timeout ct timeout-seconds)
                         (loop timeout-seconds)
                         #f
                         )))))))

(define (%charterm:bytes-ascii->nonnegative-integer bstr)
  (let ((bstr-len (bytes-length bstr)))
    (let loop ((i      0)
               (result 0))
      (if (= i bstr-len)
          result
          (let* ((b     (bytes-ref bstr i))
                 (b-num (- b 48)))
            (if (<= 0 b-num 9)
                (loop (+ 1 i)
                      (+ (* 10 result) b-num))
                (error '%charterm:bytes-ascii->nonnegative-integer
                       "invalid byte ~S"
                       b)))))))

(doc (subsection "Cursor"))

(doc (defproc (charterm-cursor (x exact-positive-integer?)
                               (y exact-positive-integer?)
                               (#:charterm ct charterm? (current-charterm)))
         void?
       (para "Positions the cursor at column "
             (racket x)
             ", row "
             (racket y)
             ", with the upper-left character cell being (1, 1).")))
(provide charterm-cursor)
(define (charterm-cursor x y #:charterm (ct (current-charterm)))
  (%charterm:position ct x y))

(doc (defproc (charterm-newline (#:charterm ct charterm? (current-charterm)))
         void?
       (para "Sends a newline to the terminal.  This is typically a CR-LF
sequence.")))
(provide charterm-newline)
(define (charterm-newline #:charterm (ct (current-charterm)))
  (%charterm:write-bytes ct #"\r\n"))

(doc (subsection "Displaying"))

(define %charterm:err-byte 63)

(doc (defproc (charterm-display
               (#:charterm ct       charterm?                         (current-charterm))
               (#:width    width    (or/c #f exact-positive-integer?) #f)
               (#:pad      pad      (or/c 'width boolean?)            'width)
               (#:truncate truncate (or/c 'width boolean?)            'width)
               (           arg      any/c) ...)
         void?
       (para "Displays each "
             (racket arg)
             " on the terminal, as if formatted by "
             (racket display)
             ", with the exception that unprintable or non-ASCII characters
might not be displayed.  (The exact behavior of what is permitted is expected
to change in a later version of "
             "CharTerm"
             ", so avoid trying to send your own control sequences or using
newlines, making assumptions about non-ASCII characters, etc.)")
       (para "If "
             (racket width)
             " is a number, then "
             (racket pad)
             " and "
             (racket truncate)
             " specify whether or not to pad with spaces or truncate the output, respectively, to "
             (racket width)
             " characters.  When "
             (racket pad)
             " or "
             (racket width)
             " is "
             (racket 'width)
             ", that is a convenience meaning ``true if, and only if, "
             (racket width)
             " is not "
             (racket #f)
             ".''")))
(provide charterm-display)
(define (charterm-display #:charterm (ct       (current-charterm))
                          #:width    (width    #f)
                          #:pad      (pad      'width)
                          #:truncate (truncate 'width)
                          . args)
  ;; TODO: make it replace unprintable and non-ascii characters with "?".  Even newlines, tabs, etc?
  ;;
  ;; TODO: Do we want buffering?
  (let ((out      (charterm-out ct))
        (pad      (if (eq? 'width pad)      (if width #t #f) pad))
        (truncate (if (eq? 'width truncate) (if width #t #f) truncate)))
    (and pad      (not width) (error 'charterm-display "#:pad cannot be true if #:width is not"))
    (and truncate (not width) (error 'charterm-display "#:truncate cannot be true if #:width is not"))
    (let loop ((args            args)
               (remaining-width (or width 0)))
      (if (null? args)
          (if (and pad (> remaining-width 0))
              ;; TODO: Get rid of this allocation.
              (begin (%charterm:write-bytes ct (make-bytes remaining-width 32))
                     (void))
              (void))
          (let* ((arg (car args))
                 (bytes (cond ((bytes? arg)
                               arg)
                              ((string? arg)
                               (string->bytes/latin-1 arg
                                                      %charterm:err-byte
                                                      0
                                                      (if truncate
                                                          (min (string-length arg)
                                                               remaining-width)
                                                          (string-length arg))))
                              ((number? arg)
                               (string->bytes/latin-1 (number->string arg)
                                                      %charterm:err-byte))
                              (else (let ((arg (format "~A" arg)))
                                      (string->bytes/latin-1 arg
                                                             %charterm:err-byte
                                                             0
                                                             (if truncate
                                                                 (min (string-length arg)
                                                                      remaining-width)
                                                                 (string-length arg)))))))
                 (remaining-width (- remaining-width (bytes-length bytes))))
            (cond ((or (not truncate) (> remaining-width 0))
                   (%charterm:write-bytes ct bytes)
                   (loop (cdr args)
                         remaining-width))
                  ((zero? remaining-width)
                   (%charterm:write-bytes ct bytes)
                   (void))
                  (else (%charterm:write-subbytes ct bytes 0 (+ (bytes-length bytes)
                                                                remaining-width))
                        (void))))))))

(define (%charterm:send-code ct . args)
  ;; TODO: Do we want buffering?
  (let ((out (charterm-out ct)))
    (let loop ((args args))
      (if (null? args)
          (void)
          (let ((arg (car args)))
            (cond ((bytes? arg)
                   (write-bytes arg out))
                  ((string? arg)
                   (write-string arg out))
                  ((integer? arg)
                   (display (inexact->exact arg) out))
                  ((pair? arg)
                   (loop (car arg))
                   (loop (cdr arg)))
                  (else (error '%charterm:send-code
                               "don't know how to send ~S"
                               arg)))
            (loop (cdr args)))))))

;; (define %charterm:2-digit-bytes-vector
;;   (vector #"00" #"01" #"02" #"03" #"04" #"05" #"06" #"07"
;;           #"08" #"09" #"10" #"11" #"12" #"13" #"14" #"15"
;;           #"16" #"17" #"18" #"19" #"20" #"21" #"22" #"23"
;;           #"24" #"25" #"26" #"27" #"28" #"29" #"30" #"31"
;;           #"32" #"33" #"34" #"35" #"36" #"37" #"38" #"39"
;;           #"40" #"41" #"42" #"43" #"44" #"45" #"46" #"47"
;;           #"48" #"49" #"50" #"51" #"52" #"53" #"54" #"55"
;;           #"56" #"57" #"58" #"59" #"60" #"61" #"62" #"63"
;;           #"64" #"65" #"66" #"67" #"68" #"68" #"69" #"70"
;;           #"72" #"73" #"74" #"75" #"76" #"77" #"78" #"79"
;;           #"80" #"81" #"82" #"83" #"84" #"85" #"86" #"87"))

(define %charterm:televideo-925-cursor-position-to-byte-vector
  (list->vector (cons #f
                      (for/list ((n (in-range 1 96)))
                        (+ 31 n)))))

;; (provide/contract with error-checks on args
(define (%charterm:position ct x y)
  (%charterm:protocol-case
   '%charterm:position
   (charterm-protocol ct)
   ((ansi)
    (if (and (= 1 x) (= 1 y))
        (%charterm:write-bytes ct #"\e[;H")
        (%charterm:send-code ct #"\e[" y #";" x #"H")))
   ((wyse-wy50)
    ;; Note: We are using the WY-50 long codes because we don't know
    ;; confidently that we are an 80-column screen.
    (if (and (= 1 x) (= 1 y))
        (%charterm:write-bytes ct #"\ea1R1C")
        (%charterm:send-code ct #"\ea" y #"R" x #"C")))
   ((televideo-925)
    (if (and (= 1 x) (= 1 y))
        (%charterm:write-bytes ct #"\e=  ")
        (begin (%charterm:write-bytes ct #"\e=")
               (%charterm:write-byte ct (vector-ref %charterm:televideo-925-cursor-position-to-byte-vector y))
               (%charterm:write-byte ct (vector-ref %charterm:televideo-925-cursor-position-to-byte-vector x)))))))

(doc (subsection "Video Attributes"))

;; TODO: !!! document link to protocol section

;; TODO: !!! define "charterm-has-video-attributes?"

(doc (defproc*
         (((charterm-normal    (#:charterm ct charterm? (current-charterm))) void?)
          ((charterm-inverse   (#:charterm ct charterm? (current-charterm))) void?)
          ((charterm-underline (#:charterm ct charterm? (current-charterm))) void?)
          ((charterm-blink     (#:charterm ct charterm? (current-charterm))) void?)
          ((charterm-bold      (#:charterm ct charterm? (current-charterm))) void?))
       (para "Sets the "
             (deftech "video attributes")
             " for subsequent writes to the terminal.  In this version of "
             (code "charterm")
             ", each is mutually-exclusive, so, for example, setting "
             (italic "bold")
             " clears "
             (italic "inverse")
             ". Note that that video attributes are currently supported only for protocol "
             (racket 'ansi)
             ", due to limitations of the TeleVideo and Wyse models for
video attributes.")))

(provide charterm-normal)
(define (charterm-normal #:charterm (ct (current-charterm)))
  (%charterm:protocol-case
   'charterm-normal
   (charterm-protocol ct)
   ((ansi)      (%charterm:write-bytes ct #"\e[m"))
   ((wyse-wy50)     (void)) ; (%charterm:write-bytes ct #"\eA00"))
   ((televideo-925) (void))))

(provide charterm-inverse)
(define (charterm-inverse #:charterm (ct (current-charterm)))
  (%charterm:protocol-case
   'charterm-inverse
   (charterm-protocol ct)
   ((ansi)      (%charterm:write-bytes ct #"\e[;7m"))
   ((wyse-wy50)     (void)) ; (%charterm:write-bytes ct #"\eA04"))
   ((televideo-925) (void))))

(provide charterm-underline)
(define (charterm-underline #:charterm (ct (current-charterm)))
  (%charterm:protocol-case
   'charterm-underline
   (charterm-protocol ct)
   ((ansi)      (%charterm:write-bytes ct #"\e[4m"))
   ((wyse-wy50)     (void)) ; (%charterm:write-bytes ct #"\eA08"))
   ((televideo-925) (void))))

(provide charterm-blink)
(define (charterm-blink #:charterm (ct (current-charterm)))
  (%charterm:protocol-case
   'charterm-blink
   (charterm-protocol ct)
   ((ansi)      (%charterm:write-bytes ct #"\e[5m"))
   ((wyse-wy50)     (void)) ; (%charterm:write-bytes ct #"\eA02"))
   ((televideo-925) (void))))

(provide charterm-bold)
(define (charterm-bold #:charterm (ct (current-charterm)))
  (%charterm:protocol-case
   'charterm-bold
   (charterm-protocol ct)
   ((ansi)      (%charterm:write-bytes ct #"\e[1m"))
   ((wyse-wy50)     (void)) ; (%charterm:write-bytes ct #"\eA0<"))
   ((televideo-925) (void))))

(doc (subsection "Clearing"))

(doc (defproc (charterm-clear-screen (#:charterm ct charterm? (current-charterm)))
         void?
       (para "Clears the screen, including first setting the video attributes to
normal, and positioning the cursor at (1, 1).")))
(provide charterm-clear-screen)
(define (charterm-clear-screen #:charterm (ct (current-charterm)))
  ;; TODO: Have a #:style argument?  Or #:background argument?
  (%charterm:protocol-case
   'charterm-clear-screen
   (charterm-protocol ct)
   ((ansi)      (%charterm:write-bytes ct #"\e[m\e[2J\e[;H"))
   ((wyse-wy50)     (%charterm:write-bytes ct #"\e+\e*\ea1R1C"))
   ((televideo-925) (%charterm:write-bytes ct #"\e+\e=  "))))

(doc (defproc*
         (((charterm-clear-line       (#:charterm ct charterm? (current-charterm))) void?)
          ((charterm-clear-line-left  (#:charterm ct charterm? (current-charterm))) void?)
          ((charterm-clear-line-right (#:charterm ct charterm? (current-charterm))) void?))
       (para "Clears text from the line with the cursor, or part of the line with the cursor.")))

(provide charterm-clear-line)
(define (charterm-clear-line #:charterm (ct (current-charterm)))
  (%charterm:protocol-case
   'charterm:clear-line
   (charterm-protocol ct)
   ((ansi)      (%charterm:write-bytes ct #"\e[2K"))
   ((televideo-925) (%charterm:write-bytes ct #"\r\eT"))
   ;; TODO: wyse-wy50 is clearing to nulls, not spaces.
   ((wyse-wy50)     (%charterm:write-bytes ct #"\r\et"))))

(provide charterm-clear-line-left)
(define (charterm-clear-line-left #:charterm (ct (current-charterm)))
  (%charterm:protocol-case
   'charterm-clear-line-left
   (charterm-protocol ct)
   ((ansi) (%charterm:write-bytes ct #"\e[1K"))
   ((televideo-925 wyse-wy50)
    ;; TODO: Do this by getting cursor position, then reposition and write spaces?
    (%charterm:unimplemented ct 'clearterm-clear-line-left))))

(provide charterm-clear-line-right)
(define (charterm-clear-line-right #:charterm (ct (current-charterm)))
  (%charterm:protocol-case
   'charterm-clear-line-right
   (charterm-protocol ct)
   ((ansi)      (%charterm:write-bytes ct #"\e[K"))
   ((televideo-925) (%charterm:write-bytes ct #"\eT"))
   ;; TODO: wyse-wy50 is clearing to nulls, not spaces.
   ((wyse-wy50)     (%charterm:write-bytes ct #"\et"))))

(doc (subsection "Line Insert and Delete"))

(doc (defproc (charterm-insert-line (count exact-positive-integer? 1)
                                    (#:charterm ct charterm? (current-charterm)))
         void?
       (para "Inserts "
             (racket count)
             " blank lines at cursor.  Note that not all terminals support
this.")))
(provide charterm-insert-line)
(define (charterm-insert-line (count 1) #:charterm (ct (current-charterm)))
  (if (integer? count)
      (cond ((= count 0) (void))
            ((> count 0)
             (%charterm:protocol-case
              'charterm-insert-line
              (charterm-protocol ct)
              ((ansi)                (%charterm:send-code ct #"\e[" count "L"))
              ((wyse-wy50 televideo-925) (%charterm:write-bytes ct #"\eE"))))
            (else (error 'charterm-insert-line
                         "invalid count: ~S"
                         count)))
      (error 'charterm-insert-line
             "invalid count: ~S"
             count)))

(doc (defproc (charterm-delete-line (count exact-positive-integer? 1)
                                    (#:charterm ct charterm? (current-charterm)))
         void?
       (para "Deletes "
             (racket count)
             " blank lines at cursor.  Note that not all terminals support
this.")))
(provide charterm-delete-line)
(define (charterm-delete-line (count 1) #:charterm (ct (current-charterm)))
  (if (integer? count)
      (cond ((= count 0) (void))
            ((> count 0)
             (%charterm:protocol-case
              'charterm-delete-line
              (charterm-protocol ct)
              ((ansi)
               (%charterm:send-code ct #"\e[" count "M"))
              ((wyse-wy50 televideo-925)
               (if (= 1 count)
                   (%charterm:write-bytes ct #"\eR")
                   (let ((bstr (make-bytes (* 2 count) 82)))
                     (let loop ((n (* 2 (- count 1))))
                       (bytes-set! bstr n 27)
                       (if (zero? n)
                           (%charterm:write-bytes ct bstr)
                           (loop (- n 2)))))))))
            (else (error 'charterm-delete-line
                         "invalid count: ~S"
                         count)))
      (error 'charterm-delete-line
             "invalid count: ~S"
             count)))

(doc (subsubsection "Misc. Output"))

(doc (defproc (charterm-bell (#:charterm ct charterm? (current-charterm)))
         void?
       (para "Rings the terminal bell.  This bell ringing might manifest as a
beep, a flash of the screen, or nothing.")))
(provide charterm-bell)
(define (charterm-bell #:charterm (ct (current-charterm)))
  (%charterm:write-bytes ct #"\007"))

(doc (section "Keyboard Input")

     ;; TODO: !!! document link to terminal diversity section

     (para "Normally you will get keyboard input using the "
           (racket charterm-read-key)
           " procedure."))

(doc (defproc (charterm-byte-ready? (#:charterm ct charterm? (current-charterm)))
         boolean?
       (para "Returns true/false for whether at least one byte is ready for
reading (either in a buffer or on the port) from "
             (racket ct)
             ".  Note that, since some keys are encoded as multiple bytes, just
because this procedure returns true doesn't mean that "
             (racket charterm-read-key)
             " won't block temporarily because it sees part of a potential
multiple-byte key encoding.")))
(provide charterm-byte-ready?)
(define (charterm-byte-ready? #:charterm (ct (current-charterm)))
  (or (> (charterm-buf-end ct) (charterm-buf-start ct))
      (byte-ready? (charterm-in ct))))

(doc (defproc (charterm-read-key
               (#:charterm ct      charterm?           (current-charterm))
               (#:timeout  timeout (or/c #f positive?) #f))
         (or #f char? symbol?)
       (para "Reads a key from "
             (racket ct)
             ", blocking indefinitely or until sometime after "
             (racket timeout)
             " seconds has been reached, if "
             (racket timeout)
             " is non-"
             (racket #f)
             ".  If timeout is reached, "
             (racket #f)
             " is returned.")
       (para "Many keys are returned as characters, especially ones that
correspond to printable characters.  For example, the unshifted "
             (bold "Q")
             " key is returned as character "
             (racket #\q)
             ".  Some other keys are returned as symbols, such as "
             (racket 'return)
             ", "
             (racket 'escape)
             ", "
             (racket 'f1)
             ", "
             (racket 'shift-f12)
             ", "
             (racket 'right)
             ", and many others.")
       (para "Since some keys are sent as ambiguous sequences, "
             (racket charterm-read-key)
             " employs separate timeouts internally, such as to disambuate
the "
             (bold "Esc")
             " key (byte sequence 27) from what on some terminals would be
the "
             (bold "F10")
             " key (bytes sequence 27, 91, 50, 49, 126).")))
(provide charterm-read-key)
(define (charterm-read-key #:charterm (ct      (current-charterm))
                           #:timeout  (timeout #f))
  (%charterm:read-keyinfo-or-key 'charterm-read-key ct timeout #f))

(doc (defproc (charterm-read-keyinfo
               (#:charterm ct      charterm?           (current-charterm))
               (#:timeout  timeout (or/c #f positive?) #f))
         charterm-keyinfo?
       (para "Like "
             (racket charterm-read-keyinfo)
             " except instead of returning a "
             (tech "keycode")
             ", it returns a "
             (tech "keyinfo")
             ".")))
(provide charterm-read-keyinfo)
(define (charterm-read-keyinfo #:charterm (ct      (current-charterm))
                               #:timeout  (timeout #f))
  (%charterm:read-keyinfo-or-key 'charterm-read-keyinfo ct timeout #t))

(define (%charterm:read-keyinfo-or-key error-name ct timeout keyinfo?)
  ;; TODO: Maybe make this shift decision smarter -- compile the key tree ahead
  ;; of time so we know the max depth, and then we know exactly the max space
  ;; we will need for this call.
  (and (< (- (charterm-buf-size ct)
             (charterm-buf-start ct))
          10)
       (%charterm:shift-buf ct))
  (let ((buf       (charterm-buf        ct))
        (buf-start (charterm-buf-start  ct))
        (buf-end   (charterm-buf-end    ct))
        (buf-size  (charterm-buf-size   ct))
        (keydec    (charterm-keydec*    ct))
        (b1        (%charterm:read-byte/timeout ct timeout)))
    (if b1
        (or (let loop ((tree        (charterm-keydec-primary-keytree keydec))
                       (probe-start (+ 1 buf-start))
                       (b           b1))
              (cond ((hash-ref tree b #f)
                     => (lambda (code-or-subtree)
                          (cond ((hash? code-or-subtree)
                                 ;; We have more subtree to search.
                                 (if (or (< probe-start buf-end)
                                         (and (< buf-end buf-size)
                                              (%charterm:read-into-buf/timeout ct 0.5)))
                                     ;; We have at least one more byte, so recurse.
                                     (loop code-or-subtree
                                           (+ 1 probe-start)
                                           (bytes-ref buf probe-start))
                                     ;; We have hit timeout or end of buffer, so
                                     ;; just accept the original byte.
                                     #f))
                                ((charterm-keyinfo? code-or-subtree)
                                 ;; We found our keyinfo, so consume the input and return the value.
                                 (begin (set-charterm-buf-start! ct probe-start)
                                        (if keyinfo?
                                            code-or-subtree
                                            (charterm-keyinfo-keycode code-or-subtree))
                                        ))
                                (else (error error-name
                                             "invalid object in keytree keyinfo position: ~S"
                                             code-or-subtree)))))
                    (else #f)))
            ;; We didn't find a key code, so try secondary keytree with initial byte.
            (cond ((hash-ref (charterm-keydec-secondary-keytree keydec) b1 #f)
                   => (lambda (keyinfo)
                        (if keyinfo?
                            keyinfo
                            (charterm-keyinfo-keycode keyinfo))))
                  (else (if keyinfo?
                            ;; TODO: Cache these keyinfos for unrecognized keys
                            ;; in the charterm object, or make a fallback
                            ;; keyset for them (although the fallback keyset,
                            ;; while it works for 8-bit characters, becomes
                            ;; less practical if we implement multibyte).
                            (make-charterm-keyinfo #f
                                                   #f
                                                   (list b1)
                                                   "???"
                                                   b1
                                                   (list b1))
                            (integer->char b1)))))
        ;; Got a timeout, so return #f.
        #f)))

(define (%charterm:write-byte ct byt)
  (write-byte byt (charterm-out ct)))

(define (%charterm:write-bytes ct bstr . rest-bstrs)
  (write-bytes bstr (charterm-out ct))
  (or (null? rest-bstrs)
      (for-each (lambda (bstr)
                  (write-bytes bstr (charterm-out ct)))
                rest-bstrs)))

(define (%charterm:write-subbytes ct bstr start end)
  (write-bytes bstr (charterm-out ct) start end))

(define (%charterm:read-byte/timeout ct timeout)
  (let ((buf-start (charterm-buf-start ct)))
    (if (or (< buf-start (charterm-buf-end ct))
            (%charterm:read-into-buf/timeout ct timeout))
        (begin0 (bytes-ref (charterm-buf ct) buf-start)
          (set-charterm-buf-start! ct (+ 1 buf-start)))
        #f)))

(define (%charterm:read-byte ct)
  (%charterm:read-byte/timeout ct #f))

(doc (section "References")

     (para "[" (deftech "ANSI X3.64") "] "
           (url "http://en.wikipedia.org/wiki/ANSI_escape_code"))

     (para "[" (deftech "ASCII") "] "
           (url "http://en.wikipedia.org/wiki/Ascii"))
     
     (para "[" (deftech "ECMA-43") "] "
           (hyperlink "http://www.ecma-international.org/publications/standards/Ecma-043.htm"
                      (italic "Standard ECMA-43: 8-bit Coded Character Set Structure and Rules"))
           ", 3rd Ed., 1991-12")

     (para "[" (deftech "ECMA-48") "] "
           (hyperlink "http://www.ecma-international.org/publications/standards/Ecma-048.htm"
                      (italic "Standard ECMA-48: Control Functions for Coded Character Sets"))
           ", 5th Ed., 1991-06")

     (para "[" (deftech "Gregory") "] "
           "Phil Gregory, ``"
           (hyperlink "http://aperiodic.net/phil/archives/Geekery/term-function-keys.html"
                      "Terminal Function Key Escape Codes")
           ",'' 2005-12-13 Web post, as viewed on 2012-06")

     (para "[" (deftech "PowerTerm") "] "
           "Ericom PowerTerm InterConnect 8.2.0.1000 terminal emulator, as run on Wyse S50 WinTerm")

     (para "[" (deftech "TVI-925-IUG") "] "
           (hyperlink "http://vt100.net/televideo/tvi925_ig.pdf"
                      (italic "TeleVideo Model 925 CRT Terminal Installation and User's Guide")))

     (para "[" (deftech "TVI-950-OM") "] "
           (hyperlink "http://www.mirrorservice.org/sites/www.bitsavers.org/pdf/televideo/Operators_Manual_Model_950_1981.pdf"
                      (italic "TeleVideo Operator's Manual Model 950"))
           ", 1981")
     
     (para "[" (deftech "VT100-TM") "] "
           "Digital Equipment Corp., "
           (hyperlink "http://vt100.net/docs/vt100-tm/"
                      (italic "VT100 Series Technical Manual"))
           ", 2nd Ed., 1980-09")
     
     (para "[" (deftech "VT100-UG") "] "
           "Digital Equipment Corp., "
           (hyperlink "http://vt100.net/docs/vt100-ug/"
                      (italic "VT100 User Guide"))
           ", 3rd Ed., 1981-06")
                      
     (para "[" (deftech "VT100-WP") "] "
           "Wikipedia, "
           (hyperlink "http://en.wikipedia.org/wiki/VT100"
                      "VT100"))

     (para "[" (deftech "WY-50-QRG") "] "
           (hyperlink "http://vt100.net/wyse/wy-50-qrg/wy-50-qrg.pdf"
                      (italic "Wyse WY-50 Display Terminal Quick-Reference Guide")))

     (para "[" (deftech "WY-60-UG") "] "
           (hyperlink "http://vt100.net/wyse/wy-60-ug/wy-60-ug.pdf"
                      (italic "Wyse WY-60 User's Guide")))

     (para "[" (deftech "wy60") "] "
           (hyperlink "http://code.google.com/p/wy60/"
                      (code "wy60")
                      " terminal emulator"))

     (para "[" (deftech "XTerm-ctlseqs") "] "
           "Edward Moy, Stephen Gildea, Thomas Dickey, ``"
           (hyperlink "http://invisible-island.net/xterm/ctlseqs/ctlseqs.html"
                      "Xterm Control Sequences")
           ",'' 2012")

     (para "[" (deftech "XTerm-Dickey") "] "
           (url "http://invisible-island.net/xterm/"))

     (para "[" (deftech "XTerm-FAQ") "] "
           "Thomas E. Dickey, ``"
           (hyperlink "http://invisible-island.net/xterm/xterm.faq.html"
                      "XTerm FAQ")
           ",'' dated 2012")

     (para "[" (deftech "XTerm-WP") "] "
           "Wikipedia, "
           (hyperlink "http://en.wikipedia.org/wiki/Xterm"
                      "xterm"))
           
     )

(doc (section "Known Issues")

     (itemlist

      (item "Need to support ANSI alternate CSI for 8-bit terminals, even
before supporting 8-bit characters and multibyte.")

      (item "Only supports ASCII characters.  Adding UTF-8 support, for terminal emulators
that support it, would be nice.")
      
      (item "Expose the character-decoding mini-language as a configurable
option.  Perhaps wait until we implement timeout-based disambiguation at
arbitrary points in the the DFA rather than just at the top.  Also, might be
better to resolve multi-byte characters first, in case that affects the
mini-language.")

      (item "More controls for terminal features can be added.")
      
      (item "Currently only implemented to work on Unix-like systems like
GNU/Linux.")

      (item "Implement text input controls, either as part of this library or
another, using "
            (racket charterm-demo)
            " as a starting point.")))

;; Note: Different ways to test demo:
;;
;;           racket -t demo.rkt -m
;; screen    racket -t demo.rkt -m
;; tmux -c  "racket -t demo.rkt -m"
;; xterm -e  racket -t demo.rkt -m
;; rxvt -e   racket -t demo.rkt -m
;; wy60 -c   racket -t demo.rkt -m
;;
;; racket -t demo.rkt -m- -n

;; TODO: Source for TeleVideo manuals:
;; http://www.mirrorservice.org/sites/www.bitsavers.org/pdf/televideo/

;; TODO: Add shifted function keys from T60 keyboard (not USB one).

(doc history

     (#:planet 3:1 #:date "2013-05-13"
               (itemlist
                (item "Now uses lowercase "
                      (code "-f")
                      " argument on MacOS X.  (Thanks to Jens Axel S\u00F8gaard for reporting.)")
                (item "Documentation tweaks.")))

     (#:planet 3:0 #:date "2012-07-13"
               (itemlist
                (item "Changed ``"
                      (code "ansi-ish")
                      "'' in identifiers to ``"
                      (code "ansi")
                      "'', hence the PLaneT major version number change.")
                (item "Documentation tweaks.")
                (item "Renamed package from ``"
                      (code "charterm")
                      "'' to ``CharTerm''.")))

     (#:planet 2:5 #:date "2012-06-28"
               (itemlist
                (item "A "
                      (racket charterm)
                      " object is now a synchronizable event.")
                (item "Documentation tweaks.")))
     
     (#:planet 2:4 #:date "2012-06-25"
               (itemlist
                (item "Documentation fix for return type of "
                      (racket charterm-read-keyinfo)
                      ".")))
     
     (#:planet 2:3 #:date "2012-06-25"
               (itemlist
                (item "Fixed problem determining screen size on some
XTerms.  (Thanks to Eli Barzilay for reporting.)")))

     (#:planet 2:2 #:date "2012-06-25"
               (itemlist
                (item "Added another variation of encoding for XTerm arrow,
Home, and End keys.  (Thanks to Eli Barzilay.)")))
     
     (#:planet 2:1 #:date "2012-06-24"
               (itemlist
                (item "Corrected PLaneT version number in "
                      (racket require)
                      " in an example.")))
     
     (#:planet 2:0 #:date "2012-06-24"
               (itemlist
                (item "Greatly increased the sophistication of handling of terminal diversity.")
                (item "Added the "
                      (code "wyse-wy50")
                      " and "
                      (code "televideo-950")
                      " [Correction: "
                      (code "televideo-925")
                      "] protocols, for supporting the native modes of Wyse and
TeleVideo terminals, respectively, and compatibles.")
                (item "More support for different key encodings and termvars.")
                (item "Demo is now in a separate file, mainly for convenience
in giving command lines that run it.  This breaks a command line example
previously documented, so changed PLaneT major version, although the
previously-published example will need to have "
                      (code ":1")
                      " added to it anyway.")
                (item (racket charterm-screen-size)
                      " now defaults to (80,24) when all else fails.")
                (item "Documentation changes.")))

     (#:planet 1:1 #:date "2012-06-17"
               (itemlist
                (item "For "
                      (code "screen")
                      " and "
                      (code "tmux")
                      ", now gets screen size via "
                      (code "stty")
                      ".  This resolves the sluggishness reported with "
                      (code "screen")
                      ".  [Correction: In version 1:1, this behavior is
adaptive for all terminals, with the shortcut for "
                      (tech "termvar")
                      " "
                      (code "screen")
                      " that it doesn't bother trying the control sequence.]")
                (item "Documentation tweaks.")))

     (#:planet 1:0 #:date "2012-06-16"
               (itemlist
                (item "Initial version."))))
