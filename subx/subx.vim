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

syntax match subxComment /#.*$/  | highlight link subxComment Comment
syntax match subxSalientComment /##.*$/  | highlight link subxSalientComment SalientComment
set comments+=n:#
syntax match subxCommentedCode "#? .*"  | highlight link subxCommentedCode CommentedCode
let b:cmt_head = "#? "
