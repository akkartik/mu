#include "ttydriver.h"
#include "device.h"
#include "screen.h"
#include "serial.h"
#include "devfs.h"
#include "alloc.h"
#include "common.h"
#include "list.h"
#include "fifobuffer.h"
#include "gfx.h"
#include "debugprint.h"
#include "commonuser.h"
#include "termios.h"

static List* gTtyList = NULL;

static List* gReaderList = NULL;

static Tty* gActiveTty = NULL;

static uint8 gKeyModifier = 0;

static uint32 gPseudoTerminalNameGenerator = 0;

typedef enum KeyModifier
{
    KM_LeftShift = 1,
    KM_RightShift = 2,
    KM_Ctrl = 4,
    KM_Alt = 8
} KeyModifier;

enum
{
    KEY_LEFTSHIFT = 0x2A,
    KEY_RIGHTSHIFT = 0x36,
    KEY_CTRL = 0x1D,
    KEY_ALT = 0x38,
    KEY_CAPSLOCK = 0x3A,
    KEY_F1 = 0x3B,
    KEY_F2 = 0x3C,
    KEY_F3 = 0x3D
};

// PC keyboard interface constants

#define KBSTATP         0x64    // kbd controller status port(I)
#define KBS_DIB         0x01    // kbd data in buffer
#define KBDATAP         0x60    // kbd data port(I)

#define NO              0

#define SHIFT           (1<<0)
#define CTL             (1<<1)
#define ALT             (1<<2)

#define CAPSLOCK        (1<<3)
#define NUMLOCK         (1<<4)
#define SCROLLLOCK      (1<<5)

#define E0ESC           (1<<6)

// Special keycodes
#define KEY_HOME        0xE0
#define KEY_END         0xE1
#define KEY_UP          0xE2
#define KEY_DOWN        0xE3
#define KEY_LEFT        0xE4
#define KEY_RIGHT       0xE5
#define KEY_PAGEUP      0xE6
#define KEY_PAGEDOWN    0xE7
#define KEY_INSERT      0xE8
#define KEY_DELETE      0xE9

// C('A') == Control-A
#define C(x) (x - '@')




static uint8 gKeyMap[256] =
{
  NO,   0x1B, '1',  '2',  '3',  '4',  '5',  '6',  // 0x00
  '7',  '8',  '9',  '0',  '-',  '=',  '\b', '\t',
  'q',  'w',  'e',  'r',  't',  'y',  'u',  'i',  // 0x10
  'o',  'p',  '[',  ']',  '\n', NO,   'a',  's',
  'd',  'f',  'g',  'h',  'j',  'k',  'l',  ';',  // 0x20
  '\'', '`',  NO,   '\\', 'z',  'x',  'c',  'v',
  'b',  'n',  'm',  ',',  '.',  '/',  NO,   '*',  // 0x30
  NO,   ' ',  NO,   NO,   NO,   NO,   NO,   NO,
  NO,   NO,   NO,   NO,   NO,   NO,   NO,   '7',  // 0x40
  '8',  '9',  '-',  '4',  '5',  '6',  '+',  '1',
  '2',  '3',  '0',  '.',  NO,   NO,   NO,   NO,   // 0x50
  [0x49] = KEY_PAGEUP,
  [0x51] = KEY_PAGEDOWN,
  [0x47] = KEY_HOME,
  [0x4F] = KEY_END,
  [0x52] = KEY_INSERT,
  [0x53] = KEY_DELETE,
  [0x48] = KEY_UP,
  [0x50] = KEY_DOWN,
  [0x4B] = KEY_LEFT,
  [0x4D] = KEY_RIGHT,
  [0x9C] = '\n',      // KP_Enter
  [0xB5] = '/',       // KP_Div
  [0xC8] = KEY_UP,
  [0xD0] = KEY_DOWN,
  [0xC9] = KEY_PAGEUP,
  [0xD1] = KEY_PAGEDOWN,
  [0xCB] = KEY_LEFT,
  [0xCD] = KEY_RIGHT,
  [0x97] = KEY_HOME,
  [0xCF] = KEY_END,
  [0xD2] = KEY_INSERT,
  [0xD3] = KEY_DELETE
};

