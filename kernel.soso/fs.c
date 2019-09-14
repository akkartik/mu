#include "fs.h"
#include "alloc.h"
#include "screen.h"
#include "rootfs.h"

FileSystemNode *gFileSystemRoot = NULL; // The root of the filesystem.

#define FILESYSTEM_CAPACITY 10

static FileSystem gRegisteredFileSystems[FILESYSTEM_CAPACITY];
static int gNextFileSystemIndex = 0;

void initializeVFS()
{
    memset((uint8*)gRegisteredFileSystems, 0, sizeof(gRegisteredFileSystems));

    gFileSystemRoot = initializeRootFS();

    mkdir_fs(gFileSystemRoot, "dev", 0);
    mkdir_fs(gFileSystemRoot, "initrd", 0);
}

FileSystemNode* getFileSystemRootNode()
{
    return gFileSystemRoot;
}

void copyFileDescriptors(Process* fromProcess, Process* toProcess)
{
    for (int i = 0; i < MAX_OPENED_FILES; ++i)
    {
        File* original = fromProcess->fd[i];

        if (original)
        {
            File* file = kmalloc(sizeof(File));
            memcpy((uint8*)file, (uint8*)original, sizeof(File));
            file->process = toProcess;
            file->thread = NULL;

            toProcess->fd[i] = file;

        }
    }
}

int getFileSystemNodePath(FileSystemNode *node, char* buffer, uint32 bufferSize)
{
    if (node == gFileSystemRoot)
    {
        if (bufferSize > 1)
        {
            buffer[0] = '/';
            buffer[1] = '\0';

            return 1;
        }
        else
        {
            return -1;
        }
    }

    char targetPath[128];

    FileSystemNode *n = node;
    int charIndex = 127;
    targetPath[charIndex] = '\0';
    while (NULL != n)
    {
        int length = strlen(n->name);
        charIndex -= length;

        if (charIndex < 2)
        {
            return -1;
        }

        if (NULL != n->parent)
        {
            strcpyNonNull(targetPath + charIndex, n->name);
            charIndex -= 1;
            targetPath[charIndex] = '/';
        }

        n = n->parent;
    }

    int len = 127 - charIndex;

    //Screen_PrintF("getFileSystemNodePath: len:[%s] %d\n", targetPath + charIndex, len);

    if (bufferSize < len)
    {
        return -1;
    }

    strcpy(buffer, targetPath + charIndex);

    return len;
}

BOOL resolvePath(const char* path, char* buffer, int bufferSize)
{
    int lengthPath = strlen(path);

    if (path[0] != '/')
    {
        return FALSE;
    }

    if (bufferSize < 2)
    {
        return FALSE;
    }

    buffer[0] = '/';
    buffer[1] = '\0';
    int index = 0;
    int indexBuffer = 1;

    while (index < lengthPath - 1)
    {
        while (path[++index] == '/');//eliminate successive

        const char* current = path + index;
        int nextIndex = strFirstIndexOf(path + index, '/');

        int lengthToken = 0;

        if (nextIndex >= 0)
        {
            const char* next = path + index + nextIndex;

            lengthToken = next - (path + index);
        }
        else
        {
            lengthToken = strlen(current);
        }

        if (lengthToken > 0)
        {
            index += lengthToken;
            if (strncmp(current, "..", 2) == 0)
            {
                --indexBuffer;
                while (indexBuffer > 0)
                {
                    --indexBuffer;

                    if (buffer[indexBuffer] == '/')
                    {
                        break;
                    }

                    buffer[indexBuffer] = '\0';
                }

                ++indexBuffer;
                continue;
            }
            else if (strncmp(current, ".", 1) == 0)
            {
                continue;
            }

            if (indexBuffer + lengthToken + 2 > bufferSize)
            {
                return FALSE;
            }

            strncpy(buffer + indexBuffer, current, lengthToken);
            indexBuffer += lengthToken;

            if (current[lengthToken] == '/')
            {
                buffer[indexBuffer++] = '/';
            }
            buffer[indexBuffer] = '\0';
        }
    }

    if (indexBuffer > 2)
    {
        if (buffer[indexBuffer - 1] == '/')
        {
            buffer[indexBuffer - 1] = '\0';
        }
    }

    return TRUE;
}

uint32 read_fs(File *file, uint32 size, uint8 *buffer)
{
    if (file->node->read != 0)
    {
        return file->node->read(file, size, buffer);
    }

    return -1;
}

uint32 write_fs(File *file, uint32 size, uint8 *buffer)
{
    if (file->node->write != 0)
    {
        return file->node->write(file, size, buffer);
    }

    return -1;
}

File *open_fs(FileSystemNode *node, uint32 flags)
{
    return open_fs_forProcess(getCurrentThread(), node, flags);
}

