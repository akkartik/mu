; Example with a data segment.
; nasm -f elf test6-global.s
; gcc -Wall -s test6-global.o -o test6
BITS 32

SECTION .data
foo: dd 42

SECTION .text
GLOBAL main
main:
  mov eax, foo
  ret
