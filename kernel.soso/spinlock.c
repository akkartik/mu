#include "spinlock.h"

static inline int32 exchangeAtomic(volatile int32* oldValueAddress, int32 newValue)
{
    //no need to use lock instruction on xchg

    asm volatile ("xchgl %0, %1"
                   : "=r"(newValue)
                   : "m"(*oldValueAddress), "0"(newValue)
                   : "memory");
    return newValue;
}

void Spinlock_Init(Spinlock* spinlock)
{
    *spinlock = 0;
}

void Spinlock_Lock(Spinlock* spinlock)
{
    while (exchangeAtomic((int32*)spinlock, 1))
    {
        halt();
    }
}

void Spinlock_Unlock(Spinlock* spinlock)
{
    *spinlock = 0;
}
