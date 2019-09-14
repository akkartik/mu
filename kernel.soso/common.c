#include "common.h"
#include "screen.h"
#include "ttydriver.h"

static BOOL gInterruptsWereEnabled = FALSE;

// Write a byte out to the specified port.
void outb(uint16 port, uint8 value)
{
    asm volatile ("outb %1, %0" : : "dN" (port), "a" (value));
}

void outw(uint16 port, uint16 value)
{
    asm volatile ("outw %1, %0" : : "dN" (port), "a" (value));
}

uint8 inb(uint16 port)
{
    uint8 ret;
    asm volatile("inb %1, %0" : "=a" (ret) : "dN" (port));
    return ret;
}

uint16 inw(uint16 port)
{
    uint16 ret;
    asm volatile ("inw %1, %0" : "=a" (ret) : "dN" (port));
    return ret;
}

// Copy len bytes from src to dest.
void* memcpy(uint8 *dest, const uint8 *src, uint32 len)
{
    const uint8 *sp = (const uint8 *)src;
    uint8 *dp = (uint8 *)dest;
    for(; len != 0; len--) *dp++ = *sp++;

    return dest;
}

// Write len copies of val into dest.
void* memset(uint8 *dest, uint8 val, uint32 len)
{
    uint8 *temp = (uint8 *)dest;
    for ( ; len != 0; len--) *temp++ = val;

    return dest;
}

void* memmove(void* dest, const void* src, uint32 n)
{
    uint8* _dest;
    uint8* _src;

    if ( dest < src ) {
        _dest = ( uint8* )dest;
        _src = ( uint8* )src;

        while ( n-- ) {
            *_dest++ = *_src++;
        }
    } else {
        _dest = ( uint8* )dest + n;
        _src = ( uint8* )src + n;

        while ( n-- ) {
            *--_dest = *--_src;
        }
    }

    return dest;
}

int memcmp( const void* p1, const void* p2, uint32 c )
{
    const uint8* su1, *su2;
    int8 res = 0;

    for ( su1 = p1, su2 = p2; 0 < c; ++su1, ++su2, c-- ) {
        if ( ( res = *su1 - *su2 ) != 0 ) {
            break;
        }
    }

    return res;
}

// Compare two strings. Should return -1 if 
// str1 < str2, 0 if they are equal or 1 otherwise.
int strcmp(const char *str1, const char *str2)
{
      int i = 0;
      int failed = 0;
      while(str1[i] != '\0' && str2[i] != '\0')
      {
          if(str1[i] != str2[i])
          {
              failed = 1;
              break;
          }
          i++;
      }

      if ((str1[i] == '\0' && str2[i] != '\0') || (str1[i] != '\0' && str2[i] == '\0'))
      {
          failed = 1;
      }
  
      return failed;
}

int strncmp(const char *str1, const char *str2, int length)
{
    for (int i = 0; i < length; ++i)
    {
        if (str1[i] != str2[i])
        {
            return str1[i] - str2[i];
        }
    }

    return 0;
}

// Copy the NULL-terminated string src into dest, and
// return dest.
char *strcpy(char *dest, const char *src)
{
    do
    {
      *dest++ = *src++;
    }
    while (*src != 0);
    *dest = '\0';

    return dest;
}

char *strcpyNonNull(char *dest, const char *src)
{
    do
    {
      *dest++ = *src++;
    }
    while (*src != 0);

    return dest;
}

//Copies the first num characters of source to destination. If the end of the source C string is found before num characters have been copied,
//destination is padded with zeros until a total of num characters have been written to it.
//No null-character is implicitly appended at the end of destination if source is longer than num.
//Thus, in this case, destination shall not be considered a null terminated C string.
char *strncpy(char *dest, const char *src, uint32 num)
{
    BOOL sourceEnded = FALSE;
    for (uint32 i = 0; i < num; ++i)
    {
        if (sourceEnded == FALSE && src[i] == '\0')
        {
            sourceEnded = TRUE;
        }

        if (sourceEnded)
        {
            dest[i] = '\0';
        }
        else
        {
            dest[i] = src[i];
        }
    }

    return dest;
}

char* strcat(char *dest, const char *src)
{
    size_t i,j;
    for (i = 0; dest[i] != '\0'; i++)
        ;
    for (j = 0; src[j] != '\0'; j++)
        dest[i+j] = src[j];
    dest[i+j] = '\0';
    return dest;
}

int strlen(const char *src)
{
    int i = 0;
    while (*src++)
        i++;
    return i;
}

int strFirstIndexOf(const char *src, char c)
{
    int i = 0;
    while (src[i])
    {
        if (src[i] == c)
        {
            return i;
        }
        i++;
    }

    return -1;
}

