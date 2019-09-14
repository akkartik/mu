#include "fatfilesystem.h"
#include "common.h"
#include "fs.h"
#include "alloc.h"
#include "fatfs_ff.h"
#include "fatfs_diskio.h"
#include "screen.h"

#define SEEK_SET	0	/* Seek from beginning of file.  */
#define SEEK_CUR	1	/* Seek from current position.  */
#define SEEK_END	2

#define O_RDONLY	     00
#define O_WRONLY	     01
#define O_RDWR		     02

static BOOL mount(const char* sourcePath, const char* targetPath, uint32 flags, void *data);
static BOOL checkMount(const char* sourcePath, const char* targetPath, uint32 flags, void *data);
static FileSystemDirent* readdir(FileSystemNode *node, uint32 index);
static FileSystemNode* finddir(FileSystemNode *node, char *name);
static int32 read(File *file, uint32 size, uint8 *buffer);
static int32 write(File *file, uint32 size, uint8 *buffer);
static int32 lseek(File *file, int32 offset, int32 whence);
static int32 stat(FileSystemNode *node, struct stat* buf);
static BOOL open(File *file, uint32 flags);
static void close(File *file);

static FileSystemDirent gFileSystemDirent;

static FileSystemNode* gMountedBlockDevices[FF_VOLUMES];


void initializeFatFileSystem()
{
    FileSystem fs;
    memset((uint8*)&fs, 0, sizeof(fs));
    strcpy(fs.name, "fat");
    fs.mount = mount;
    fs.checkMount = checkMount;

    registerFileSystem(&fs);

    for (int i = 0; i < FF_VOLUMES; ++i)
    {
        gMountedBlockDevices[i] = NULL;
    }
}

static BOOL mount(const char* sourcePath, const char* targetPath, uint32 flags, void *data)
{
    printkf("fat mount source: %s\n", sourcePath);

    FileSystemNode* node = getFileSystemNode(sourcePath);
    if (node && node->nodeType == FT_BlockDevice)
    {
        FileSystemNode* targetNode = getFileSystemNode(targetPath);
        if (targetNode)
        {
            if (targetNode->nodeType == FT_Directory)
            {
                printkf("fat mount target: %s\n", targetPath);

                int32 volume = -1;
                for (int32 v = 0; v < FF_VOLUMES; ++v)
                {
                    if (NULL == gMountedBlockDevices[v])
                    {
                        volume = v;
                        break;
                    }
                }

                if (volume < 0)
                {
                    return FALSE;
                }

                FileSystemNode* newNode = kmalloc(sizeof(FileSystemNode));

                memset((uint8*)newNode, 0, sizeof(FileSystemNode));
                strcpy(newNode->name, targetNode->name);
                newNode->nodeType = FT_Directory;
                newNode->open = open;
                newNode->readdir = readdir;
                newNode->finddir = finddir;
                newNode->parent = targetNode->parent;
                newNode->mountSource = node;
                newNode->privateNodeData = (void*)volume;

                gMountedBlockDevices[volume] = node;

                FATFS* fatFs = (FATFS*)kmalloc(sizeof(FATFS));
                //uint8 work[512];
                //FRESULT fr = f_mkfs("", FM_FAT | FM_SFD, 512, work, 512);
                //Screen_PrintF("f_mkfs: %d\n", fr);
                char path[8];
                sprintf(path, "%d:", volume);
                FRESULT fr = f_mount(fatFs, path, 1);
                //Screen_PrintF("f_mount: fr:%d drv:%d\n", fr, fatFs->pdrv);

                if (FR_OK == fr)
                {
                    targetNode->nodeType |= FT_MountPoint;
                    targetNode->mountPoint = newNode;

                    return TRUE;
                }
                else
                {
                    kfree(newNode);

                    kfree(fatFs);

                    gMountedBlockDevices[volume] = NULL;
                }
            }
        }
    }

    return FALSE;
}

static BOOL checkMount(const char* sourcePath, const char* targetPath, uint32 flags, void *data)
{
    FileSystemNode* node = getFileSystemNode(sourcePath);
    if (node && node->nodeType == FT_BlockDevice)
    {
        FileSystemNode* targetNode = getFileSystemNode(targetPath);
        if (targetNode)
        {
            if (targetNode->nodeType == FT_Directory)
            {
                return TRUE;
            }
        }
    }

    return FALSE;
}

