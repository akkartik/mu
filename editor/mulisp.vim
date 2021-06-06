" Vim syntax file
" Language:    Mu Lisp
" Maintainer:  Kartik Agaram <mu@akkartik.com>
" URL:         http://github.com/akkartik/mu
" License:     public domain
"
" Copy this file into your ftplugin directory, and add the following to your
" vimrc or to .vim/ftdetect/mulisp.vim:
"   autocmd BufReadPost,BufNewFile *.limg set filetype=mulisp

let s:save_cpo = &cpo
set cpo&vim

setlocal iskeyword=@,48-57,?,!,_,$

" Hack: I define new syntax groups here, and I don't know how to distribute
" colorscheme-independent color suggestions for them.
highlight Normal ctermfg=245
highlight MuLispNormal ctermfg=0
highlight muLispKeyword ctermfg=2

syntax region String   start=+"+  skip=+\\"+  end=+"+

syntax region muLispNormal matchgroup=Normal start=/\[/ end=/\]/ contains=muLispLiteral,muLispComment,muLispDelimiter

syntax match muLispComment /#.*/ contained | highlight link muLispComment Comment
syntax match muLispLiteral /\<[0-9]\+\>/ contained | highlight link muLispLiteral Constant
syntax match muLispLiteral /\[[^\]]*\]/ contained
syntax match muLispDelimiter /[(),@`]/ contained | highlight link muLispDelimiter Delimiter

syntax keyword muLispKeyword globals sandbox

let &cpo = s:save_cpo
