;;; Emacs major mode for editing SubX files. -*- coding: utf-8; lexical-binding: t; -*-

;; Author: Kartik Agaram (subx.el@akkartik.com)
;; Version: 0.0.1
;; Created: 28 Dec 2019
;; Keywords: languages
;; Homepage: https://github.com/akkartik/mu

;;; Commentary:

;; I don't know how to define new faces in an emacs package, so I'm
;; cannibalizing existing faces.
;;
;; I load this file like so in my .emacs:
;;    (load "/absolute/path/to/subx.el")
;;    (add-to-list 'auto-mode-alist '("\\.subx" . subx-mode))
;;
;; Education on the right way to do this most appreciated.

(setq subx-font-lock-keywords
  '(
    ; tests
    ("^test-[^ ]*:" . font-lock-type-face)
    ; functions
    ("^[a-z][^ ]*:" . font-lock-function-name-face)
    ; globals
    ("^[A-Z][^ ]*:" . font-lock-variable-name-face)
    ; minor labels
    ("^[^a-zA-Z#( ][^ ]*:" . font-lock-doc-face)
    ; string literals
    ; ("\"[^\"]*\"" . font-lock-constant-face)  ; strings colorized already, albeit buggily
    ; 4 colors for comments; ugly but functional
    ("# \\. \\. .*" . font-lock-doc-face)
    ("# \\. .*" . font-lock-constant-face)
    ("# - .*" . font-lock-comment-face)
    ("#.*" . font-lock-preprocessor-face)
    ))

(define-derived-mode subx-mode fundamental-mode "subx mode"
  "Major mode for editing SubX (Mu project)"
  (setq font-lock-defaults '((subx-font-lock-keywords)))
  )

(provide 'subx-mode)
