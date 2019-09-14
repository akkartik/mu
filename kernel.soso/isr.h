#ifndef ISR_H
#define ISR_H

#include "common.h"

#define IRQ0 32
#define IRQ1 33
#define IRQ2 34
#define IRQ3 35
#define IRQ4 36
#define IRQ5 37
#define IRQ6 38
#define IRQ7 39
#define IRQ8 40
#define IRQ9 41
#define IRQ10 42
#define IRQ11 43
#define IRQ12 44
#define IRQ13 45
#define IRQ14 46
#define IRQ15 47

typedef struct Registers
{
    uint32 gs;
    uint32 fs;
    uint32 es;
    uint32 ds;
    uint32 edi, esi, ebp, esp, ebx, edx, ecx, eax; //pushed by pusha
    uint32 interruptNumber, errorCode;             //if applicable
    uint32 eip, cs, eflags, userEsp, ss;           //pushed by the CPU
} Registers;

typedef void (*IsrFunction)(Registers*);
void registerInterruptHandler(uint8 n, IsrFunction handler);

#endif //ISR_H
