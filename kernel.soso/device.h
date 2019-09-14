#ifndef DEVICE_H
#define DEVICE_H

#include "common.h"
#include "fs.h"

typedef struct Device
{
    char name[16];
    FileType deviceType;
    ReadWriteBlockFunction readBlock;
    ReadWriteBlockFunction writeBlock;
    ReadWriteFunction read;
    ReadWriteFunction write;
    OpenFunction open;
    CloseFunction close;
    IoctlFunction ioctl;
    FtruncateFunction ftruncate;
    MmapFunction mmap;
    MunmapFunction munmap;
    void * privateData;
} Device;

#endif // DEVICE_H