static uint8 gKeyShiftMap[256] =
{
  NO,   033,  '!',  '@',  '#',  '$',  '%',  '^',  // 0x00
  '&',  '*',  '(',  ')',  '_',  '+',  '\b', '\t',
  'Q',  'W',  'E',  'R',  'T',  'Y',  'U',  'I',  // 0x10
  'O',  'P',  '{',  '}',  '\n', NO,   'A',  'S',
  'D',  'F',  'G',  'H',  'J',  'K',  'L',  ':',  // 0x20
  '"',  '~',  NO,   '|',  'Z',  'X',  'C',  'V',
  'B',  'N',  'M',  '<',  '>',  '?',  NO,   '*',  // 0x30
  NO,   ' ',  NO,   NO,   NO,   NO,   NO,   NO,
  NO,   NO,   NO,   NO,   NO,   NO,   NO,   '7',  // 0x40
  '8',  '9',  '-',  '4',  '5',  '6',  '+',  '1',
  '2',  '3',  '0',  '.',  NO,   NO,   NO,   NO,   // 0x50
  [0x49] = KEY_PAGEUP,
  [0x51] = KEY_PAGEDOWN,
  [0x47] = KEY_HOME,
  [0x4F] = KEY_END,
  [0x52] = KEY_INSERT,
  [0x53] = KEY_DELETE,
  [0x48] = KEY_UP,
  [0x50] = KEY_DOWN,
  [0x4B] = KEY_LEFT,
  [0x4D] = KEY_RIGHT,
  [0x9C] = '\n',      // KP_Enter
  [0xB5] = '/',       // KP_Div
  [0xC8] = KEY_UP,
  [0xD0] = KEY_DOWN,
  [0xC9] = KEY_PAGEUP,
  [0xD1] = KEY_PAGEDOWN,
  [0xCB] = KEY_LEFT,
  [0xCD] = KEY_RIGHT,
  [0x97] = KEY_HOME,
  [0xCF] = KEY_END,
  [0xD2] = KEY_INSERT,
  [0xD3] = KEY_DELETE
};

static BOOL tty_open(File *file, uint32 flags);
static void tty_close(File *file);
static int32 tty_ioctl(File *file, int32 request, void * argp);
static int32 tty_read(File *file, uint32 size, uint8 *buffer);
static int32 tty_write(File *file, uint32 size, uint8 *buffer);
static int32 write(Tty* tty, uint32 size, uint8 *buffer);

static uint8 getCharacterForScancode(KeyModifier modifier, uint8 scancode);
static void processScancode(uint8 scancode);

void initializeTTYs(BOOL graphicMode)
{
    gTtyList = List_Create();

    gReaderList = List_Create();

    for (int i = 1; i <= 9; ++i)
    {
        Tty* tty = NULL;
        if (graphicMode)
        {
            tty = createTty(768 / 16, 1024 / 9, Gfx_FlushFromTty);
        }
        else
        {
            tty = createTty(25, 80, Screen_FlushFromTty);
        }

        tty->color = 0x0A;

        List_Append(gTtyList, tty);

        Device device;
        memset((uint8*)&device, 0, sizeof(Device));
        sprintf(device.name, "tty%d", i);
        device.deviceType = FT_CharacterDevice;
        device.open = tty_open;
        device.close = tty_close;
        device.ioctl = tty_ioctl;
        device.read = tty_read;
        device.write = tty_write;
        device.privateData = tty;
        registerDevice(&device);
    }

    gActiveTty = List_GetFirstNode(gTtyList)->data;
}

Tty* getActiveTTY()
{
    return gActiveTty;
}

