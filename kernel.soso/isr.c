#include "common.h"
#include "isr.h"
#include "screen.h"

IsrFunction gInterruptHandlers[256];

extern uint32 gSystemTickCount;

void registerInterruptHandler(uint8 n, IsrFunction handler)
{
    gInterruptHandlers[n] = handler;
}

void handleISR(Registers regs)
{
    //Screen_PrintF("handleISR interrupt no:%d\n", regs.int_no);

    uint8 int_no = regs.interruptNumber & 0xFF;

    if (gInterruptHandlers[int_no] != 0)
    {
        IsrFunction handler = gInterruptHandlers[int_no];
        handler(&regs);
    }
    else
    {
        printkf("unhandled interrupt: %d\n", int_no);
        printkf("Tick: %d\n", gSystemTickCount);
        PANIC("unhandled interrupt");
    }
}

void handleIRQ(Registers regs)
{
    // end of interrupt message
    if (regs.interruptNumber >= 40)
    {
        //slave PIC
        outb(0xA0, 0x20);
    }

    outb(0x20, 0x20);

    //Screen_PrintF("irq: %d\n", regs.int_no);

    if (gInterruptHandlers[regs.interruptNumber] != 0)
    {
        IsrFunction handler = gInterruptHandlers[regs.interruptNumber];
        handler(&regs);
    }
}
