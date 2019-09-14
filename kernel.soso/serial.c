#include "common.h"
#include "serial.h"

#define PORT 0x3f8   //COM1

void initializeSerial()
{
   outb(PORT + 1, 0x00);    // Disable all interrupts
   outb(PORT + 3, 0x80);    // Enable DLAB (set baud rate divisor)
   outb(PORT + 0, 0x03);    // Set divisor to 3 (lo byte) 38400 baud
   outb(PORT + 1, 0x00);    //                  (hi byte)
   outb(PORT + 3, 0x03);    // 8 bits, no parity, one stop bit
   outb(PORT + 2, 0xC7);    // Enable FIFO, clear them, with 14-byte threshold
   outb(PORT + 4, 0x0B);    // IRQs enabled, RTS/DSR set
}

int serialReceived()
{
   return inb(PORT + 5) & 1;
}

char readSerial()
{
   while (serialReceived() == 0);

   return inb(PORT);
}

int isTransmitEmpty()
{
   return inb(PORT + 5) & 0x20;
}

void writeSerial(char a)
{
   while (isTransmitEmpty() == 0);

   outb(PORT,a);
}

void Serial_PrintF(const char *format, ...)
{
  char **arg = (char **) &format;
  char c;
  char buf[20];

  //arg++;
  __builtin_va_list vl;
  __builtin_va_start(vl, format);

  while ((c = *format++) != 0)
    {
      if (c != '%')
        writeSerial(c);
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
                writeSerial(*p++);
              break;

            default:
              //writeSerial(*((int *) arg++));
              writeSerial(__builtin_va_arg(vl, int));
              break;
            }
        }
    }
  __builtin_va_end(vl);
}