FileSystemNode* createPseudoTerminal()
{
    Tty* tty = createTty(768 / 16, 1024 / 9, Gfx_FlushFromTty);

    tty->color = 0x0A;

    Device device;
    memset((uint8*)&device, 0, sizeof(Device));
    sprintf(device.name, "pts%d", gPseudoTerminalNameGenerator++);
    device.deviceType = FT_CharacterDevice;
    device.open = tty_open;
    device.close = tty_close;
    device.ioctl = tty_ioctl;
    device.read = tty_read;
    device.write = tty_write;
    device.privateData = tty;
    FileSystemNode* node = registerDevice(&device);
    if (NULL == node)
    {
        destroyTty(tty);
    }

    return node;
}

static void sendInputToKeyBuffer(Tty* tty, uint8 scancode, uint8 character)
{
    char seq[8];
    memset(seq, 0, 8);

    switch (character) {
    case KEY_PAGEUP:
    {
        seq[0] = 27;
        seq[1] = 91;
        seq[2] = 53;
        seq[3] = 126;
        FifoBuffer_enqueue(tty->keyBuffer, seq, 4);
    }
        break;
    case KEY_PAGEDOWN:
    {
        seq[0] = 27;
        seq[1] = 91;
        seq[2] = 54;
        seq[3] = 126;
        FifoBuffer_enqueue(tty->keyBuffer, seq, 4);
    }
        break;
    case KEY_HOME:
    {
        seq[0] = 27;
        seq[1] = 91;
        seq[2] = 72;
        FifoBuffer_enqueue(tty->keyBuffer, seq, 3);
    }
        break;
    case KEY_END:
    {
        seq[0] = 27;
        seq[1] = 91;
        seq[2] = 70;
        FifoBuffer_enqueue(tty->keyBuffer, seq, 3);
    }
        break;
    case KEY_INSERT:
    {
        seq[0] = 27;
        seq[1] = 91;
        seq[2] = 50;
        seq[3] = 126;
        FifoBuffer_enqueue(tty->keyBuffer, seq, 4);
    }
        break;
    case KEY_DELETE:
    {
        seq[0] = 27;
        seq[1] = 91;
        seq[2] = 51;
        seq[3] = 126;
        FifoBuffer_enqueue(tty->keyBuffer, seq, 4);
    }
        break;
    case KEY_UP:
    {
        seq[0] = 27;
        seq[1] = 91;
        seq[2] = 65;
        FifoBuffer_enqueue(tty->keyBuffer, seq, 3);
    }
        break;
    case KEY_DOWN:
    {
        seq[0] = 27;
        seq[1] = 91;
        seq[2] = 66;
        FifoBuffer_enqueue(tty->keyBuffer, seq, 3);
    }
        break;
    case KEY_RIGHT:
    {
        seq[0] = 27;
        seq[1] = 91;
        seq[2] = 67;
        FifoBuffer_enqueue(tty->keyBuffer, seq, 3);
    }
        break;
    case KEY_LEFT:
    {
        seq[0] = 27;
        seq[1] = 91;
        seq[2] = 68;
        FifoBuffer_enqueue(tty->keyBuffer, seq, 3);
    }
        break;
    default:
        FifoBuffer_enqueue(tty->keyBuffer, &character, 1);
        break;
    }
}

