; https://www.muppetlabs.com/~breadbox/software/tiny/teensy.html
; nasm -f elf test2.s
; gcc -Wall -s test2.o -o test2
BITS 32
GLOBAL main
SECTION .text
main:
  mov eax, 42
  ret
