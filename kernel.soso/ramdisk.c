#include "ramdisk.h"
#include "alloc.h"
#include "fs.h"
#include "devfs.h"

typedef struct Ramdisk
{
    uint8* buffer;
    uint32 size;
} Ramdisk;

#define RAMDISK_BLOCKSIZE 512

static BOOL open(File *file, uint32 flags);
static void close(File *file);
static int32 readBlock(FileSystemNode* node, uint32 blockNumber, uint32 count, uint8* buffer);
static int32 writeBlock(FileSystemNode* node, uint32 blockNumber, uint32 count, uint8* buffer);
static int32 ioctl(File *node, int32 request, void * argp);

BOOL createRamdisk(const char* devName, uint32 size)
{
    Ramdisk* ramdisk = kmalloc(sizeof(Ramdisk));
    ramdisk->size = size;
    ramdisk->buffer = kmalloc(size);

    Device device;
    memset((uint8*)&device, 0, sizeof(device));
    strcpy(device.name, devName);
    device.deviceType = FT_BlockDevice;
    device.open = open;
    device.close = close;
    device.readBlock = readBlock;
    device.writeBlock = writeBlock;
    device.ioctl = ioctl;
    device.privateData = ramdisk;

    if (registerDevice(&device))
    {
        return TRUE;
    }

    kfree(ramdisk->buffer);
    kfree(ramdisk);

    return FALSE;
}

static BOOL open(File *file, uint32 flags)
{
    return TRUE;
}

static void close(File *file)
{
}

static int32 readBlock(FileSystemNode* node, uint32 blockNumber, uint32 count, uint8* buffer)
{
    Ramdisk* ramdisk = (Ramdisk*)node->privateNodeData;

    uint32 location = blockNumber * RAMDISK_BLOCKSIZE;
    uint32 size = count * RAMDISK_BLOCKSIZE;

    if (location + size > ramdisk->size)
    {
        return -1;
    }

    beginCriticalSection();

    memcpy(buffer, ramdisk->buffer + location, size);

    endCriticalSection();

    return 0;
}

static int32 writeBlock(FileSystemNode* node, uint32 blockNumber, uint32 count, uint8* buffer)
{
    Ramdisk* ramdisk = (Ramdisk*)node->privateNodeData;

    uint32 location = blockNumber * RAMDISK_BLOCKSIZE;
    uint32 size = count * RAMDISK_BLOCKSIZE;

    if (location + size > ramdisk->size)
    {
        return -1;
    }

    beginCriticalSection();

    memcpy(ramdisk->buffer + location, buffer, size);

    endCriticalSection();

    return 0;
}

static int32 ioctl(File *node, int32 request, void * argp)
{
    Ramdisk* ramdisk = (Ramdisk*)node->node->privateNodeData;

    uint32* result = (uint32*)argp;

    switch (request)
    {
    case IC_GetSectorCount:
        *result = ramdisk->size / RAMDISK_BLOCKSIZE;
        return 0;
        break;
    case IC_GetSectorSizeInBytes:
        *result = RAMDISK_BLOCKSIZE;
        return 0;
        break;
    default:
        break;
    }

    return -1;
}
