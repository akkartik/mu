; https://www.muppetlabs.com/~breadbox/software/tiny/teensy.html
; nasm -f bin test5.s -o test5
; chmod +x test5
BITS 32

              org     0x08048000

ehdr:                                                 ; Elf32_Ehdr
              db      0x7F, "ELF", 1, 1, 1, 0         ;   e_ident
      times 8 db      0
              dw      2                               ;   e_type
              dw      3                               ;   e_machine
              dd      1                               ;   e_version
              dd      _start                          ;   e_entry
              dd      phdr - $$                       ;   e_phoff
              dd      0                               ;   e_shoff
              dd      0                               ;   e_flags
              dw      ehdrsize                        ;   e_ehsize
              dw      phdrsize                        ;   e_phentsize
              dw      1                               ;   e_phnum
              dw      0                               ;   e_shentsize
              dw      0                               ;   e_shnum
              dw      0                               ;   e_shstrndx
ehdrsize  equ  $ - ehdr

phdr:                                                 ; Elf32_Phdr
              dd      1                               ;   p_type
              # don't copy ehdr or phdr into the first segment.
              dd      0x54                            ;   p_offset
              # but you can't save on bytes for them, because p_align.
              # messing with the ORG won't help you here.
              dd      0x08048054                      ;   p_vaddr
              dd      0x08048054                      ;   p_paddr
              dd      codesize                        ;   p_filesz
              dd      codesize                        ;   p_memsz
              dd      5                               ;   p_flags
              dd      0x1000                          ;   p_align
phdrsize  equ  $ - phdr

_start:
  mov ebx, 42
  mov eax, 1
  int 0x80

codesize      equ     $ - _start
