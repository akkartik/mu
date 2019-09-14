#ifndef FIFOBUFFER_H
#define FIFOBUFFER_H

#include "common.h"

typedef struct FifoBuffer
{
    uint8* data;
    uint32 writeIndex;
    uint32 readIndex;
    uint32 capacity;
    uint32 usedBytes;
} FifoBuffer;

FifoBuffer* FifoBuffer_create(uint32 capacity);
void FifoBuffer_destroy(FifoBuffer* fifoBuffer);
void FifoBuffer_clear(FifoBuffer* fifoBuffer);
BOOL FifoBuffer_isEmpty(FifoBuffer* fifoBuffer);
uint32 FifoBuffer_getSize(FifoBuffer* fifoBuffer);
uint32 FifoBuffer_getCapacity(FifoBuffer* fifoBuffer);
uint32 FifoBuffer_getFree(FifoBuffer* fifoBuffer);
int32 FifoBuffer_enqueue(FifoBuffer* fifoBuffer, uint8* data, uint32 size);
int32 FifoBuffer_dequeue(FifoBuffer* fifoBuffer, uint8* data, uint32 size);

#endif // FIFOBUFFER_H