uint32 rand()
{
    static uint32 x = 123456789;
    static uint32 y = 362436069;
    static uint32 z = 521288629;
    static uint32 w = 88675123;

    uint32 t;

    t = x ^ (x << 11);
    x = y; y = z; z = w;
    return w = w ^ (w >> 19) ^ t ^ (t >> 8);
}

int atoi(char *str)
{
    int result = 0;

    for (int i = 0; str[i] != '\0'; ++i)
    {
        result = result*10 + str[i] - '0';
    }

    return result;
}

void itoa (char *buf, int base, int d)
{
    char *p = buf;
    char *p1, *p2;
    unsigned long ud = d;
    int divisor = 10;


    if (base == 'd' && d < 0)
    {
        *p++ = '-';
        buf++;
        ud = -d;
    }
    else if (base == 'x')
    {
        divisor = 16;
    }

    do
    {
        int remainder = ud % divisor;

        *p++ = (remainder < 10) ? remainder + '0' : remainder + 'A' - 10;
    }
    while (ud /= divisor);


    *p = 0;

    //Reverse BUF.
    p1 = buf;
    p2 = p - 1;
    while (p1 < p2)
    {
        char tmp = *p1;
        *p1 = *p2;
        *p2 = tmp;
        p1++;
        p2--;
    }
}

int sprintf_va(char* buffer, const char *format, __builtin_va_list vl)
{
    char c;
    char buf[20];

    int bufferIndex = 0;

    while ((c = *format++) != 0)
      {
        if (c != '%')
          buffer[bufferIndex++] = c;
        else
          {
            char *p;

            c = *format++;
            switch (c)
              {
              case 'x':
                 buf[0] = '0';
                 buf[1] = 'x';
                 //itoa (buf + 2, c, *((int *) arg++));
                 itoa (buf + 2, c, __builtin_va_arg(vl, int));
                 p = buf;
                 goto string;
                 break;
              case 'd':
              case 'u':
                //itoa (buf, c, *((int *) arg++));
                itoa (buf, c, __builtin_va_arg(vl, int));
                p = buf;
                goto string;
                break;

              case 's':
                //p = *arg++;
                p = __builtin_va_arg(vl, char*);
                if (! p)
                  p = "(null)";

              string:
                while (*p)
                  buffer[bufferIndex++] = (*p++);
                break;

              default:
                //buffer[bufferIndex++] = (*((int *) arg++));
                buffer[bufferIndex++] = __builtin_va_arg(vl, int);
                break;
              }
          }
      }

    buffer[bufferIndex] = '\0';

    return bufferIndex;
}

int sprintf(char* buffer, const char *format, ...)
{
    int result = 0;

    __builtin_va_list vl;
    __builtin_va_start(vl, format);

    result = sprintf_va(buffer, format, vl);

    __builtin_va_end(vl);

    return result;
}

void printkf(const char *format, ...)
{
    char buffer[1024];
    buffer[0] = 'k';
    buffer[1] = ':';
    buffer[2] = 0;

    Tty* tty = getActiveTTY();
    if (tty)
    {
        __builtin_va_list vl;
        __builtin_va_start(vl, format);

        sprintf_va(buffer+2, format, vl);

        __builtin_va_end(vl);

        Tty_PutText(tty, buffer);

        if (tty->flushScreen)
        {
            tty->flushScreen(tty);
        }
    }
}

void panic(const char *message, const char *file, uint32 line)
{
    disableInterrupts();

    printkf("PANIC:%s:%d:%s\n", file, line, message);

    halt();
}

void warning(const char *message, const char *file, uint32 line)
{
    printkf("WARNING:%s:%d:%s\n", file, line, message);
}

void panic_assert(const char *file, uint32 line, const char *desc)
{
    disableInterrupts();

    printkf("ASSERTION-FAILED:%s:%d:%s\n", file, line, desc);

    halt();
}

uint32 readEsp()
{
    uint32 stack_pointer;
    asm volatile("mov %%esp, %0" : "=r" (stack_pointer));

    return stack_pointer;
}

uint32 getCpuFlags()
{
    uint32 eflags = 0;

    asm("pushfl; pop %%eax; mov %%eax, %0": "=m"(eflags):);

    return eflags;
}

BOOL isInterruptsEnabled()
{
    uint32 eflags = getCpuFlags();

    uint32 interruptFlag = 0x200; //9th flag

    return (eflags & interruptFlag) == interruptFlag;
}

void beginCriticalSection()
{
    gInterruptsWereEnabled = isInterruptsEnabled();

    disableInterrupts();
}

void endCriticalSection()
{
    if (gInterruptsWereEnabled)
    {
        enableInterrupts();
    }
}
