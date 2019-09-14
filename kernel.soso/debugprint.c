#include "debugprint.h"
#include "common.h"
#include "fs.h"

static File* gFile = NULL;

void Debug_initialize(const char* fileName)
{
    FileSystemNode* node = getFileSystemNode(fileName);

    gFile = open_fs(node, 0);
}

void Debug_PrintF(const char *format, ...)
{
    char **arg = (char **) &format;
    char c;
    char buf[20];
    char buffer[512];

    int bufferIndex = 0;

    //arg++;
    __builtin_va_list vl;
    __builtin_va_start(vl, format);

    while ((c = *format++) != 0)
      {
        if (bufferIndex > 510)
        {
            break;
        }

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

    if (gFile)
    {
        write_fs(gFile, strlen(buffer), (uint8*)buffer);
    }

    __builtin_va_end(vl);
}
