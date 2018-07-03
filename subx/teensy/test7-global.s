; https://www.muppetlabs.com/~breadbox/software/tiny/teensy.html
; nasm -f bin test7-global.s -o test7
; chmod +x test7
BITS 32

              org     0x08048000

ehdr:                                                 ; Elf32_Ehdr
              db      0x7F, "ELF", 1, 1, 1, 0         ;   e_ident
      times 8 db      0
              dw      2                               ;   e_type
              dw      3                               ;   e_machine
              dd      1                               ;   e_version
              dd      _start                          ;   e_entry
              dd      phdr1 - $$                      ;   e_phoff
              dd      0                               ;   e_shoff
              dd      0                               ;   e_flags
              dw      ehdrsize                        ;   e_ehsize
              dw      phdrsize                        ;   e_phentsize
              dw      2                               ;   e_phnum
              dw      0                               ;   e_shentsize
              dw      0                               ;   e_shnum
              dw      0                               ;   e_shstrndx
ehdrsize  equ  $ - ehdr

phdr1:                                                ; Elf32_Phdr
              dd      1                               ;   p_type
              dd      0                               ;   p_offset
              dd      $$                              ;   p_vaddr
              dd      $$                              ;   p_paddr
              dd      codesize                        ;   p_filesz
              dd      codesize                        ;   p_memsz
              dd      5                               ;   p_flags = r-x
              dd      0x1000                          ;   p_align
phdrsize  equ  $ - phdr1

phdr2:
              dd      1                               ;   p_type
              dd      _data - $$                      ;   p_offset
              dd      _data                           ;   p_vaddr
              dd      _data                           ;   p_paddr
              dd      datasize                        ;   p_filesz
              dd      datasize                        ;   p_memsz
              dd      6                               ;   p_flags = rw-
              dd      0x1000                          ;   p_align

_start:
  mov ebx, [foo]
  mov eax, 1
  int 0x80

codesize      equ     $ - $$  ; TODO: why include the headers?!

alignb 0x1000
_data:
  foo:        dd      42

datasize      equ     $ - _data
