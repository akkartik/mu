[GLOBAL readEip]
readEip:
    pop eax
    jmp eax

[GLOBAL disablePaging]
disablePaging:
    mov edx, cr0
    and edx, 0x7fffffff
    mov cr0, edx
    ret

[GLOBAL enablePaging]
enablePaging:
    mov edx, cr0
    or edx, 0x80000000
    mov cr0, edx
    ret
