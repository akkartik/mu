" Vim syntax file
" Language:    mu
" Maintainer:  Kartik Agaram <mu@akkartik.com>
" URL:         http://github.com/akkartik/mu
" License:     public domain
"
" Copy this into your ftplugin directory, and add the following to your vimrc
" or to .vim/ftdetect/mu.vim:
"   autocmd BufReadPost,BufNewFile *.mu set filetype=mu

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

syntax match muComment /#.*$/  | highlight link muComment Comment
syntax match muSalientComment /##.*$/  | highlight link muSalientComment SalientComment
syntax match muComment /;.*$/  | highlight link muComment Comment
syntax match muSalientComment /;;.*$/  | highlight link muSalientComment SalientComment
set comments+=n:#
syntax match muCommentedCode "#? .*"  | highlight link muCommentedCode CommentedCode
let b:cmt_head = "#? "

syntax match muDelimiter "[{}]"  | highlight link muDelimiter Delimiter

" Mu strings are inside [ ... ] and can span multiple lines
" don't match '[' at end of line, that's usually code
syntax match muLiteral %^[^ a-zA-Z0-9(){}\[\]#$_*@&,=-][^ ,]*\|[ ,]\@<=[^ a-zA-Z0-9(){}\[\]#$_*@&,=-][^ ,]*%
syntax region muString start=+\[[^\]]+ end=+\]+
syntax match muString "\[\]"
highlight link muString String
" Mu syntax for representing the screen in scenarios
syntax region muScreen start=+ \.+ end=+\.$\|$+
highlight link muScreen muString

" Mu literals
syntax match muLiteral %[^ ]\+:literal/[^ ,]*\|[^ ]\+:literal\>%
syntax match muLiteral %\<[0-9-]\?[0-9]\+/[^ ,]*%
syntax match muLiteral % [0-9-]\?[0-9]\+[, ]\@=\| [0-9-]\?[0-9]\+$%
syntax match muLiteral "^\s\+[^ 0-9a-zA-Z{}$#\[\]][^ ]*\s*$"
" labels
syntax match muLiteral %[^ ]\+:label/[^ ,]*\|[^ ]\+:label\>%
" other literal types
syntax match muLiteral %[^ ]\+:type/[^ ,]*\|[^ ]\+:type\>%
syntax match muLiteral %[^ ]\+:offset/[^ ,]*\|[^ ]\+:offset\>%
syntax match muLiteral %[^ ]\+:variant/[^ ,]*\|[^ ]\+:variant\>%
syntax match muLiteral % true\(\/[^ ]*\)\?\| false\(\/[^ ]*\)\?%  " literals will never be the first word in an instruction
syntax match muLiteral % null\(\/[^ ]*\)\?%
highlight link muLiteral Constant

" sources of action at a distance
syntax match muAssign "<-"
syntax match muAssign "\<raw\>"
highlight link muAssign SpecialChar
syntax match muGlobal %[^ ]\+:global/\?[^ ,]*%  | highlight link muGlobal SpecialChar

" common keywords
" use regular expressions for common words that may come after '/'
syntax keyword muKeyword default-space local-scope
syntax keyword muKeyword next-input rewind-inputs load-inputs
syntax keyword muKeyword next-ingredient rewind-ingredients load-ingredients
syntax match muKeyword " input\>\| ingredient\>"
highlight link muKeyword Constant

syntax keyword muControl return return-if return-unless
syntax keyword muControl reply reply-if reply-unless
syntax keyword muControl output-if output-unless
syntax match muControl "^return\>\| return\>\|^reply\>\| reply\>\|^output\|^ output\>"
syntax keyword muControl jump-if jump-unless
syntax keyword muControl break-if break-unless
syntax keyword muControl loop-if loop-unless
syntax match muControl "^jump\>\| jump\>\|^break\>\| break\>\|^loop\>\| loop\>"
syntax keyword muControl start-running
syntax keyword muControl call-with-continuation-mark return-continuation-until-mark
highlight muControl ctermfg=3

syntax match muRecipe "->"
syntax match muRecipe "^recipe\>\|^def\>\|^before\>\|^after\>\| -> "
syntax keyword muRecipe recipe! def! function fn
highlight muRecipe ctermfg=208

syntax match muScenario "^scenario\>"  | highlight muScenario ctermfg=34
syntax keyword muPendingScenario pending-scenario  | highlight link muPendingScenario SpecialChar
syntax match muData "^type\>\|^container\>"
syntax keyword muData exclusive-container
highlight muData ctermfg=226

let &cpo = s:save_cpo
