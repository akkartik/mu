#ifndef DEVFS_H
#define DEVFS_H

#include "device.h"
#include "fs.h"
#include "common.h"

void initializeDevFS();
FileSystemNode* registerDevice(Device* device);

#endif // DEVFS_H
