#include "mouse.h"
#include "isr.h"
#include "common.h"
#include "device.h"
#include "alloc.h"
#include "devfs.h"
#include "list.h"
#include "fifobuffer.h"
#include "spinlock.h"

static void handleMouseInterrupt(Registers *regs);

static uint8 gMouseByteCounter = 0;

static void prepareForRead();
static void prepareForWrite();
static void writeMouse(uint8 data);
static void handleMouseInterrupt(Registers *regs);

static BOOL mouse_open(File *file, uint32 flags);
static void mouse_close(File *file);
static int32 mouse_read(File *file, uint32 size, uint8 *buffer);

#define MOUSE_PACKET_SIZE 3

uint8 gMousePacket[MOUSE_PACKET_SIZE];

static List* gReaders = NULL;

static Spinlock gReadersLock;

void initializeMouse()
{
    Device device;
    memset((uint8*)&device, 0, sizeof(Device));
    strcpy(device.name, "psaux");
    device.deviceType = FT_CharacterDevice;
    device.open = mouse_open;
    device.close = mouse_close;
    device.read = mouse_read;
    registerInterruptHandler(IRQ12, handleMouseInterrupt);

    registerDevice(&device);

    memset(gMousePacket, 0, MOUSE_PACKET_SIZE);

    gReaders = List_Create();

    Spinlock_Init(&gReadersLock);

    prepareForWrite();

    outb(0x64, 0x20); //get status command

    uint8 status = inb(0x60);
    status = status | 2; //enable IRQ12

    outb(0x64, 0x60); //set status command
    outb(0x60, status);

    outb(0x64, 0xA8); //enable Auxiliary Device command

    writeMouse(0xF4); //0xF4: Enable Packet Streaming
}

static BOOL mouse_open(File *file, uint32 flags)
{
    FifoBuffer* fifo = FifoBuffer_create(60);

    file->privateData = (void*)fifo;

    Spinlock_Lock(&gReadersLock);

    List_Append(gReaders, file);

    Spinlock_Unlock(&gReadersLock);

    return TRUE;
}

static void mouse_close(File *file)
{
    Spinlock_Lock(&gReadersLock);

    List_RemoveFirstOccurrence(gReaders, file);

    Spinlock_Unlock(&gReadersLock);

    FifoBuffer* fifo = (FifoBuffer*)file->privateData;

    FifoBuffer_destroy(fifo);
}

static int32 mouse_read(File *file, uint32 size, uint8 *buffer)
{
    FifoBuffer* fifo = (FifoBuffer*)file->privateData;

    while (FifoBuffer_getSize(fifo) < MOUSE_PACKET_SIZE)
    {
        file->thread->state = TS_WAITIO;
        file->thread->state_privateData = mouse_read;
        enableInterrupts();
        halt();
    }

    disableInterrupts();


    uint32 available = FifoBuffer_getSize(fifo);
    uint32 smaller = MIN(available, size);

    FifoBuffer_dequeue(fifo, buffer, smaller);

    return smaller;
}

static void prepareForRead()
{
    //https://wiki.osdev.org/Mouse_Input
    //Bytes cannot be read from port 0x60 until bit 0 (value=1) of port 0x64 is set

    int32 tryCount = 1000;

    uint8 data = 0;
    do
    {
        data = inb(0x64);
    } while (((data & 0x01) == 0) && --tryCount > 0);
}

static void prepareForWrite()
{
    //https://wiki.osdev.org/Mouse_Input
    //All output to port 0x60 or 0x64 must be preceded by waiting for bit 1 (value=2) of port 0x64 to become clear

    int32 tryCount = 1000;

    uint8 data = 0;
    do
    {
        data = inb(0x64);
    } while (((data & 0x02) != 0) && --tryCount > 0);
}

static void writeMouse(uint8 data)
{
    prepareForWrite();

    outb(0x64, 0xD4);

    prepareForWrite();

    outb(0x60, data);
}

static void handleMouseInterrupt(Registers *regs)
{
    uint8 status = 0;
    //0x20 (5th bit is mouse bit)
    //read from 0x64, if its mouse bit is 1 then data is available at 0x60!

    int32 tryCount = 1000;
    do
    {
        status = inb(0x64);
    } while (((status & 0x20) == 0) && --tryCount > 0);

    uint8 data = inb(0x60);

    gMousePacket[gMouseByteCounter] = data;

    gMouseByteCounter += 1;

    if (gMouseByteCounter == MOUSE_PACKET_SIZE)
    {
        gMouseByteCounter = 0;

        Spinlock_Lock(&gReadersLock);

        //Wake readers
        List_Foreach(n, gReaders)
        {
            File* file = n->data;

            FifoBuffer* fifo = (FifoBuffer*)file->privateData;

            FifoBuffer_enqueue(fifo, gMousePacket, MOUSE_PACKET_SIZE);

            if (file->thread->state == TS_WAITIO)
            {
                if (file->thread->state_privateData == mouse_read)
                {
                    file->thread->state = TS_RUN;
                    file->thread->state_privateData = NULL;
                }
            }
        }

        Spinlock_Unlock(&gReadersLock);
    }

    //printkf("mouse:%d\n", data);
}