File *open_fs_forProcess(Thread* thread, FileSystemNode *node, uint32 flags)
{
    Process* process = thread->owner;

    if ( (node->nodeType & FT_MountPoint) == FT_MountPoint && node->mountPoint != NULL )
    {
        node = node->mountPoint;
    }

    if (node->open != NULL)
    {
        File* file = kmalloc(sizeof(File));
        memset((uint8*)file, 0, sizeof(File));
        file->node = node;
        file->process = process;
        file->thread = thread;

        BOOL success = node->open(file, flags);

        if (success)
        {
            //Screen_PrintF("Opened:%s\n", file->node->name);
            int32 fd = addFileToProcess(file->process, file);

            if (fd < 0)
            {
                //TODO: sett errno max files opened already
                printkf("Maxfiles opened already!!\n");

                close_fs(file);
                file = NULL;
            }
        }
        else
        {
            kfree(file);
        }

        return file;
    }

    return NULL;
}

void close_fs(File *file)
{
    if (file->node->close != NULL)
    {
        file->node->close(file);
    }

    removeFileFromProcess(file->process, file);

    kfree(file);
}

int32 ioctl_fs(File *file, int32 request, void * argp)
{
    if (file->node->ioctl != NULL)
    {
        return file->node->ioctl(file, request, argp);
    }

    return 0;
}

int32 lseek_fs(File *file, int32 offset, int32 whence)
{
    if (file->node->lseek != NULL)
    {
        return file->node->lseek(file, offset, whence);
    }

    return 0;
}

int32 ftruncate_fs(File* file, int32 length)
{
    if (file->node->ftruncate != NULL)
    {
        return file->node->ftruncate(file, length);
    }

    return -1;
}

int32 stat_fs(FileSystemNode *node, struct stat *buf)
{
#define	__S_IFDIR	0040000	/* Directory.  */
#define	__S_IFCHR	0020000	/* Character device.  */
#define	__S_IFBLK	0060000	/* Block device.  */
#define	__S_IFREG	0100000	/* Regular file.  */
#define	__S_IFIFO	0010000	/* FIFO.  */
#define	__S_IFLNK	0120000	/* Symbolic link.  */
#define	__S_IFSOCK	0140000	/* Socket.  */

    if (node->stat != NULL)
    {
        int32 val = node->stat(node, buf);

        if (val == 1)
        {
            //return value of 1 from driver means we should fill buf here.

            if ((node->nodeType & FT_Directory) == FT_Directory)
            {
                buf->st_mode = __S_IFDIR;
            }
            else if ((node->nodeType & FT_CharacterDevice) == FT_CharacterDevice)
            {
                buf->st_mode = __S_IFCHR;
            }
            else if ((node->nodeType & FT_BlockDevice) == FT_BlockDevice)
            {
                buf->st_mode = __S_IFBLK;
            }
            else if ((node->nodeType & FT_Pipe) == FT_Pipe)
            {
                buf->st_mode = __S_IFIFO;
            }
            else if ((node->nodeType & FT_SymbolicLink) == FT_SymbolicLink)
            {
                buf->st_mode = __S_IFLNK;
            }
            else if ((node->nodeType & FT_File) == FT_File)
            {
                buf->st_mode = __S_IFREG;
            }

            buf->st_size = node->length;

            return 0;
        }
        else
        {
            return val;
        }
    }

    return -1;
}

FileSystemDirent *readdir_fs(FileSystemNode *node, uint32 index)
{
    //Screen_PrintF("readdir_fs: node->name:%s index:%d\n", node->name, index);

    if ( (node->nodeType & FT_MountPoint) == FT_MountPoint && node->mountPoint != NULL )
    {
        if (NULL == node->mountPoint->readdir)
        {
            WARNING("mounted fs does not have readdir!\n");
        }
        else
        {
            return node->mountPoint->readdir(node->mountPoint, index);
        }
    }
    else if ( (node->nodeType & FT_Directory) == FT_Directory && node->readdir != NULL )
    {
        return node->readdir(node, index);
    }

    return NULL;
}

FileSystemNode *finddir_fs(FileSystemNode *node, char *name)
{
    //Screen_PrintF("finddir_fs: name:%s\n", name);

    if ( (node->nodeType & FT_MountPoint) == FT_MountPoint && node->mountPoint != NULL )
    {
        if (NULL == node->mountPoint->finddir)
        {
            WARNING("mounted fs does not have finddir!\n");
        }
        else
        {
            return node->mountPoint->finddir(node->mountPoint, name);
        }
    }
    else if ( (node->nodeType & FT_Directory) == FT_Directory && node->finddir != NULL )
    {
        return node->finddir(node, name);
    }

    return NULL;
}

