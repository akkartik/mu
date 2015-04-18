" Vim syntax file
" Language:    mu
" Maintainer:  Kartik Agaram <mu@akkartik.com>
" URL:         http://github.com/akkartik/mu
" License:     public domain
"
" Copy this into your ftplugin directory, and add the following to your vimrc:
"   autocmd BufReadPost,BufNewFile *.mu,*.test set filetype=mu

let s:save_cpo = &cpo
set cpo&vim

" todo: why does this periodically lose syntax, like on file reload?
"   $ vim x.mu
"   :e
"? if exists("b:syntax")
"?   finish
"? endif
"? let b:syntax = "mu"

setlocal iskeyword=@,48-57,?,!,_,$,-

syntax match muComment /#.*$/ | highlight link muComment Comment
syntax match muSalientComment /##.*$/ | highlight link muSalientComment SalientComment
syntax match muComment /;.*$/ | highlight link muComment Comment
syntax match muSalientComment /;;.*$/ | highlight link muSalientComment SalientComment
set comments+=n:#
syntax match CommentedCode "#? .*"
let b:cmt_head = "#? "

syntax region muString start=+"+ skip=+\\\\\|\\"+ end=+"+ contains=@Spell
highlight link muString String

syntax match muDelimiter "[{}\[\]]" | highlight link muDelimiter Delimiter
syntax match muLabel " [^a-zA-Z0-9 \[][a-zA-Z0-9-]\+" | highlight link muLabel Function
syntax match muAssign " <- " | highlight link muAssign SpecialChar
syntax match muAssign "\<raw\>"
syntax keyword muControl reply jump jump-if jump-unless loop loop-if loop-unless break-if break-unless | highlight link muControl Function
" common keywords
syntax keyword muFunc recipe default-space next-ingredient ingredient before after scenario run memory trace screen keyboard stalled finished | highlight link muFunc Statement

let &cpo = s:save_cpo