static FileSystemDirent* readdir(FileSystemNode *node, uint32 index)
{
    //when node is the root of mounted filesystem,
    //node->mountSource is the source node (eg. disk partition /dev/hd1p1)

    //Screen_PrintF("readdir1: node->name:%s\n", node->name);

    uint8 targetPath[128];

    FileSystemNode *n = node;
    int charIndex = 126;
    memset(targetPath, 0, 128);
    while (NULL == n->mountSource)
    {
        int length = strlen(n->name);

        charIndex -= length;

        if (charIndex < 2)
        {
            return NULL;
        }

        strcpyNonNull((char*)(targetPath + charIndex), n->name);
        charIndex -= 1;
        targetPath[charIndex] = '/';

        n = n->parent;
    }

    char number[8];
    sprintf(number, "%d", n->privateNodeData);//volume nuber

    targetPath[charIndex] = ':';
    int length = strlen(number);
    charIndex -= length;
    if (charIndex < 0)
    {
        return NULL;
    }

    strcpyNonNull((char*)(targetPath + charIndex), number);
    uint8* target = targetPath + charIndex;

    //Screen_PrintF("readdir: targetpath:[%s]\n", target);

    DIR dir;
    FRESULT fr = f_opendir(&dir, (TCHAR*)target);
    if (FR_OK == fr)
    {
        FILINFO fileInfo;
        for (int i = 0; i <= index; ++i)
        {
            memset((uint8*)&fileInfo, 0, sizeof(FILINFO));
            fr = f_readdir(&dir, &fileInfo);

            if (strlen(fileInfo.fname) <= 0)
            {
                f_closedir(&dir);

                return NULL;
            }
        }

        gFileSystemDirent.inode = 0;
        strcpy(gFileSystemDirent.name, fileInfo.fname);
        if ((fileInfo.fattrib & AM_DIR) == AM_DIR)
        {
            gFileSystemDirent.fileType = FT_Directory;
        }
        else
        {
            gFileSystemDirent.fileType = FT_File;
        }

        f_closedir(&dir);

        return &gFileSystemDirent;
    }

    return NULL;
}

static FileSystemNode* finddir(FileSystemNode *node, char *name)
{
    //when node is the root of mounted filesystem,
    //node->mountSource is the source node (eg. disk partition /dev/hd1p1)

    //Screen_PrintF("finddir1: node->name:%s name:%s\n", node->name, name);

    FileSystemNode* child = node->firstChild;
    while (NULL != child)
    {
        if (strcmp(name, child->name) == 0)
        {
            return child;
        }

        child = child->nextSibling;
    }

    //If we are here, this file is accesed first time in this session.
    //So we create its node...

    uint8 targetPath[128];

    FileSystemNode *n = node;
    int charIndex = 126;
    memset(targetPath, 0, 128);
    int length = strlen(name);
    charIndex -= length;
    strcpyNonNull((char*)(targetPath + charIndex), name);
    charIndex -= 1;
    targetPath[charIndex] = '/';
    while (NULL == n->mountSource)
    {
        length = strlen(n->name);
        charIndex -= length;

        if (charIndex < 2)
        {
            return NULL;
        }

        strcpyNonNull((char*)(targetPath + charIndex), n->name);
        charIndex -= 1;
        targetPath[charIndex] = '/';

        n = n->parent;
    }

    char number[8];
    sprintf(number, "%d", n->privateNodeData);//volume nuber

    targetPath[charIndex] = ':';
    length = strlen(number);
    charIndex -= length;
    if (charIndex < 0)
    {
        return NULL;
    }

    strcpyNonNull((char*)(targetPath + charIndex), number);
    uint8* target = targetPath + charIndex;

    //Screen_PrintF("finddir: targetpath:[%s]\n", target);

    FILINFO fileInfo;
    memset((uint8*)&fileInfo, 0, sizeof(FILINFO));
    FRESULT fr = f_stat((TCHAR*)target, &fileInfo);
    if (FR_OK == fr)
    {
        FileSystemNode* newNode = kmalloc(sizeof(FileSystemNode));

        memset((uint8*)newNode, 0, sizeof(FileSystemNode));
        strcpy(newNode->name, name);
        newNode->parent = node;
        newNode->readdir = readdir;
        newNode->finddir = finddir;
        newNode->open = open;
        newNode->close = close;
        newNode->read = read;
        newNode->write = write;
        newNode->lseek = lseek;
        newNode->stat = stat;
        newNode->length = fileInfo.fsize;

        if ((fileInfo.fattrib & AM_DIR) == AM_DIR)
        {
            newNode->nodeType = FT_Directory;
        }
        else
        {
            newNode->nodeType = FT_File;
        }

        if (NULL == node->firstChild)
        {
            node->firstChild = newNode;
        }
        else
        {
            FileSystemNode* child = node->firstChild;
            while (NULL != child->nextSibling)
            {
                child = child->nextSibling;
            }
            child->nextSibling = newNode;
        }

        //Screen_PrintF("finddir: returning [%s]\n", name);
        return newNode;
    }
    else
    {
        //Screen_PrintF("finddir error: fr: %d]\n", fr);
    }

    return NULL;
}

