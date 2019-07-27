#lang setup/infotab

(define mcfly-planet       'neil/charterm:3:1)
(define name               "CharTerm")
(define mcfly-subtitle     "Character-cell Terminal Interface in Racket")
(define blurb              (list name ": Character-cell Terminal Interface"))
(define homepage           "http://www.neilvandyke.org/racket-charterm/")
(define mcfly-author       "Neil Van Dyke")
(define repositories       '("4.x"))
(define categories         '(misc))
(define can-be-loaded-with 'all)
(define scribblings        '(("doc.scrbl" () (library))))
(define primary-file       "main.rkt")
(define mcfly-start        "charterm.rkt")
(define mcfly-files        '(defaults
                              "charterm.rkt"
                              "demo.rkt"
                              "test-charterm.rkt"))
(define mcfly-license      "LGPLv3")

(define mcfly-legal
    "Copyright 2012 -- 2013 Neil Van Dyke.  This program is Free Software; you
can redistribute it and/or modify it under the terms of the GNU Lesser General
Public License as published by the Free Software Foundation; either version 3
of the License, or (at your option) any later version.  This program is
distributed in the hope that it will be useful, but without any warranty;
without even the implied warranty of merchantability or fitness for a
particular purpose.  See http://www.gnu.org/licenses/ for details.  For other
licenses and consulting, please contact the author.")