BOOL mkdir_fs(FileSystemNode *node, const char *name, uint32 flags)
{
    if ( (node->nodeType & FT_MountPoint) == FT_MountPoint && node->mountPoint != NULL )
    {
        if (node->mountPoint->mkdir)
        {
            return node->mountPoint->mkdir(node->mountPoint, name, flags);
        }
    }
    else if ( (node->nodeType & FT_Directory) == FT_Directory && node->mkdir != NULL )
    {
        return node->mkdir(node, name, flags);
    }

    return FALSE;
}

void* mmap_fs(File* file, uint32 size, uint32 offset, uint32 flags)
{
    if (file->node->mmap)
    {
        return file->node->mmap(file, size, offset, flags);
    }

    return NULL;
}

BOOL munmap_fs(File* file, void* address, uint32 size)
{
    if (file->node->munmap)
    {
        return file->node->munmap(file, address, size);
    }

    return FALSE;
}

FileSystemNode *getFileSystemNode(const char *path)
{
    //Screen_PrintF("getFileSystemNode:%s *0\n", path);

    if (path[0] != '/')
    {
        //We require absolute path!
        return NULL;
    }


    char realPath[256];

    BOOL resolved = resolvePath(path, realPath, 256);

    if (FALSE == resolved)
    {
        return NULL;
    }

    const char* inputPath = realPath;
    int pathLength = strlen(inputPath);

    if (pathLength < 1)
    {
        return NULL;
    }



    //Screen_PrintF("getFileSystemNode:%s *1\n", path);

    FileSystemNode* root = getFileSystemRootNode();

    if (pathLength == 1)
    {
        return root;
    }

    int nextIndex = 0;

    FileSystemNode* node = root;

    //Screen_PrintF("getFileSystemNode:%s *2\n", path);

    char buffer[64];

    do
    {
        do_start:
        inputPath = inputPath + nextIndex + 1;
        nextIndex = strFirstIndexOf(inputPath, '/');

        if (nextIndex == 0)
        {
            //detected successive slash
            goto do_start;
        }

        if (nextIndex > 0)
        {
            int tokenSize = nextIndex;

            strncpy(buffer, inputPath, tokenSize);
            buffer[tokenSize] = '\0';
        }
        else
        {
            //Last part
            strcpy(buffer, inputPath);
        }

        //Screen_PrintF("getFileSystemNode:%s *3\n", path);

        node = finddir_fs(node, buffer);

        //Screen_PrintF("getFileSystemNode:%s *4\n", path);

        if (NULL == node)
        {
            return NULL;
        }

    } while (nextIndex > 0);

    return node;
}

FileSystemNode* getFileSystemNodeAbsoluteOrRelative(const char* path, Process* process)
{
    FileSystemNode* node = NULL;

    if (process)
    {
        if ('\0' == path[0])
        {
            //empty
        }
        else if ('/' == path[0])
        {
            //absolute

            node = getFileSystemNode(path);
        }
        else
        {
            //relative

            if (process->workingDirectory)
            {
                char buffer[256];

                if (getFileSystemNodePath(process->workingDirectory, buffer, 256) >= 0)
                {
                    strcat(buffer, "/");
                    strcat(buffer, path);

                    //Screen_PrintF("getFileSystemNodeAbsoluteOrRelative:[%s]\n", buffer);

                    node = getFileSystemNode(buffer);
                }
            }
        }
    }

    return node;
}

BOOL registerFileSystem(FileSystem* fs)
{
    if (strlen(fs->name) <= 0)
    {
        return FALSE;
    }

    for (int i = 0; i < gNextFileSystemIndex; ++i)
    {
        if (strcmp(gRegisteredFileSystems[i].name, fs->name) == 0)
        {
            //name is in use
            return FALSE;
        }
    }

    gRegisteredFileSystems[gNextFileSystemIndex++] = *fs;

    return TRUE;
}

BOOL mountFileSystem(const char *source, const char *target, const char *fsType, uint32 flags, void *data)
{
    FileSystem* fs = NULL;

    for (int i = 0; i < gNextFileSystemIndex; ++i)
    {
        if (strcmp(gRegisteredFileSystems[i].name, fsType) == 0)
        {
            fs = &gRegisteredFileSystems[i];
            break;
        }
    }

    if (NULL == fs)
    {
        return FALSE;
    }

    return fs->mount(source, target, flags, data);
}

BOOL checkMountFileSystem(const char *source, const char *target, const char *fsType, uint32 flags, void *data)
{
    FileSystem* fs = NULL;

    for (int i = 0; i < gNextFileSystemIndex; ++i)
    {
        if (strcmp(gRegisteredFileSystems[i].name, fsType) == 0)
        {
            fs = &gRegisteredFileSystems[i];
            break;
        }
    }

    if (NULL == fs)
    {
        return FALSE;
    }

    return fs->checkMount(source, target, flags, data);
}