static int32 read(File *file, uint32 size, uint8 *buffer)
{
    if (file->privateData == NULL)
    {
        return -1;
    }

    FIL* f = (FIL*)file->privateData;

    UINT br = 0;
    FRESULT fr = f_read(f, buffer, size, &br);
    file->offset = f->fptr;
    //Screen_PrintF("fat read: name:%s size:%d hasRead:%d, fr:%d\n", file->node->name, size, br, fr);
    if (FR_OK == fr)
    {
        return br;
    }

    return -1;
}

static int32 write(File *file, uint32 size, uint8 *buffer)
{
    if (file->privateData == NULL)
    {
        return -1;
    }

    FIL* f = (FIL*)file->privateData;

    UINT bw = 0;
    FRESULT fr = f_write(f, buffer, size, &bw);
    file->offset = f->fptr;
    if (FR_OK == fr)
    {
        return bw;
    }

    return -1;
}

static int32 lseek(File *file, int32 offset, int32 whence)
{
    if (file->privateData == NULL)
    {
        return -1;
    }

    FIL* f = (FIL*)file->privateData;

    FRESULT fr = FR_INVALID_OBJECT;

    switch (whence)
    {
    case SEEK_SET:
        fr = f_lseek(f, offset);
        break;
    case SEEK_CUR:
        fr = f_lseek(f, f_tell(f) + offset);
        break;
    case SEEK_END:
        fr = f_lseek(f, f_size(f) + offset);
        break;
    default:
        break;
    }


    if (FR_OK == fr)
    {
        file->offset = f->fptr;

        return file->offset;
    }

    return -1;
}

static int32 stat(FileSystemNode *node, struct stat* buf)
{
    //Screen_PrintF("fat stat [%s]\n", node->name);

    uint8 targetPath[128];

    FileSystemNode *n = node;
    int charIndex = 126;
    memset(targetPath, 0, 128);
    while (NULL == n->mountSource)
    {
        int length = strlen(n->name);
        charIndex -= length;

        if (charIndex < 2)
        {
            return NULL;
        }

        strcpyNonNull((char*)(targetPath + charIndex), n->name);
        charIndex -= 1;
        targetPath[charIndex] = '/';

        n = n->parent;
    }

    char number[8];
    sprintf(number, "%d", n->privateNodeData);//volume nuber

    targetPath[charIndex] = ':';
    int length = strlen(number);
    charIndex -= length;
    if (charIndex < 0)
    {
        return NULL;
    }

    strcpyNonNull((char*)(targetPath + charIndex), number);
    uint8* target = targetPath + charIndex;

    //Screen_PrintF("fat stat target:[%s]\n", target);

    FILINFO fileInfo;
    memset((uint8*)&fileInfo, 0, sizeof(FILINFO));
    FRESULT fr = f_stat((TCHAR*)target, &fileInfo);
    if (FR_OK == fr)
    {
        if ((fileInfo.fattrib & AM_DIR) == AM_DIR)
        {
            node->nodeType = FT_Directory;
        }
        else
        {
            node->nodeType = FT_File;
        }

        node->length = fileInfo.fsize;

        return 1;
    }

    return -1; //Error
}

