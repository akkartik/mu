#ifndef DESCRIPTORTABLES_H
#define DESCRIPTORTABLES_H

#include "common.h"

void initializeDescriptorTables();


struct GdtEntry
{
    uint16 limit_low;
    uint16 base_low;
    uint8  base_middle;
    uint8  access;
    uint8  granularity;
    uint8  base_high;
} __attribute__((packed));

typedef struct GdtEntry GdtEntry;


struct GdtPointer
{
    uint16 limit;
    uint32 base;
} __attribute__((packed));

typedef struct GdtPointer GdtPointer;


struct IdtEntry
{
    uint16 base_lo;
    uint16 sel;
    uint8  always0;
    uint8  flags;
    uint16 base_hi;
} __attribute__((packed));

typedef struct IdtEntry IdtEntry;


struct IdtPointer
{
    uint16 limit;
    uint32 base;
} __attribute__((packed));

typedef struct IdtPointer IdtPointer;

struct Tss {
    uint16 previous_task, __previous_task_unused;
    uint32 esp0;
    uint16 ss0, __ss0_unused;
    uint32 esp1;
    uint16 ss1, __ss1_unused;
    uint32 esp2;
    uint16 ss2, __ss2_unused;
    uint32 cr3;
    uint32 eip, eflags, eax, ecx, edx, ebx, esp, ebp, esi, edi;
    uint16 es, __es_unused;
    uint16 cs, __cs_unused;
    uint16 ss, __ss_unused;
    uint16 ds, __ds_unused;
    uint16 fs, __fs_unused;
    uint16 gs, __gs_unused;
    uint16 ldt_selector, __ldt_sel_unused;
    uint16 debug_flag, io_map;
} __attribute__ ((packed));

typedef struct Tss Tss;


extern void isr0 ();
extern void isr1 ();
extern void isr2 ();
extern void isr3 ();
extern void isr4 ();
extern void isr5 ();
extern void isr6 ();
extern void isr7 ();
extern void isr8 ();
extern void isr9 ();
extern void isr10();
extern void isr11();
extern void isr12();
extern void isr13();
extern void isr14();
extern void isr15();
extern void isr16();
extern void isr17();
extern void isr18();
extern void isr19();
extern void isr20();
extern void isr21();
extern void isr22();
extern void isr23();
extern void isr24();
extern void isr25();
extern void isr26();
extern void isr27();
extern void isr28();
extern void isr29();
extern void isr30();
extern void isr31();
extern void irq0 ();
extern void irq1 ();
extern void irq2 ();
extern void irq3 ();
extern void irq4 ();
extern void irq5 ();
extern void irq6 ();
extern void irq7 ();
extern void irq8 ();
extern void irq9 ();
extern void irq10();
extern void irq11();
extern void irq12();
extern void irq13();
extern void irq14();
extern void irq15();
extern void isr128();

#endif //DESCRIPTORTABLES_H
