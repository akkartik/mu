#include "random.h"
#include "devfs.h"
#include "device.h"
#include "common.h"
#include "process.h"
#include "sleep.h"

static BOOL random_open(File *file, uint32 flags);
static int32 random_read(File *file, uint32 size, uint8 *buffer);

void initializeRandom()
{
    Device device;
    memset((uint8*)&device, 0, sizeof(Device));
    strcpy(device.name, "random");
    device.deviceType = FT_CharacterDevice;
    device.open = random_open;
    device.read = random_read;

    registerDevice(&device);
}

static BOOL random_open(File *file, uint32 flags)
{
    return TRUE;
}

static int32 random_read(File *file, uint32 size, uint8 *buffer)
{
    if (size == 0)
    {
        return 0;
    }

    //Screen_PrintF("random_read: calling sleep\n");

    //sleep(10000);

    //Screen_PrintF("random_read: returned from sleep\n");

    uint32 number = rand();

    if (size == 1)
    {
        *buffer = (uint8)number;
        return 1;
    }
    else if (size == 2 || size == 3)
    {
        *((uint16*)buffer) = (uint16)number;
        return 2;
    }
    else if (size >= 4)
    {
        //Screen_PrintF("random_read: buffer is %x, writing %x to buffer\n", buffer, number);

        *((uint32*)buffer) = number;
        return 4;
    }

    return 0;
}
