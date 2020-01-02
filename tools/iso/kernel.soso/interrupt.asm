; NASM macro
%macro ISR_ERROR_CODE 1
  global isr%1
  isr%1:
    push dword %1         ; push the interrupt number
    jmp handleISRCommon
%endmacro

; NASM macro
%macro ISR_NO_ERROR_CODE 1
  global isr%1
  isr%1:
    push dword 0          ; push a dummy error code just because to keep struct Registers the same as the above macro
    push dword %1         ; push the interrupt number
    jmp handleISRCommon
%endmacro


; NASM macro
%macro IRQ 2
  global irq%1
  irq%1:
    push dword 0          ; push a dummy error code just because to keep struct Registers the same again
    push dword %2
    jmp handleIRQCommon
%endmacro
        
ISR_NO_ERROR_CODE  0
ISR_NO_ERROR_CODE  1
ISR_NO_ERROR_CODE  2
ISR_NO_ERROR_CODE  3
ISR_NO_ERROR_CODE  4
ISR_NO_ERROR_CODE  5
ISR_NO_ERROR_CODE  6
ISR_NO_ERROR_CODE  7
ISR_ERROR_CODE     8
ISR_NO_ERROR_CODE  9
ISR_ERROR_CODE     10
ISR_ERROR_CODE     11
ISR_ERROR_CODE     12
ISR_ERROR_CODE     13
ISR_ERROR_CODE     14
ISR_NO_ERROR_CODE  15
ISR_NO_ERROR_CODE  16
ISR_NO_ERROR_CODE  17
ISR_NO_ERROR_CODE  18
ISR_NO_ERROR_CODE  19
ISR_NO_ERROR_CODE  20
ISR_NO_ERROR_CODE  21
ISR_NO_ERROR_CODE  22
ISR_NO_ERROR_CODE  23
ISR_NO_ERROR_CODE  24
ISR_NO_ERROR_CODE  25
ISR_NO_ERROR_CODE  26
ISR_NO_ERROR_CODE  27
ISR_NO_ERROR_CODE  28
ISR_NO_ERROR_CODE  29
ISR_NO_ERROR_CODE  30
ISR_NO_ERROR_CODE  31
ISR_NO_ERROR_CODE  128

; IRQ0 is handled by irqTimer below

IRQ   1,    33
IRQ   2,    34
IRQ   3,    35
IRQ   4,    36
IRQ   5,    37
IRQ   6,    38
IRQ   7,    39
IRQ   8,    40
IRQ   9,    41
IRQ  10,    42
IRQ  11,    43
IRQ  12,    44
IRQ  13,    45
IRQ  14,    46
IRQ  15,    47

%macro	SAVE_REGS 0
        pushad
        push ds ;those registers are 16 bit but they are pushed as 32 bits here
        push es
        push fs
        push gs

        push ebx
        mov bx, 0x10 ; load the kernel data segment descriptor
        mov ds, bx
        mov es, bx
        mov fs, bx
        mov gs, bx
        pop ebx
%endmacro

%macro	RESTORE_REGS 0
        pop gs
        pop fs
        pop es
        pop ds
        popad
%endmacro


extern handleISR

handleISRCommon:
    SAVE_REGS
    call handleISR
    RESTORE_REGS
    add esp, 8     ; deallocate the error code and the interrupt number
    iret           ; pops CS, EIP, EFLAGS and also SS, and ESP if privilege change occurs

extern handleIRQ


handleIRQCommon:
    SAVE_REGS
    call handleIRQ
    RESTORE_REGS
    add esp, 8     ; deallocate the error code and the interrupt number
    iret           ; pops CS, EIP, EFLAGS and also SS, and ESP if privilege change occurs

extern handleTimerIRQ
global irqTimer
irqTimer:           ; this does not have int no and error code in the stack, so there is no "add esp, 8"
        SAVE_REGS
        call handleTimerIRQ
        mov al,0x20
        out 0x20,al
        RESTORE_REGS
        iret
        
