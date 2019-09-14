#include "keyboard.h"
#include "isr.h"
#include "common.h"
#include "screen.h"
#include "ttydriver.h"
#include "fs.h"
#include "device.h"
#include "alloc.h"
#include "devfs.h"
#include "list.h"

static uint8* gKeyBuffer = NULL;
static uint32 gKeyBufferWriteIndex = 0;
static uint32 gKeyBufferReadIndex = 0;

#define KEYBUFFER_SIZE 128

static BOOL keyboard_open(File *file, uint32 flags);
static void keyboard_close(File *file);
static int32 keyboard_read(File *file, uint32 size, uint8 *buffer);
static int32 keyboard_ioctl(File *file, int32 request, void * argp);

typedef enum ReadMode
{
    Blocking = 0,
    NonBlocking = 1
} ReadMode;

typedef struct Reader
{
    uint32 readIndex;
    ReadMode readMode;
} Reader;

static List* gReaders = NULL;

static void handleKeyboardInterrupt(Registers *regs);

void initializeKeyboard()
{
    Device device;
    memset((uint8*)&device, 0, sizeof(Device));
    strcpy(device.name, "keyboard");
    device.deviceType = FT_CharacterDevice;
    device.open = keyboard_open;
    device.close = keyboard_close;
    device.read = keyboard_read;
    device.ioctl = keyboard_ioctl;

    gKeyBuffer = kmalloc(KEYBUFFER_SIZE);
    memset((uint8*)gKeyBuffer, 0, KEYBUFFER_SIZE);

    gReaders = List_Create();

    registerDevice(&device);

    registerInterruptHandler(IRQ1, handleKeyboardInterrupt);
}

static BOOL keyboard_open(File *file, uint32 flags)
{
    Reader* reader = (Reader*)kmalloc(sizeof(Reader));
    reader->readIndex = 0;
    reader->readMode = Blocking;

    if (gKeyBufferWriteIndex > 0)
    {
        reader->readIndex = gKeyBufferWriteIndex;
    }
    file->privateData = (void*)reader;

    List_Append(gReaders, file);

    return TRUE;
}

static void keyboard_close(File *file)
{
    //Screen_PrintF("keyboard_close\n");

    Reader* reader = (Reader*)file->privateData;

    kfree(reader);

    List_RemoveFirstOccurrence(gReaders, file);
}

static int32 keyboard_read(File *file, uint32 size, uint8 *buffer)
{
    Reader* reader = (Reader*)file->privateData;

    uint32 readIndex = reader->readIndex;

    if (reader->readMode == Blocking)
    {
        while (readIndex == gKeyBufferWriteIndex)
        {
            file->thread->state = TS_WAITIO;
            file->thread->state_privateData = keyboard_read;
            enableInterrupts();
            halt();
        }
    }

    disableInterrupts();

    if (readIndex == gKeyBufferWriteIndex)
    {
        //non-blocking return here
        return -1;
    }

    buffer[0] = gKeyBuffer[readIndex];
    readIndex++;
    readIndex %= KEYBUFFER_SIZE;

    reader->readIndex = readIndex;

    return 1;
}

static int32 keyboard_ioctl(File *file, int32 request, void * argp)
{
    Reader* reader = (Reader*)file->privateData;

    int cmd = (int)argp;

    switch (request)
    {
    case 0: //get
        *(int*)argp = (int)reader->readMode;
        return 0;
        break;
    case 1: //set
        if (cmd == 0)
        {
            reader->readMode = Blocking;

            return 0;
        }
        else if (cmd == 1)
        {
            reader->readMode = NonBlocking;
            return 0;
        }
        break;
    default:
        break;
    }

    return -1;
}

static void handleKeyboardInterrupt(Registers *regs)
{
    uint8 scancode = 0;
    do
    {
        scancode = inb(0x64);
    } while ((scancode & 0x01) == 0);

    scancode = inb(0x60);

    gKeyBuffer[gKeyBufferWriteIndex] = scancode;
    gKeyBufferWriteIndex++;
    gKeyBufferWriteIndex %= KEYBUFFER_SIZE;

    //Wake readers
    List_Foreach(n, gReaders)
    {
        File* file = n->data;

        if (file->thread->state == TS_WAITIO)
        {
            if (file->thread->state_privateData == keyboard_read)
            {
                file->thread->state = TS_RUN;
                file->thread->state_privateData = NULL;
            }
        }
    }

    sendKeyInputToTTY(getActiveTTY(), scancode);
}
