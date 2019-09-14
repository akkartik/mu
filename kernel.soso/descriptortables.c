#include "screen.h"
#include "common.h"
#include "descriptortables.h"
#include "isr.h"
#include "process.h"

extern void flushGdt(uint32);
extern void flushIdt(uint32);
extern void flushTss();


static void initializeGdt();
static void initializeIdt();
static void setGdtEntry(int32 num, uint32 base, uint32 limit, uint8 access, uint8 gran);
static void setIdtEntry(uint8 num, uint32 base, uint16 sel, uint8 flags);

GdtEntry gGdtEntries[6];
GdtPointer   gGdtPointer;
IdtEntry gIdtEntries[256];
IdtPointer   gIdtPointer;
Tss 		gTss;

extern IsrFunction gInterruptHandlers[];

static void handleDoubleFault(Registers *regs);
static void handleGeneralProtectionFault(Registers *regs);

void initializeDescriptorTables()
{
    initializeGdt();

    initializeIdt();

    memset((uint8*)&gInterruptHandlers, 0, sizeof(IsrFunction)*256);

    registerInterruptHandler(8, handleDoubleFault);
    registerInterruptHandler(13, handleGeneralProtectionFault);
}

static void initializeGdt()
{
    gGdtPointer.limit = (sizeof(GdtEntry) * 6) - 1;
    gGdtPointer.base  = (uint32)&gGdtEntries;

    setGdtEntry(0, 0, 0, 0, 0);                // 0x00 Null segment
    setGdtEntry(1, 0, 0xFFFFFFFF, 0x9A, 0xCF); // 0x08 Code segment
    setGdtEntry(2, 0, 0xFFFFFFFF, 0x92, 0xCF); // 0x10 Data segment
    setGdtEntry(3, 0, 0xFFFFFFFF, 0xFA, 0xCF); // 0x18 User mode code segment
    setGdtEntry(4, 0, 0xFFFFFFFF, 0xF2, 0xCF); // 0x20 User mode data segment

    //TSS
    memset((uint8*)&gTss, 0, sizeof(gTss));
    gTss.debug_flag = 0x00;
    gTss.io_map = 0x00;
    gTss.esp0 = 0;//0x1FFF0;
    gTss.ss0 = 0x10;//0x18;

    gTss.cs   = 0x0B; //from ring 3 - 0x08 | 3 = 0x0B
    gTss.ss = gTss.ds = gTss.es = gTss.fs = gTss.gs = 0x13; //from ring 3 = 0x10 | 3 = 0x13
    uint32 tss_base = (uint32) &gTss;
    uint32 tss_limit = tss_base + sizeof(gTss);
    setGdtEntry(5, tss_base, tss_limit, 0xE9, 0x00);

    flushGdt((uint32)&gGdtPointer);
    flushTss();
}

// Set the value of one GDT entry.
static void setGdtEntry(int32 num, uint32 base, uint32 limit, uint8 access, uint8 gran)
{
    gGdtEntries[num].base_low    = (base & 0xFFFF);
    gGdtEntries[num].base_middle = (base >> 16) & 0xFF;
    gGdtEntries[num].base_high   = (base >> 24) & 0xFF;

    gGdtEntries[num].limit_low   = (limit & 0xFFFF);
    gGdtEntries[num].granularity = (limit >> 16) & 0x0F;
    
    gGdtEntries[num].granularity |= gran & 0xF0;
    gGdtEntries[num].access      = access;
}

void irqTimer();

