[GLOBAL flushGdt]

flushGdt:
    mov eax, [esp+4] ;[esp+4] is the parametered passed
    lgdt [eax]

    mov ax, 0x10  ;0x10 is the offset to our data segment
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    jmp 0x08:.flush ;0x08 is the offset to our code segment
.flush:
    ret

[GLOBAL flushIdt]

flushIdt:
    mov eax, [esp+4] ;[esp+4] is the parametered passed
    lidt [eax]
    ret

[GLOBAL flushTss]

flushTss:
    mov ax, 0x2B ;index of the TSS structure is 0x28 (5*8) and OR'ing two bits in order to set RPL 3 and we get 0x2B

    ltr ax
    ret
