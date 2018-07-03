; https://www.muppetlabs.com/~breadbox/software/tiny/teensy.html
; nasm -f elf test4.s
; gcc -Wall -s -nostdlib test4.o -o test4
BITS 32
GLOBAL _start
SECTION .text
_start:
  mov ebx, 42
  mov eax, 1
  int 0x80
