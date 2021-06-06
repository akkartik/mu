" SubX syntax file
" Language:    SubX
" Maintainer:  Kartik Agaram <mu@akkartik.com>
" URL:         https://github.com/akkartik/mu
" License:     public domain
"
" Copy this file into your ftplugin directory, and add the following to your
" vimrc or to .vim/ftdetect/subx.vim:
"   autocmd BufReadPost,BufNewFile *.subx set filetype=subx

" Some highlight groups you might want to select colors for in your vimrc:
highlight link CommentedCode Comment
highlight link SalientComment Comment
highlight link subxFunction Identifier
highlight link subxMinorFunction Identifier
highlight link subxTest Identifier
highlight link subxH1Comment Comment
highlight link subxComment Comment
highlight link subxS1Comment Comment
highlight link subxS2Comment Comment
" Some suggestions for 256-color terminals to add to your vimrc:
"   blue tones
"     highlight subxH1Comment cterm=underline ctermfg=27
"     highlight subxComment ctermfg=27
"     highlight subxS1Comment ctermfg=19
"     highlight subxS2Comment ctermfg=245
"   blue-green tones
"     highlight subxH1Comment cterm=underline ctermfg=25
"     highlight subxComment ctermfg=25
"     highlight subxS1Comment ctermfg=19
"     highlight subxS2Comment ctermfg=245
"   grey tones
"     highlight subxH1Comment cterm=bold,underline
"     highlight subxComment cterm=bold ctermfg=236
"     highlight subxS1Comment cterm=bold ctermfg=242
"     highlight subxS2Comment ctermfg=242

let s:save_cpo = &cpo
set cpo&vim

" setlocal iskeyword=@,48-57,?,!,_,$,-
setlocal formatoptions-=t  " allow long lines
setlocal formatoptions+=c  " but comments should still wrap

setlocal iskeyword+=-,?,<,>,$,@

syntax match subxH1Comment /# - .*/ | highlight link subxH1Comment Comment
syntax match subxComment /#\( \.\| - \|? \)\@!.*/ | highlight link subxComment Comment
syntax match subxS1Comment /# \..*/ | highlight link subxS1Comment Comment
syntax match subxS2Comment /# \. \..*/ | highlight link subxS2Comment Comment

set comments-=:#
set comments+=n:#
syntax match subxCommentedCode "#? .*"  | highlight link subxCommentedCode CommentedCode | highlight link CommentedCode Comment
let b:cmt_head = "#? "

" comment token
syntax match subxDelimiter / \. /  | highlight link subxDelimiter Normal

syntax match subxString %"[^"]*"% | highlight link subxString Constant

"" definitions
" match globals but not registers like 'EAX'
" don't match capitalized words in metadata
" don't match inside strings
syntax match subxGlobal %\(/\)\@<!\<[A-Z][a-z0-9_-]*\>% | highlight link subxGlobal SpecialChar

" functions but not tests, globals or internal functions
syntax match subxFunction "^\(test_\)\@<![a-z][^ ]*\(:\)\@=" | highlight link subxFunction Function
" tests starting with 'test-'; dark:34 light:64
syntax match subxTest "^test-[^ ]*\(:\)\@=" | highlight link subxTest Typedef
" internal functions starting with '_'
syntax match subxMinorFunction "^_[^ ]*\(:\)\@=" | highlight link subxMinorFunction Ignore
" other internal labels starting with '$'
syntax match subxLabel "^\$[^ ]*\(:\)\@=" | highlight link subxLabel Constant

syntax keyword subxControl break loop | highlight link subxControl Constant

let &cpo = s:save_cpo
