#include "gfx.h"
#include "vmm.h"
#include "serial.h"
#include "framebuffer.h"
#include "debugprint.h"

static uint32 gWidth = 0;
static uint32 gHeight = 0;
static uint32 gBytesPerPixel = 0;
static uint32 gPitch = 0;
static uint32* gPixels = NULL;

extern char _binary_font_psf_start;
extern char _binary_font_psf_end;

uint16 *gUnicode = NULL;

static int gLineCount = 10;
static int gColumnCount = 10;
static uint16 gCurrentLine = 0;
static uint16 gCurrentColumn = 0;

#define LINE_HEIGHT 16

void Gfx_Initialize(uint32* pixels, uint32 width, uint32 height, uint32 bytesPerPixel, uint32 pitch)
{
    char* p_address = (char*)pixels;
    char* v_address = (char*)GFX_MEMORY;

    //Usually physical and virtual are the same here but of course they don't have to

    gPixels = (uint32*)v_address;
    gWidth = width;
    gHeight = height;
    gBytesPerPixel = bytesPerPixel;
    gPitch = pitch;

    gLineCount = gHeight / LINE_HEIGHT;
    gColumnCount = gWidth / 8;


    BOOL success = addPageToPd(gKernelPageDirectory, v_address, p_address, 0);

    if (success)
    {
        for (int y = 0; y < gHeight; ++y)
        {
            for (int x = 0; x < gWidth; ++x)
            {
                gPixels[x + y * gWidth] = 0xFFFFFFFF;
            }
        }
    }
    else
    {
        Debug_PrintF("Gfx initialization failed!\n");
    }

    initializeFrameBuffer((uint8*)p_address, (uint8*)v_address);
}

#define PSF_FONT_MAGIC 0x864ab572

typedef struct {
    uint32 magic;         /* magic bytes to identify PSF */
    uint32 version;       /* zero */
    uint32 headersize;    /* offset of bitmaps in file, 32 */
    uint32 flags;         /* 0 if there's no unicode table */
    uint32 numglyph;      /* number of glyphs */
    uint32 bytesperglyph; /* size of each glyph */
    uint32 height;        /* height in pixels */
    uint32 width;         /* width in pixels */
} PSF_font;

//From Osdev PC Screen Font (The font used here is free to use)
void Gfx_PutCharAt(
    /* note that this is int, not char as it's a unicode character */
    unsigned short int c,
    /* cursor position on screen, in characters not in pixels */
    int cx, int cy,
    /* foreground and background colors, say 0xFFFFFF and 0x000000 */
    uint32 fg, uint32 bg)
{
    /* cast the address to PSF header struct */
    PSF_font *font = (PSF_font*)&_binary_font_psf_start;
    /* we need to know how many bytes encode one row */
    int bytesperline=(font->width+7)/8;
    /* unicode translation */
    if(gUnicode != NULL) {
        c = gUnicode[c];
    }
    /* get the glyph for the character. If there's no
       glyph for a given character, we'll display the first glyph. */
    unsigned char *glyph =
     (unsigned char*)&_binary_font_psf_start +
     font->headersize +
     (c>0&&c<font->numglyph?c:0)*font->bytesperglyph;
    /* calculate the upper left corner on screen where we want to display.
       we only do this once, and adjust the offset later. This is faster. */
    int offs =
        (cy * font->height * gPitch) +
        (cx * (font->width+1) * 4);
    /* finally display pixels according to the bitmap */
    int x,y, line,mask;
    for(y=0;y<font->height;y++){
        /* save the starting position of the line */
        line=offs;
        mask=1<<(font->width-1);
        /* display a row */
        for(x=0;x<font->width;x++)
        {
            if (c == 0)
            {
                *((uint32*)((uint8*)gPixels + line)) = bg;
            }
            else
            {
                *((uint32*)((uint8*)gPixels + line)) = ((int)*glyph) & (mask) ? fg : bg;
            }

            /* adjust to the next pixel */
            mask >>= 1;
            line += 4;
        }
        /* adjust to the next line */
        glyph += bytesperline;
        offs  += gPitch;
    }
}

void Gfx_FlushFromTty(Tty* tty)
{
    for (uint32 r = 0; r < tty->lineCount; ++r)
    {
        for (uint32 c = 0; c < tty->columnCount; ++c)
        {
            uint8* ttyPos = tty->buffer + (r * tty->columnCount + c) * 2;

            uint8 chr = ttyPos[0];
            uint8 color = ttyPos[1];

            Gfx_PutCharAt(chr, c, r, 0, 0xFFFFFFFF);
        }
    }

    //Screen_MoveCursor(tty->currentLine, tty->currentColumn);
}

uint8* Gfx_GetVideoMemory()
{
    return (uint8*)gPixels;
}

uint16 Gfx_GetWidth()
{
    return gWidth;
}

uint16 Gfx_GetHeight()
{
    return gHeight;
}

uint16 Gfx_GetBytesPerPixel()
{
    return gBytesPerPixel;
}

void Gfx_Fill(uint32 color)
{
    for (uint32 y = 0; y < gHeight; ++y)
    {
        for (uint32 x = 0; x < gWidth; ++x)
        {
            gPixels[x + y * gWidth] = color;
        }
    }
}