static BOOL open(File *file, uint32 flags)
{
    //Screen_PrintF("fat open %s\n", file->node->name);

    FileSystemNode *node = file->node;

    if (node->nodeType == FT_Directory)
    {
        return TRUE;
    }

    uint8 targetPath[128];

    FileSystemNode *n = node;
    int charIndex = 126;
    memset(targetPath, 0, 128);
    while (NULL == n->mountSource)
    {
        int length = strlen(n->name);
        charIndex -= length;

        if (charIndex < 2)
        {
            return NULL;
        }

        strcpyNonNull((char*)(targetPath + charIndex), n->name);
        charIndex -= 1;
        targetPath[charIndex] = '/';

        n = n->parent;
    }

    char number[8];
    sprintf(number, "%d", n->privateNodeData);//volume nuber

    targetPath[charIndex] = ':';
    int length = strlen(number);
    charIndex -= length;
    if (charIndex < 0)
    {
        return NULL;
    }

    strcpyNonNull((char*)(targetPath + charIndex), number);
    uint8* target = targetPath + charIndex;

    //Screen_PrintF("fat open %s\n", target);

    int fatfsMode = FA_READ;

    switch (flags)
    {
    case O_RDONLY:
        fatfsMode = FA_READ;
        break;
    case O_WRONLY:
        fatfsMode = FA_WRITE;
        break;
    case O_RDWR:
        fatfsMode = (FA_READ | FA_WRITE);
        break;
        //TODO: append, create
    default:
        break;
    }

    FIL* f = (FIL*)kmalloc(sizeof(FIL));
    FRESULT fr = f_open(f, (TCHAR*)target, fatfsMode);
    if (FR_OK == fr)
    {
        file->offset = f->fptr;

        file->privateData = f;

        return TRUE;
    }

    return FALSE;
}

static void close(File *file)
{
    if (file->privateData == NULL)
    {
        return;
    }

    FIL* f = (FIL*)file->privateData;

    f_close(f);

    kfree(f);

    file->privateData = NULL;
}

DSTATUS disk_initialize(
        BYTE pdrv		//Physical drive nmuber
)
{
    return 0;
}

DSTATUS disk_status(BYTE pdrv)
{
    return 0;
}

DRESULT disk_read (
    BYTE pdrv,			/* Physical drive nmuber (0) */
    BYTE *buff,			/* Pointer to the data buffer to store read data */
    DWORD sector,		/* Start sector number (LBA) */
    UINT count			/* Number of sectors to read */
)
{
    //Screen_PrintF("disk_read() drv:%d sector:%d count:%d\n", pdrv, sector, count);

    if (gMountedBlockDevices[pdrv] == NULL) return RES_NOTRDY;

    //if (sector >= RamDiskSize) return RES_PARERR;

    gMountedBlockDevices[pdrv]->readBlock(gMountedBlockDevices[pdrv], (uint32)sector, count, buff);

    return RES_OK;
}

DRESULT disk_write (
    BYTE pdrv,			/* Physical drive nmuber (0) */
    const BYTE *buff,	/* Pointer to the data to be written */
    DWORD sector,		/* Start sector number (LBA) */
    UINT count			/* Number of sectors to write */
)
{
    if (gMountedBlockDevices[pdrv] == NULL) return RES_NOTRDY;

    //if (sector >= RamDiskSize) return RES_PARERR;

    gMountedBlockDevices[pdrv]->writeBlock(gMountedBlockDevices[pdrv], (uint32)sector, count, (uint8*)buff);

    return RES_OK;
}

DRESULT disk_ioctl (
    BYTE pdrv,		/* Physical drive nmuber (0) */
    BYTE ctrl,		/* Control code */
    void* buff		/* Buffer to send/receive data block */
)
{
    if (gMountedBlockDevices[pdrv] == NULL) return RES_ERROR;

    DRESULT dr = RES_ERROR;

    File* f = NULL;

    uint32 value = 0;

    switch (ctrl)
    {
    case CTRL_SYNC:
        dr = RES_OK;
        break;
    case GET_SECTOR_COUNT:
        f = open_fs(gMountedBlockDevices[pdrv], 0);
        if (f)
        {
            ioctl_fs(f, IC_GetSectorCount, &value);
            *(DWORD*)buff = value;
            dr = RES_OK;
            close_fs(f);
        }
        printkf("disk_ioctl GET_SECTOR_COUNT: %d\n", value);
        break;
    case GET_BLOCK_SIZE:
        f = open_fs(gMountedBlockDevices[pdrv], 0);
        if (f)
        {
            ioctl_fs(f, IC_GetSectorSizeInBytes, &value);
            *(DWORD*)buff = value;
            dr = RES_OK;
            close_fs(f);
        }
        printkf("disk_ioctl GET_BLOCK_SIZE: %d\n", value);
        *(DWORD*)buff = value;
        dr = RES_OK;
        break;
    }
    return dr;
}
