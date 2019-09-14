#ifndef COMMONUSER_H
#define COMMONUSER_H

typedef struct SosoMessage
{
    int messageType;
    int parameter1;
    int parameter2;
    int parameter3;
} SosoMessage;

typedef struct TtyUserBuffer
{
    unsigned short lineCount;
    unsigned short columnCount;
    unsigned short currentLine;
    unsigned short currentColumn;
    unsigned char* buffer;
} TtyUserBuffer;

#endif // COMMONUSER_H