void sendKeyInputToTTY(Tty* tty, uint8 scancode)
{
    beginCriticalSection();

    processScancode(scancode);

    uint8 character = getCharacterForScancode(gKeyModifier, scancode);

    uint8 keyRelease = (0x80 & scancode); //ignore release event

    if (character > 0 && keyRelease == 0)
    {
        //enqueue for non-canonical readers
        sendInputToKeyBuffer(tty, scancode, character);
        //FifoBuffer_enqueue(tty->keyBuffer, &scancode, 1);

        if (tty->lineBufferIndex >= TTY_LINEBUFFER_SIZE - 1)
        {
            tty->lineBufferIndex = 0;
        }

        if (character == '\b')
        {
            if (tty->lineBufferIndex > 0)
            {
                tty->lineBuffer[--tty->lineBufferIndex] = '\0';

                if ((tty->term.c_lflag & ECHO) == ECHO)
                {
                    write(tty, 1, &character);
                }
            }
        }
        else
        {
            tty->lineBuffer[tty->lineBufferIndex++] = character;

            if ((tty->term.c_lflag & ECHO) == ECHO)
            {
                write(tty, 1, &character);
            }
        }
    }

    //Wake readers
    List_Foreach(n, gReaderList)
    {
        File* file = n->data;

        if (file->thread->state == TS_WAITIO)
        {
            if (file->thread->state_privateData == tty)
            {
                file->thread->state = TS_RUN;
                file->thread->state_privateData = NULL;
            }
        }
    }

    endCriticalSection();
}

static BOOL tty_open(File *file, uint32 flags)
{
    //Screen_PrintF("tty_open: pid:%d\n", file->process->pid);

    Tty* tty = (Tty*)file->node->privateNodeData;

    FifoBuffer_clear(tty->keyBuffer);

    List_Append(gReaderList, file);

    return TRUE;
}

static void tty_close(File *file)
{
    List_RemoveFirstOccurrence(gReaderList, file);
}

static int32 tty_ioctl(File *file, int32 request, void * argp)
{
    Tty* tty = (Tty*)file->node->privateNodeData;

    switch (request)
    {
    case 0:
    {
        sendKeyInputToTTY(tty, (uint8)(uint32)argp);

        return 0;
    }
        break;
    case 1:
        return tty->columnCount * tty->lineCount * 2;
        break;
    case 2:
    {
        //set
        TtyUserBuffer* userTtyBuffer = (TtyUserBuffer*)argp;
        memcpy(tty->buffer, (uint8*)userTtyBuffer->buffer, tty->columnCount * tty->lineCount * 2);
        return 0;
    }
        break;
    case 3:
    {
        //get
        TtyUserBuffer* userTtyBuffer = (TtyUserBuffer*)argp;
        userTtyBuffer->columnCount = tty->columnCount;
        userTtyBuffer->lineCount = tty->lineCount;
        userTtyBuffer->currentColumn = tty->currentColumn;
        userTtyBuffer->currentLine = tty->currentLine;
        memcpy((uint8*)userTtyBuffer->buffer, tty->buffer, tty->columnCount * tty->lineCount * 2);
        return 0;
    }
        break;
    case TCGETS:
    {
        struct termios* term = (struct termios*)argp;

        //Debug_PrintF("TCGETS\n");

        memcpy((uint8*)term, (uint8*)&(tty->term), sizeof(struct termios));

        return 0;//success
    }
        break;
    case TCSETS:
    case TCSETSW:
        break;
    case TCSETSF:
    {
        struct termios* term = (struct termios*)argp;

        //Debug_PrintF("TCSETSF\n");

        memcpy((uint8*)&(tty->term), (uint8*)term, sizeof(struct termios));

        return 0;//success
    }
        break;
    default:
        break;
    }

    return -1;
}

static int32 tty_read(File *file, uint32 size, uint8 *buffer)
{
    enableInterrupts();

    if (size > 0)
    {
        Tty* tty = (Tty*)file->node->privateNodeData;

        if ((tty->term.c_lflag & ICANON) == ICANON)
        {
            while (TRUE)
            {
                for (int i = 0; i < tty->lineBufferIndex; ++i)
                {
                    char chr = tty->lineBuffer[i];

                    if (chr == '\n')
                    {
                        int bytesToCopy = MIN(tty->lineBufferIndex, size);

                        if (bytesToCopy >= tty->term.c_cc[VMIN])
                        {
                            tty->lineBufferIndex = 0;
                            memcpy(buffer, tty->lineBuffer, bytesToCopy);

                            return bytesToCopy;
                        }
                    }
                }

                file->thread->state = TS_WAITIO;
                file->thread->state_privateData = tty;
                halt();
            }
        }
        else
        {
            while (TRUE)
            {
                uint32 neededSize = tty->term.c_cc[VMIN];
                uint32 bufferLen = FifoBuffer_getSize(tty->keyBuffer);

                if (bufferLen >= neededSize)
                {
                    int readSize = FifoBuffer_dequeue(tty->keyBuffer, buffer, MIN(bufferLen, size));

                    return readSize;
                }

                file->thread->state = TS_WAITIO;
                file->thread->state_privateData = tty;
                halt();
            }
        }
    }

    return -1;
}

