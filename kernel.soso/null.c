#include "null.h"
#include "devfs.h"
#include "device.h"
#include "common.h"

static BOOL null_open(File *file, uint32 flags);

void initializeNull()
{
    Device device;
    memset((uint8*)&device, 0, sizeof(Device));
    strcpy(device.name, "null");
    device.deviceType = FT_CharacterDevice;
    device.open = null_open;

    registerDevice(&device);
}

static BOOL null_open(File *file, uint32 flags)
{
    return TRUE;
}
