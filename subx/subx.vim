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
set comments-=:#
set comments+=n:#
syntax match subxCommentedCode "#? .*"  | highlight link subxCommentedCode CommentedCode
let b:cmt_head = "#? "

" comment token
syntax match subxDelimiter / \. /  | highlight link subxDelimiter Delimiter

"" highlight low-level idioms in red as I provide more high-level replacements

" Once we have labels, highlight raw displacement
highlight Warn ctermbg=brown ctermfg=black
call matchadd("Warn", '\c^\s*e8.*\<\(0x\)\?[0-9a-f]\+/disp32')  " call
call matchadd("Warn", '\c^\s*e9.*\<\(0x\)\?[0-9a-f]\+/disp8')  " unconditional jump disp8
call matchadd("Warn", '\c^\s*7[45cdef].*\<\(0x\)\?[0-9a-f]\+/disp8')  " conditional jump disp8
call matchadd("Warn", '\c^\s*eb.*\<\(0x\)\?[0-9a-f]\+/disp16')  " unconditional jump disp16
call matchadd("Warn", '\c^\s*0f[^\s]*\s*8[45cdef].*\<\(0x\)\?[0-9a-f]\+/disp16')  " conditional jump disp16

let &cpo = s:save_cpo
