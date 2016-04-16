" Vim syntax file
" Language:    mu
" Maintainer:  Kartik Agaram <mu@akkartik.com>
" URL:         http://github.com/akkartik/mu
" License:     public domain
"
" Copy this into your ftplugin directory, and add the following to your vimrc
" or to .vim/ftdetect/mu.vim:
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
setlocal formatoptions-=t  " mu programs have long lines
setlocal formatoptions+=c  " but comments should still wrap

syntax match muComment /#.*$/ | highlight link muComment Comment
syntax match muSalientComment /##.*$/ | highlight link muSalientComment SalientComment
syntax match muComment /;.*$/ | highlight link muComment Comment
syntax match muSalientComment /;;.*$/ | highlight link muSalientComment SalientComment
set comments+=n:#
syntax match CommentedCode "#? .*"
let b:cmt_head = "#? "

" mu strings are inside [ ... ] and can span multiple lines
" don't match '[' at end of line, that's usually code
syntax region muString start=+\[[^\]]+ end=+\]+
syntax match muString "\[\]"
highlight link muString String
" mu syntax for representing the screen in scenarios
syntax region muScreen start=+ \.+ end=+\.$\|$+
highlight link muScreen muString

" mu literals
syntax match muNumber %[^ ]\+:literal/\?[^ ,]*%
syntax match muNumber %\<[0-9-]\?[0-9]\+\>%
syntax match muNumber %\<[0-9-]\?[0-9]\+/[^ ,]*%
highlight link muNumber Constant
syntax match muLabel "^\s\+[^ 0-9a-zA-Z{}#\[\]][^ ]*\s*$"
syntax match muLabel %[^ ]\+:label/\?[^ ,]*%
syntax match muLabel "<[^ ]*>"
highlight link muLabel Constant
syntax match muLiteral %[^ ]\+:type/\?[^ ,]*%
syntax match muLiteral %[^ ]\+:offset/\?[^ ,]*%
syntax match muLiteral %[^ ]\+:variant/\?[^ ,]*%
highlight link muLiteral Constant
syntax keyword muKeyword default-space global-space new-default-space local-scope next-ingredient ingredient rewind-ingredients load-ingredients | highlight link muKeyword Constant

syntax match muDelimiter "[{}]" | highlight link muDelimiter Delimiter
syntax match muAssign " <- \|\<raw\>" | highlight link muAssign SpecialChar
syntax match muGlobal %[^ ]\+:global/\?[^ ,]*% | highlight link muGlobal SpecialChar
syntax keyword muControl reply reply-if reply-unless return return-if return-unless jump jump-if jump-unless loop loop-if loop-unless break break-if break-unless current-continuation continue-from create-delimited-continuation reply-delimited-continuation | highlight muControl ctermfg=3
" common keywords
syntax keyword muRecipe recipe recipe! def def! before after | highlight muRecipe ctermfg=208
syntax match muRecipe " -> "
syntax keyword muScenario scenario | highlight muScenario ctermfg=34
syntax keyword muData container exclusive-container | highlight muData ctermfg=226

let &cpo = s:save_cpo
