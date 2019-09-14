#include "rootfs.h"
#include "alloc.h"

static BOOL rootfs_open(File *node, uint32 flags);
static void rootfs_close(File *file);
static FileSystemNode *rootfs_finddir(FileSystemNode *node, char *name);
static struct FileSystemDirent *rootfs_readdir(FileSystemNode *node, uint32 index);
static BOOL rootfs_mkdir(FileSystemNode *node, const char *name, uint32 flags);

FileSystemNode* initializeRootFS()
{
    FileSystemNode* root = (FileSystemNode*)kmalloc(sizeof(FileSystemNode));
    memset((uint8*)root, 0, sizeof(FileSystemNode));
    root->nodeType = FT_Directory;
    root->open = rootfs_open;
    root->close = rootfs_close;
    root->readdir = rootfs_readdir;
    root->finddir = rootfs_finddir;
    root->mkdir = rootfs_mkdir;

    return root;
}

static FileSystemDirent gDirent;

static BOOL rootfs_open(File *node, uint32 flags)
{
    return TRUE;
}

static void rootfs_close(File *file)
{

}

static struct FileSystemDirent *rootfs_readdir(FileSystemNode *node, uint32 index)
{
    FileSystemNode *n = node->firstChild;
    uint32 i = 0;
    while (NULL != n)
    {
        if (index == i)
        {
            gDirent.fileType = n->nodeType;
            gDirent.inode = n->inode;
            strcpy(gDirent.name, n->name);

            return &gDirent;
        }
        n = n->nextSibling;
        ++i;
    }

    return NULL;
}

static FileSystemNode *rootfs_finddir(FileSystemNode *node, char *name)
{
    FileSystemNode *n = node->firstChild;
    while (NULL != n)
    {
        if (strcmp(name, n->name) == 0)
        {
            return n;
        }
        n = n->nextSibling;
    }

    return NULL;
}

static BOOL rootfs_mkdir(FileSystemNode *node, const char *name, uint32 flags)
{
    FileSystemNode *n = node->firstChild;
    while (NULL != n)
    {
        if (strcmp(name, n->name) == 0)
        {
            return FALSE;
        }
        n = n->nextSibling;
    }

    FileSystemNode* newNode = (FileSystemNode*)kmalloc(sizeof(FileSystemNode));
    memset((uint8*)newNode, 0, sizeof(FileSystemNode));
    strcpy(newNode->name, name);
    newNode->nodeType = FT_Directory;
    newNode->open = rootfs_open;
    newNode->close = rootfs_close;
    newNode->readdir = rootfs_readdir;
    newNode->finddir = rootfs_finddir;
    newNode->mkdir = rootfs_mkdir;
    newNode->parent = node;

    if (node->firstChild == NULL)
    {
        node->firstChild = newNode;
    }
    else
    {
        FileSystemNode *n = node->firstChild;
        while (NULL != n->nextSibling)
        {
            n = n->nextSibling;
        }
        n->nextSibling = newNode;
    }

    return TRUE;
}

