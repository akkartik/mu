#include "screen.h"
#include "common.h"
#include "serial.h"

#define SCREEN_LINE_COUNT 25
#define SCREEN_COLUMN_COUNT 80

static unsigned char *videoStart = (unsigned char*)0xB8000;

static uint16 gCurrentLine = 0;
static uint16 gCurrentColumn = 0;
static uint8 gColor = 0x0A;

void Screen_FlushFromTty(Tty* tty)
{
    memcpy(videoStart, tty->buffer, SCREEN_LINE_COUNT * SCREEN_COLUMN_COUNT * 2);

    Screen_MoveCursor(tty->currentLine, tty->currentColumn);
}

void Screen_Print(int row, int column, const char* text)
{
    unsigned char * video = videoStart;
    
    video += (row * SCREEN_COLUMN_COUNT + column) * 2;
    while(*text != 0)
    {
        *video++ = *text++;
        *video++ = gColor;
    }
}

void Screen_SetActiveColor(uint8 color)
{
    gColor = color;
}

void Screen_ApplyColor(uint8 color)
{
    gColor = color;

    unsigned char * video = videoStart;
    int i = 0;

    for (i = 0; i < SCREEN_LINE_COUNT * SCREEN_COLUMN_COUNT; ++i)
    {
        video++;
        *video++ = gColor;
    }
}

void Screen_Clear()
{
	unsigned char * video = videoStart;
	int i = 0;
    
    for (i = 0; i < SCREEN_LINE_COUNT * SCREEN_COLUMN_COUNT; ++i)
    {
        *video++ = 0;
        *video++ = gColor;
    }
    
    gCurrentLine = 0;
    gCurrentColumn = 0;
}

void Screen_MoveCursor(uint16 line, uint16 column)
{
   // The screen is 80 characters wide...
   uint16 cursorLocation = line * SCREEN_COLUMN_COUNT + column;
   outb(0x3D4, 14);                  // Tell the VGA board we are setting the high cursor byte.
   outb(0x3D5, cursorLocation >> 8); // Send the high cursor byte.
   outb(0x3D4, 15);                  // Tell the VGA board we are setting the low cursor byte.
   outb(0x3D5, cursorLocation);      // Send the low cursor byte.

   gCurrentColumn = column;
   gCurrentLine = line;
}

void Screen_SetCursorVisible(BOOL visible)
{
    uint8 cursor = inb(0x3d5);

    if (visible)
    {
        cursor &= ~0x20;//5th bit cleared when cursor visible
    }
    else
    {
        cursor |= 0x20;//5th bit set when cursor invisible
    }
    outb(0x3D5, cursor);
}

void Screen_GetCursor(uint16* line, uint16* column)
{
    *line = gCurrentLine;
    *column = gCurrentColumn;
}
