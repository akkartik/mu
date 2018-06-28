; https://www.muppetlabs.com/~breadbox/software/tiny/teensy.html
; nasm -f elf test3.s
; gcc -Wall -s -nostartfiles test3.o -o test3
BITS 32
EXTERN _exit
GLOBAL _start
SECTION .text
_start:
  push dword 42
  call _exit
