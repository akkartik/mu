" Vim syntax file
" Language:    mu
" Maintainer:  Kartik Agaram <mu@akkartik.com>
" URL:         http://github.com/akkartik/mu
" License:     public domain
"
" Copy this file into your ftplugin directory, and add the following to your
" vimrc or to .vim/ftdetect/mu.vim:
"   autocmd BufReadPost,BufNewFile *.mu set filetype=mu
"
" Some highlight groups you might want to select colors for in your vimrc:
"   muFunction
"   muTest

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
setlocal formatoptions-=t  " Mu programs have long lines
setlocal formatoptions+=c  " but comments should still wrap

syntax match muSalientComment /##.*$/  | highlight link muSalientComment SalientComment
syntax match muComment /#\( \.\|? \)\@!.*/ | highlight link muComment Comment
syntax match muS1Comment /# \..*/ | highlight link muS1Comment Comment
syntax match muS2Comment /# \. \..*/ | highlight link muS2Comment Comment

set comments+=n:#
syntax match muCommentedCode "#? .*"  | highlight link muCommentedCode CommentedCode
let b:cmt_head = "#? "

syntax match muDelimiter "[{}]"  | highlight link muDelimiter Delimiter

" Mu literals
syntax match muLiteral %\<-\?[0-9][0-9A-Fa-f]*\>%
syntax match muLiteral %\<-\?0x[0-9A-Fa-f]\+\>%
syntax match muLiteral %"[^"]*"%
highlight link muLiteral Constant
syntax match muError %\<[0-9][0-9A-Fa-f]*[^0-9A-Fa-f]\>%
highlight link muError Error

" sources of action at a distance
syntax match muAssign "<-"
highlight link muAssign SpecialChar
syntax keyword muAssign error error-stream
highlight link muAssign Special

" common keywords
syntax match muControl "\<return\>\|\<return-if[^ ]*\>"
syntax match muControl "\<jump\>\|\<jump-if[^ ]*"
syntax match muControl "\<break\>\|\<break-if[^ ]*"
syntax match muControl "\<loop\>\|\<loop-if[^ ]*"
highlight link muControl PreProc

syntax match muKeyword " -> "
syntax keyword muKeyword fn sig type var
highlight link muKeyword PreProc

syntax match muFunction "\(fn\s\+\)\@<=\(\S\+\)"
highlight link muFunction Identifier

syntax match muTest "\(fn\s\+\)\@<=\(test-\S\+\)"
highlight link muTest Identifier

syntax match muData "^type\>"
syntax match muData "\<xmm[0-7]\>"
highlight link muData Constant

" Some hacky colors
" TODO: This should really be theme-dependent.
syntax match muRegEax "\<eax\>"
highlight muRegEax ctermfg=94
syntax match muRegEcx "\<ecx\>"
highlight muRegEcx ctermfg=137
syntax match muRegEdx "\<edx\>"
highlight muRegEdx ctermfg=100
syntax match muRegEbx "\<ebx\>"
highlight muRegEbx ctermfg=103
syntax match muRegEsi "\<esi\>"
highlight muRegEsi ctermfg=114
syntax match muRegEdi "\<edi\>"
highlight muRegEdi ctermfg=122

let &cpo = s:save_cpo
