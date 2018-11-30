" SubX syntax file
" Language:    SubX
" Maintainer:  Kartik Agaram <mu@akkartik.com>
" URL:         http://github.com/akkartik/mu
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

"? syntax match subxH1Comment /^# ===== .*/ | highlight subxH1Comment ctermfg=14
"? syntax match subxH2Comment /^# ==== .*/ | highlight subxH2Comment ctermfg=39
"? syntax match subxH3Comment /^# === .*/ | highlight subxH3Comment ctermfg=33
"? syntax match subxH4Comment /^# == .*/ | highlight subxH4Comment ctermfg=27
"? syntax match subxH5Comment /^# = .*/ | highlight subxH5Comment ctermfg=21
"? syntax match subxH6Comment /^# [^=].*/ | highlight subxH6Comment ctermfg=19

"? syntax match subxH1Comment /^# === .*/ | highlight subxH1Comment ctermfg=14
"? syntax match subxH2Comment /^# --- .*/ | highlight subxH2Comment ctermfg=39
"? syntax match subxComment /^# [^=-\.].*/ | highlight subxComment ctermfg=33
"? syntax match subxS1Comment /^# \. .*/ | highlight subxS1Comment ctermfg=27
"? syntax match subxS2Comment /^# \. \. .*/ | highlight subxS2Comment ctermfg=21
"? syntax match subxS3Comment /^# \. \. \. .*/ | highlight subxS3Comment ctermfg=19

"? syntax match subxH1Comment /^# =.*/ | highlight subxH1Comment ctermfg=14
"? syntax match subxH2Comment /^# -.*/ | highlight subxH2Comment ctermfg=39
"? syntax match subxComment /^#[^ ].*\|# [^ .=-].*\|# \?$/ | highlight subxComment ctermfg=27
"? syntax match subxS1Comment /^# \..*/ | highlight subxS1Comment ctermfg=21
"? syntax match subxS2Comment /^# \. \..*/ | highlight subxS2Comment ctermfg=19
"? syntax match subxS3Comment /^# \. \. \..*/ | highlight subxS3Comment ctermfg=18

syntax match subxH1Comment /# =.*/ | highlight subxH1Comment ctermfg=14
syntax match subxH2Comment /# -.*/ | highlight subxH2Comment ctermfg=39
syntax match subxComment /#[^ ].*\|# [^.=-].*\|# \?$/ | highlight subxComment ctermfg=27
syntax match subxS1Comment /# \..*/ | highlight subxS1Comment ctermfg=19

"? syntax match subxH2Comment /^# --- .*/ | highlight subxH2Comment ctermfg=33
"? syntax match subxH3Comment /^# --- .*/ | highlight subxH3Comment ctermfg=21
"? syntax match subxComment /#.*$/  | highlight link subxComment Comment
"? syntax match subxSalientComment /##.*$/  | highlight link subxSalientComment SalientComment
set comments-=:#
set comments+=n:#
syntax match subxCommentedCode "#? .*"  | highlight link subxCommentedCode CommentedCode
let b:cmt_head = "#? "

" comment token
syntax match subxDelimiter / \. /  | highlight link subxDelimiter CommentedCode

syntax match subxString %"[^"]*"% | highlight link subxString Constant
" match globals but not registers like 'EAX'
syntax match subxGlobal %\<[A-Z][a-z0-9_-]*\>% | highlight link subxGlobal SpecialChar

let &cpo = s:save_cpo
