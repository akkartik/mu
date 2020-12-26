; A boot sector that enters 32-bit protected mode.
;
; To convert to a disk image:
;   cd apps/bos
;   nasm 4.asm -f bin -o boot.bin
; To run:
;   qemu-system-i386 boot.bin
; Or:
;   bochs  # bochsrc loads boot.bin

[org 0x7c00]

  mov bp, 0x9000
  mov sp, bp

  mov bx, MSG_REAL_MODE
  call print_string

  call switch_to_pm
  ; never gets here

  jmp $

switch_to_pm:
  cli
  lgdt [gdt_descriptor]
  ; set LSB of CR0
  mov eax, cr0
  or eax, 0x1
  mov cr0, eax
  jmp CODE_SEG:init_pm  ; Far jump to a new segment containing 32-bit code.
                        ; This also forces the CPU to flush its cache of
                        ; prefetched and real-mode decoded instructions.
  ; never gets here

;; === GDT stuff
gdt_start:

gdt_null:  ; the mandatory null descriptor
  dd 0x0  ; ’dd’ means define double word (i.e. 4 bytes)
  dd 0x0

gdt_code: ; the code segment descriptor
  ; base=0x0, limit=0xfffff,
  ; 1st flags: (present)1 (privilege)00 (descriptor type)1 -> 1001b
  ; type flags: (code)1 (conforming)0 (readable)1 (accessed )0 -> 1010b
  ; 2nd flags: (granularity)1 (32-bit default)1 (64-bit seg)0 (AVL)0 -> 1100b
  dw 0xffff     ; Limit (bits 0-15)
  dw 0x0        ; Base (bits 0-15)
  db 0x0        ; Base (bits 16 -23)
  db 10011010b  ; 1st flags, type flags
  db 11001111b  ; 2nd flags, Limit (bits 16-19)
  db 0x0        ; Base (bits 24 -31)

gdt_data: ; the  data segment descriptor
  ; Same as code segment except for the type flags:
  ; type flags: (code)0 (expand down)0 (writable)1 (accessed)0 -> 0010b
  dw 0xffff    ; Limit (bits 0-15)
  dw 0x0       ; Base (bits 0-15)
  db 0x0       ; Base (bits 16 -23)
  db 10010010b ; 1st flags, type flags
  db 11001111b ; 2nd flags, Limit (bits 16-19)
  db 0x0       ; Base (bits 24 -31)

gdt_end:

gdt_descriptor:
  dw gdt_end - gdt_start - 1  ; last valid byte
  dd gdt_start

; some handy constants
CODE_SEG equ gdt_code - gdt_start
DATA_SEG equ gdt_data - gdt_start
;; === end GDT stuff

;; some 16-bit helpers

; print string whose address is in bx
print_string:
  pusha
  mov ah, 0x0e
loop:
  mov al, [bx]
  int 0x10
  add bx, 1
  cmp al, 0
  jne loop
  popa
  ret

;; 32-bit code starts here
[bits  32]

; Initialise registers and the stack once in PM.
init_pm:

  mov ax, DATA_SEG        ; Now in PM, our old segments are meaningless,
  mov ds, ax              ; so we point our segment registers to the
  mov ss, ax              ; data selector we defined in our GDT
  mov es, ax
  mov fs, ax
  mov gs, ax

  mov ebp, 0x90000        ; Update our stack position so it is right
  mov esp, ebp            ; at the top of the free space.

  ;; Protected Mode is now initialized

  mov ebx, MSG_PROT_MODE
  call print_string_pm

  ; all done; hang
  jmp $

; Define  some  constants
VIDEO_MEMORY  equ 0xb8000
WHITE_ON_BLACK  equ 0x0f

; prints a null -terminated  string  pointed  to by EDX
print_string_pm:
  pusha
  mov edx, VIDEO_MEMORY  ; Set  edx to the  start  of vid  mem.
print_string_pm_loop:
  mov al, [ebx]          ; Store  the  char at EBX in AL
  mov ah, WHITE_ON_BLACK ; Store  the  attributes  in AH
  cmp al, 0         ; if (al == 0), at end of string , so
  je print_string_pm_done
  mov [edx], ax     ; Store  char  and  attributes  at  current
                    ; character  cell.
  add ebx , 1       ; Increment  EBX to the  next  char in  string.
  add edx , 2       ; Move to next  character  cell in vid  mem.
  jmp  print_string_pm_loop   ; loop  around  to  print  the  next  char.
print_string_pm_done:
  popa
  ret               ; Return  from  the  function

; Global variables
MSG_REAL_MODE   db "Started in 16-bit Real Mode", 0
MSG_PROT_MODE   db "Successfully landed in 32-bit Protected Mode", 0

; Bootsector padding
times 510-($-$$) db 0
dw 0xaa55
