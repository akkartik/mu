; To convert to a disk image:
;   cd apps/bos
;   nasm 4.asm -f bin -o boot.bin
; To run:
;   qemu-system-i386 boot.bin
; Or:
;   bochs  # bochsrc loads boot.bin
#
# Expected output inside emulator:
#   Started in 16-bit Real Mode
#   Successfully landed in 32-bit Protected Mode
# Look for the second line at the top of the emulated screen.

; A boot sector that enters 32-bit protected mode.
[org 0x7c00]

  mov bp, 0x9000          ; Set the stack.
  mov sp, bp

  mov bx, MSG_REAL_MODE
  call print_string

  call switch_to_pm      ; Note that we never return from here.

  jmp $

%include "print_string.asm"
%include "gdt.asm"
%include "print_string_pm.asm"
%include "switch_to_pm.asm"

[bits 32]
; This is where we arrive after switching to and initialising protected mode.
BEGIN_PM:

  mov ebx, MSG_PROT_MODE
  call print_string_pm    ; Use our 32-bit print routine.

  jmp $                      ; Hang.

; Global variables
MSG_REAL_MODE   db "Started in 16-bit Real Mode", 0
MSG_PROT_MODE   db "Successfully landed in 32-bit Protected Mode", 0
; Bootsector padding
times 510-($-$$) db 0
dw 0xaa55