static int32 write(Tty* tty, uint32 size, uint8 *buffer)
{
    buffer[size] = '\0';

    Tty_PutText(tty, (const char*)buffer);

    if (gActiveTty == tty)
    {
        if (gActiveTty->flushScreen)
        {
            gActiveTty->flushScreen(gActiveTty);
        }
    }

    return size;
}

static int32 tty_write(File *file, uint32 size, uint8 *buffer)
{
    return write(file->node->privateNodeData, size, buffer);
}

static void setActiveTty(Tty* tty)
{
    gActiveTty = tty;

    Gfx_Fill(0xFFFFFFFF);

    if (tty->flushScreen)
    {
        tty->flushScreen(tty);
    }

    //Serial_PrintF("line:%d column:%d\r\n", gActiveTty->currentLine, gActiveTty->currentColumn);
}

BOOL isValidTTY(Tty* tty)
{
    List_Foreach(n, gTtyList)
    {
        if (n->data == tty)
        {
            return TRUE;
        }
    }

    return FALSE;
}

static uint8 getCharacterForScancode(KeyModifier modifier, uint8 scancode)
{
    //return gKeyboardLayout[scancode];
    if ((modifier & KM_LeftShift) == KM_LeftShift || (modifier & KM_RightShift) == KM_RightShift)
    {
        return gKeyShiftMap[scancode];
    }

    return gKeyMap[scancode];
}

static void applyModifierKeys(KeyModifier modifier, uint8 scancode)
{
    if ((modifier & KM_Ctrl) == KM_Ctrl)
    {
        int ttyIndex = scancode - KEY_F1;
        //printkf("TTY:%d\n", ttyIndex);
        int ttyCount = List_GetCount(gTtyList);
        if (ttyIndex >= 0 && ttyIndex < ttyCount)
        {
            int i = 0;
            List_Foreach(n, gTtyList)
            {
                if (ttyIndex == i)
                {
                    setActiveTty(n->data);
                    break;
                }
                ++i;
            }
        }
    }
}

static void processScancode(uint8 scancode)
{
    uint8 lastBit = scancode & 0x80;

    scancode &= 0x7F;

    if (lastBit)
    {
        //key release

        switch (scancode)
        {
        case KEY_LEFTSHIFT:
            gKeyModifier &= ~KM_LeftShift;
            break;
        case KEY_RIGHTSHIFT:
            gKeyModifier &= ~KM_RightShift;
            break;
        case KEY_CTRL:
            gKeyModifier &= ~KM_Ctrl;
            break;
        case KEY_ALT:
            gKeyModifier &= ~KM_Alt;
            break;
        }

        //Screen_PrintF("released: %x (%d)\n", scancode, scancode);
    }
    else
    {
        //key pressed

        switch (scancode)
        {
        case KEY_LEFTSHIFT:
            gKeyModifier |= KM_LeftShift;
            break;
        case KEY_RIGHTSHIFT:
            gKeyModifier |= KM_RightShift;
            break;
        case KEY_CTRL:
            gKeyModifier |= KM_Ctrl;
            break;
        case KEY_ALT:
            gKeyModifier |= KM_Alt;
            break;
        }

        //Screen_PrintF("pressed: %x (%d)\n", scancode, scancode);

        applyModifierKeys(gKeyModifier, scancode);
    }
}
