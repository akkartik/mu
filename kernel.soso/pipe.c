#include "list.h"
#include "pipe.h"
#include "fs.h"
#include "alloc.h"
#include "fifobuffer.h"

static List* gPipeList = NULL;

static FileSystemNode* gPipesRoot = NULL;

static FileSystemDirent gDirent;

typedef struct Pipe
{
    char name[32];
    FifoBuffer* buffer;
    FileSystemNode* fsNode;
    List* accessingThreads;
} Pipe;

static BOOL pipes_open(File *file, uint32 flags);
static FileSystemDirent *pipes_readdir(FileSystemNode *node, uint32 index);
static FileSystemNode *pipes_finddir(FileSystemNode *node, char *name);

void initializePipes()
{
    gPipeList = List_Create();

    gPipesRoot = getFileSystemNode("/system/pipes");

    if (NULL == gPipesRoot)
    {
        WARNING("/system/pipes not found!!");
    }
    else
    {
        gPipesRoot->open = pipes_open;
        gPipesRoot->finddir = pipes_finddir;
        gPipesRoot->readdir = pipes_readdir;
    }
}

static BOOL pipes_open(File *file, uint32 flags)
{
    return TRUE;
}

static FileSystemDirent *pipes_readdir(FileSystemNode *node, uint32 index)
{
    int counter = 0;

    List_Foreach (n, gPipeList)
    {
        Pipe* p = (Pipe*)n->data;

        if (counter == index)
        {
            strcpy(gDirent.name, p->name);
            gDirent.fileType = FT_Pipe;

            return &gDirent;
        }
        ++counter;
    }

    return NULL;
}

static FileSystemNode *pipes_finddir(FileSystemNode *node, char *name)
{
    List_Foreach (n, gPipeList)
    {
        Pipe* p = (Pipe*)n->data;

        if (strcmp(name, p->name) == 0)
        {
            return p->fsNode;
        }
    }

    return NULL;
}

static BOOL pipe_open(File *file, uint32 flags)
{
    beginCriticalSection();

    Pipe* pipe = file->node->privateNodeData;

    List_Append(pipe->accessingThreads, file->thread);

    endCriticalSection();

    return TRUE;
}

static void pipe_close(File *file)
{
    beginCriticalSection();

    Pipe* pipe = file->node->privateNodeData;

    List_RemoveFirstOccurrence(pipe->accessingThreads, file->thread);

    endCriticalSection();
}

static void blockAccessingThreads(Pipe* pipe)
{
    disableInterrupts();

    List_Foreach (n, pipe->accessingThreads)
    {
        Thread* reader = n->data;

        reader->state = TS_WAITIO;

        reader->state_privateData = pipe;
    }

    enableInterrupts();

    halt();
}

static void wakeupAccessingThreads(Pipe* pipe)
{
    beginCriticalSection();

    List_Foreach (n, pipe->accessingThreads)
    {
        Thread* reader = n->data;

        if (reader->state == TS_WAITIO)
        {
            if (reader->state_privateData == pipe)
            {
                reader->state = TS_RUN;
            }
        }
    }

    endCriticalSection();
}

static int32 pipe_read(File *file, uint32 size, uint8 *buffer)
{
    if (0 == size || NULL == buffer)
    {
        return -1;
    }

    Pipe* pipe = file->node->privateNodeData;

    uint32 used = 0;
    while ((used = FifoBuffer_getSize(pipe->buffer)) < size)
    {
        blockAccessingThreads(pipe);
    }

    disableInterrupts();

    int32 readBytes = FifoBuffer_dequeue(pipe->buffer, buffer, size);

    wakeupAccessingThreads(pipe);

    return readBytes;
}

static int32 pipe_write(File *file, uint32 size, uint8 *buffer)
{
    if (0 == size || NULL == buffer)
    {
        return -1;
    }

    Pipe* pipe = file->node->privateNodeData;

    uint32 free = 0;
    while ((free = FifoBuffer_getFree(pipe->buffer)) < size)
    {
        blockAccessingThreads(pipe);
    }

    disableInterrupts();

    int32 bytesWritten = FifoBuffer_enqueue(pipe->buffer, buffer, size);

    wakeupAccessingThreads(pipe);

    return bytesWritten;
}

BOOL createPipe(const char* name, uint32 bufferSize)
{
    List_Foreach (n, gPipeList)
    {
        Pipe* p = (Pipe*)n->data;
        if (strcmp(name, p->name) == 0)
        {
            return FALSE;
        }
    }

    Pipe* pipe = (Pipe*)kmalloc(sizeof(Pipe));
    memset((uint8*)pipe, 0, sizeof(Pipe));

    strcpy(pipe->name, name);
    pipe->buffer = FifoBuffer_create(bufferSize);

    pipe->accessingThreads = List_Create();

    pipe->fsNode = (FileSystemNode*)kmalloc(sizeof(FileSystemNode));
    memset((uint8*)pipe->fsNode, 0, sizeof(FileSystemNode));
    pipe->fsNode->privateNodeData = pipe;
    pipe->fsNode->open = pipe_open;
    pipe->fsNode->close = pipe_close;
    pipe->fsNode->read = pipe_read;
    pipe->fsNode->write = pipe_write;

    List_Append(gPipeList, pipe);

    return TRUE;
}

BOOL destroyPipe(const char* name)
{
    List_Foreach (n, gPipeList)
    {
        Pipe* p = (Pipe*)n->data;
        if (strcmp(name, p->name) == 0)
        {
            List_RemoveFirstOccurrence(gPipeList, p);
            FifoBuffer_destroy(p->buffer);
            List_Destroy(p->accessingThreads);
            kfree(p->fsNode);
            kfree(p);

            return TRUE;
        }
    }

    return FALSE;
}

BOOL existsPipe(const char* name)
{
    List_Foreach (n, gPipeList)
    {
        Pipe* p = (Pipe*)n->data;
        if (strcmp(name, p->name) == 0)
        {
            return TRUE;
        }
    }

    return FALSE;
}
