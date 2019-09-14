#include "message.h"
#include "process.h"
#include "fifobuffer.h"


void sendMesage(Thread* thread, SosoMessage* message)
{
    Spinlock_Lock(&(thread->messageQueueLock));

    FifoBuffer_enqueue(thread->messageQueue, (uint8*)message, sizeof(SosoMessage));

    Spinlock_Unlock(&(thread->messageQueueLock));
}

uint32 getMessageQueueCount(Thread* thread)
{
    int result = 0;

    Spinlock_Lock(&(thread->messageQueueLock));

    result = FifoBuffer_getSize(thread->messageQueue) / sizeof(SosoMessage);

    Spinlock_Unlock(&(thread->messageQueueLock));

    return result;
}

//returns remaining message count
int32 getNextMessage(Thread* thread, SosoMessage* message)
{
    uint32 result = -1;

    Spinlock_Lock(&(thread->messageQueueLock));

    result = FifoBuffer_getSize(thread->messageQueue) / sizeof(SosoMessage);

    if (result > 0)
    {
        FifoBuffer_dequeue(thread->messageQueue, (uint8*)message, sizeof(SosoMessage));

        --result;
    }
    else
    {
        result = -1;
    }

    Spinlock_Unlock(&(thread->messageQueueLock));

    return result;
}
