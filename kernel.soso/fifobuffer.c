#include "fifobuffer.h"
#include "alloc.h"

FifoBuffer* FifoBuffer_create(uint32 capacity)
{
    FifoBuffer* fifo = (FifoBuffer*)kmalloc(sizeof(FifoBuffer));
    memset((uint8*)fifo, 0, sizeof(FifoBuffer));
    fifo->data = (uint8*)kmalloc(capacity);
    memset((uint8*)fifo->data, 0, capacity);
    fifo->capacity= capacity;

    return fifo;
}

void FifoBuffer_destroy(FifoBuffer* fifoBuffer)
{
    kfree(fifoBuffer->data);
    kfree(fifoBuffer);
}

void FifoBuffer_clear(FifoBuffer* fifoBuffer)
{
    fifoBuffer->usedBytes = 0;
    fifoBuffer->readIndex = 0;
    fifoBuffer->writeIndex = 0;
}

BOOL FifoBuffer_isEmpty(FifoBuffer* fifoBuffer)
{
    if (0 == fifoBuffer->usedBytes)
    {
        return TRUE;
    }

    return FALSE;
}

uint32 FifoBuffer_getSize(FifoBuffer* fifoBuffer)
{
    return fifoBuffer->usedBytes;
}

uint32 FifoBuffer_getCapacity(FifoBuffer* fifoBuffer)
{
    return fifoBuffer->capacity;
}

uint32 FifoBuffer_getFree(FifoBuffer* fifoBuffer)
{
    return fifoBuffer->capacity - fifoBuffer->usedBytes;
}

int32 FifoBuffer_enqueue(FifoBuffer* fifoBuffer, uint8* data, uint32 size)
{
    if (size == 0)
    {
        return -1;
    }

    uint32 bytesAvailable = fifoBuffer->capacity - fifoBuffer->usedBytes;

    if (size > bytesAvailable)
    {
        return -1;
    }

    uint32 i = 0;
    while (fifoBuffer->usedBytes < fifoBuffer->capacity && i < size)
    {
        fifoBuffer->data[fifoBuffer->writeIndex] = data[i++];
        fifoBuffer->usedBytes++;
        fifoBuffer->writeIndex++;
        fifoBuffer->writeIndex %= fifoBuffer->capacity;
    }

    return size;
}

int32 FifoBuffer_dequeue(FifoBuffer* fifoBuffer, uint8* data, uint32 size)
{
    if (size == 0)
    {
        return -1;
    }

    if (0 == fifoBuffer->usedBytes)
    {
        //Buffer is empty
        return 0;
    }

    uint32 i = 0;
    while (fifoBuffer->usedBytes > 0 && i < size)
    {
        data[i++] = fifoBuffer->data[fifoBuffer->readIndex];
        fifoBuffer->usedBytes--;
        fifoBuffer->readIndex++;
        fifoBuffer->readIndex %= fifoBuffer->capacity;
    }

    return i;
}
