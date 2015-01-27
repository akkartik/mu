(require "charterm/main.rkt")
(require "terminal-color/terminal-color/main.rkt")
(open-charterm)
(charterm-clear-screen)
(charterm-cursor 5 5)
(displayln-color "Hello" #:fg 'green)  ; works
(charterm-cursor 25 5)
(displayln-color " Hello" #:fg 'green)  ; works
;? ;? (charterm-cursor 1 6) ;? 2
;? ;? (display-color "Hello" #:fg 'green)  ; err: cursor moves to start of line ;? 1
;? (charterm-newline)  ; doesn't work after display; somehow runs before it ;? 1
;? ;? (charterm-clear-line) ;? 3
;? (displayln-color "World" #:fg 'green) ;? 1
(close-charterm)