static void initializeIdt()
{
    gIdtPointer.limit = sizeof(IdtEntry) * 256 -1;
    gIdtPointer.base  = (uint32)&gIdtEntries;

    memset((uint8*)&gIdtEntries, 0, sizeof(IdtEntry)*256);

    // Remap the irq table.
    outb(0x20, 0x11);
    outb(0xA0, 0x11);
    outb(0x21, 0x20);
    outb(0xA1, 0x28);
    outb(0x21, 0x04);
    outb(0xA1, 0x02);
    outb(0x21, 0x01);
    outb(0xA1, 0x01);
    outb(0x21, 0x0);
    outb(0xA1, 0x0);

    setIdtEntry( 0, (uint32)isr0 , 0x08, 0x8E);
    setIdtEntry( 1, (uint32)isr1 , 0x08, 0x8E);
    setIdtEntry( 2, (uint32)isr2 , 0x08, 0x8E);
    setIdtEntry( 3, (uint32)isr3 , 0x08, 0x8E);
    setIdtEntry( 4, (uint32)isr4 , 0x08, 0x8E);
    setIdtEntry( 5, (uint32)isr5 , 0x08, 0x8E);
    setIdtEntry( 6, (uint32)isr6 , 0x08, 0x8E);
    setIdtEntry( 7, (uint32)isr7 , 0x08, 0x8E);
    setIdtEntry( 8, (uint32)isr8 , 0x08, 0x8E);
    setIdtEntry( 9, (uint32)isr9 , 0x08, 0x8E);
    setIdtEntry(10, (uint32)isr10, 0x08, 0x8E);
    setIdtEntry(11, (uint32)isr11, 0x08, 0x8E);
    setIdtEntry(12, (uint32)isr12, 0x08, 0x8E);
    setIdtEntry(13, (uint32)isr13, 0x08, 0x8E);
    setIdtEntry(14, (uint32)isr14, 0x08, 0x8E);
    setIdtEntry(15, (uint32)isr15, 0x08, 0x8E);
    setIdtEntry(16, (uint32)isr16, 0x08, 0x8E);
    setIdtEntry(17, (uint32)isr17, 0x08, 0x8E);
    setIdtEntry(18, (uint32)isr18, 0x08, 0x8E);
    setIdtEntry(19, (uint32)isr19, 0x08, 0x8E);
    setIdtEntry(20, (uint32)isr20, 0x08, 0x8E);
    setIdtEntry(21, (uint32)isr21, 0x08, 0x8E);
    setIdtEntry(22, (uint32)isr22, 0x08, 0x8E);
    setIdtEntry(23, (uint32)isr23, 0x08, 0x8E);
    setIdtEntry(24, (uint32)isr24, 0x08, 0x8E);
    setIdtEntry(25, (uint32)isr25, 0x08, 0x8E);
    setIdtEntry(26, (uint32)isr26, 0x08, 0x8E);
    setIdtEntry(27, (uint32)isr27, 0x08, 0x8E);
    setIdtEntry(28, (uint32)isr28, 0x08, 0x8E);
    setIdtEntry(29, (uint32)isr29, 0x08, 0x8E);
    setIdtEntry(30, (uint32)isr30, 0x08, 0x8E);
    setIdtEntry(31, (uint32)isr31, 0x08, 0x8E);

    setIdtEntry(32, (uint32)irqTimer, 0x08, 0x8E);
    setIdtEntry(33, (uint32)irq1, 0x08, 0x8E);
    setIdtEntry(34, (uint32)irq2, 0x08, 0x8E);
    setIdtEntry(35, (uint32)irq3, 0x08, 0x8E);
    setIdtEntry(36, (uint32)irq4, 0x08, 0x8E);
    setIdtEntry(37, (uint32)irq5, 0x08, 0x8E);
    setIdtEntry(38, (uint32)irq6, 0x08, 0x8E);
    setIdtEntry(39, (uint32)irq7, 0x08, 0x8E);
    setIdtEntry(40, (uint32)irq8, 0x08, 0x8E);
    setIdtEntry(41, (uint32)irq9, 0x08, 0x8E);
    setIdtEntry(42, (uint32)irq10, 0x08, 0x8E);
    setIdtEntry(43, (uint32)irq11, 0x08, 0x8E);
    setIdtEntry(44, (uint32)irq12, 0x08, 0x8E);
    setIdtEntry(45, (uint32)irq13, 0x08, 0x8E);
    setIdtEntry(46, (uint32)irq14, 0x08, 0x8E);
    setIdtEntry(47, (uint32)irq15, 0x08, 0x8E);
    setIdtEntry(128, (uint32)isr128, 0x08, 0x8E);

    flushIdt((uint32)&gIdtPointer);
}

static void setIdtEntry(uint8 num, uint32 base, uint16 sel, uint8 flags)
{
    gIdtEntries[num].base_lo = base & 0xFFFF;
    gIdtEntries[num].base_hi = (base >> 16) & 0xFFFF;

    gIdtEntries[num].sel     = sel;
    gIdtEntries[num].always0 = 0;
    gIdtEntries[num].flags   = flags  | 0x60;
}

static void handleDoubleFault(Registers *regs)
{
    printkf("Double fault!!! Error code:%d\n", regs->errorCode);

    PANIC("Double fault!!!");
}

static void handleGeneralProtectionFault(Registers *regs)
{
    printkf("General protection fault!!! Error code:%d - IP:%x\n", regs->errorCode, regs->eip);

    Thread* faultingThread = getCurrentThread();
    if (NULL != faultingThread)
    {
        Thread* mainThread = getMainKernelThread();

        if (mainThread == faultingThread)
        {
            PANIC("General protection fault in Kernel main thread!!!");
        }
        else
        {
            printkf("Faulting thread is %d\n", faultingThread->threadId);

            if (faultingThread->userMode)
            {
                printkf("Destroying process %d\n", faultingThread->owner->pid);

                destroyProcess(faultingThread->owner);
            }
            else
            {
                printkf("Destroying kernel thread %d\n", faultingThread->threadId);

                destroyThread(faultingThread);
            }

            waitForSchedule();
        }
    }
    else
    {
        PANIC("General protection fault!!!");
    }
}
