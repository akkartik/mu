#include "devfs.h"
#include "common.h"
#include "fs.h"
#include "alloc.h"
#include "device.h"
#include "screen.h"
#include "list.h"
#include "spinlock.h"

static FileSystemNode* gDevRoot = NULL;

static List* gDeviceList = NULL;
static Spinlock gDeviceListLock;

static BOOL devfs_open(File *node, uint32 flags);
static FileSystemDirent *devfs_readdir(FileSystemNode *node, uint32 index);
static FileSystemNode *devfs_finddir(FileSystemNode *node, char *name);

static FileSystemDirent gDirent;

void initializeDevFS()
{
    gDevRoot = kmalloc(sizeof(FileSystemNode));
    memset((uint8*)gDevRoot, 0, sizeof(FileSystemNode));

    gDevRoot->nodeType = FT_Directory;

    FileSystemNode* rootFs = getFileSystemRootNode();

    FileSystemNode* devNode = finddir_fs(rootFs, "dev");

    if (devNode)
    {
        devNode->nodeType |= FT_MountPoint;
        devNode->mountPoint = gDevRoot;
        gDevRoot->parent = devNode->parent;
        strcpy(gDevRoot->name, devNode->name);
    }
    else
    {
        PANIC("/dev does not exist!");
    }

    gDevRoot->open = devfs_open;
    gDevRoot->finddir = devfs_finddir;
    gDevRoot->readdir = devfs_readdir;

    gDeviceList = List_Create();
    Spinlock_Init(&gDeviceListLock);
}

static BOOL devfs_open(File *node, uint32 flags)
{
    return TRUE;
}

static FileSystemDirent *devfs_readdir(FileSystemNode *node, uint32 index)
{
    FileSystemDirent * result = NULL;

    uint32 counter = 0;

    Spinlock_Lock(&gDeviceListLock);

    List_Foreach(n, gDeviceList)
    {
        if (index == counter)
        {
            FileSystemNode* deviceNode = (FileSystemNode*)n->data;
            strcpy(gDirent.name, deviceNode->name);
            gDirent.fileType = deviceNode->nodeType;
            gDirent.inode = index;
            result = &gDirent;
            break;
        }

        ++counter;
    }
    Spinlock_Unlock(&gDeviceListLock);

    return result;
}

static FileSystemNode *devfs_finddir(FileSystemNode *node, char *name)
{
    FileSystemNode* result = NULL;


    Spinlock_Lock(&gDeviceListLock);

    List_Foreach(n, gDeviceList)
    {
        FileSystemNode* deviceNode = (FileSystemNode*)n->data;

        if (strcmp(name, deviceNode->name) == 0)
        {
            result = deviceNode;
            break;
        }
    }

    Spinlock_Unlock(&gDeviceListLock);

    return result;
}

FileSystemNode* registerDevice(Device* device)
{
    Spinlock_Lock(&gDeviceListLock);

    List_Foreach(n, gDeviceList)
    {
        FileSystemNode* deviceNode = (FileSystemNode*)n->data;

        if (strcmp(device->name, deviceNode->name) == 0)
        {
            //There is already a device with the same name
            Spinlock_Unlock(&gDeviceListLock);
            return NULL;
        }
    }

    FileSystemNode* deviceNode = (FileSystemNode*)kmalloc(sizeof(FileSystemNode));
    memset((uint8*)deviceNode, 0, sizeof(FileSystemNode));
    strcpy(deviceNode->name, device->name);
    deviceNode->nodeType = device->deviceType;
    deviceNode->open = device->open;
    deviceNode->close = device->close;
    deviceNode->readBlock = device->readBlock;
    deviceNode->writeBlock = device->writeBlock;
    deviceNode->read = device->read;
    deviceNode->write = device->write;
    deviceNode->ioctl = device->ioctl;
    deviceNode->ftruncate = device->ftruncate;
    deviceNode->mmap = device->mmap;
    deviceNode->munmap = device->munmap;
    deviceNode->privateNodeData = device->privateData;
    deviceNode->parent = gDevRoot;

    List_Append(gDeviceList, deviceNode);

    Spinlock_Unlock(&gDeviceListLock);

    return deviceNode;
}
