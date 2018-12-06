" SubX syntax file
" Language:    SubX
" Maintainer:  Kartik Agaram <mu@akkartik.com>
" URL:         https://github.com/akkartik/mu
" License:     public domain
"
" Copy this into your ftplugin directory, and add the following to your vimrc
" or to .vim/ftdetect/subx.vim:
"   autocmd BufReadPost,BufNewFile *.subx set filetype=subx

let s:save_cpo = &cpo
set cpo&vim

" setlocal iskeyword=@,48-57,?,!,_,$,-
setlocal formatoptions-=t  " allow long lines
setlocal formatoptions+=c  " but comments should still wrap

setlocal iskeyword+=-

"? syntax match subxComment /#.*$/  | highlight link subxComment Comment
"? syntax match subxSalientComment /##.*$/  | highlight link subxSalientComment SalientComment
syntax match subxH1Comment /# -.*/ | highlight subxH1Comment ctermfg=14
syntax match subxComment /#[^ ].*\|# [^.-].*\|# \?$/ | highlight subxComment ctermfg=39
syntax match subxS1Comment /# \..*/ | highlight subxS1Comment ctermfg=27
syntax match subxS2Comment /# \. \..*/ | highlight subxS2Comment ctermfg=19

set comments-=:#
set comments+=n:#
syntax match subxCommentedCode "#? .*"  | highlight link subxCommentedCode CommentedCode
let b:cmt_head = "#? "

" comment token
syntax match subxDelimiter / \. /  | highlight link subxDelimiter CommentedCode

syntax match subxString %"[^"]*"% | highlight link subxString Constant

"" definitions
" match globals but not registers like 'EAX'
" don't match capitalized words in metadata
" don't match inside strings
syntax match subxGlobal %\(/\)\@<!\<[A-Z][a-z0-9_-]*\>% | highlight link subxGlobal SpecialChar
" tweak the red color from the colorscheme just a tad to improve contrast
highlight SpecialChar ctermfg=196

" functions but not tests, globals or internal functions
syntax match subxFunction "^\(test_\)\@<![a-z][^ ]*\(:\)\@=" | highlight subxFunction ctermfg=208
" tests starting with 'test-'
syntax match subxTest "^test-[^ ]*\(:\)\@=" | highlight subxTest ctermfg=34
" internal functions starting with '_'
syntax match subxMinorFunction "^_[^ ]*\(:\)\@=" | highlight subxMinorFunction ctermfg=95
" other internal labels starting with '$'
syntax match subxLabel "^\$[^ ]*\(:\)\@=" | highlight link subxLabel Constant

let &cpo = s:save_cpo
