#ifndef TTY_H
#define TTY_H

#include "common.h"
#include "fifobuffer.h"
#include "termios.h"

#define TTY_LINEBUFFER_SIZE 1024

typedef struct Tty Tty;

typedef void (*TtyFlushScreenFunction)(Tty* tty);

typedef struct Tty
{
    uint16 lineCount;
    uint16 columnCount;
    uint8* buffer;
    uint16 currentLine;
    uint16 currentColumn;
    uint8 color;
    void* privateData;
    uint8 lineBuffer[TTY_LINEBUFFER_SIZE];
    uint32 lineBufferIndex;
    FifoBuffer* keyBuffer;
    struct termios term;
    TtyFlushScreenFunction flushScreen;
} Tty;



Tty* createTty(uint16 lineCount, uint16 columnCount, TtyFlushScreenFunction flushFunction);
void destroyTty(Tty* tty);

void Tty_Print(Tty* tty, int row, int column, const char* text);
void Tty_Clear(Tty* tty);
void Tty_PutChar(Tty* tty, char c);
void Tty_PutText(Tty* tty, const char* text);
void Tty_MoveCursor(Tty* tty, uint16 line, uint16 column);
void Tty_ScrollUp(Tty* tty);

#endif // TTY_H
