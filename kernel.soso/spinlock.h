#ifndef SPINLOCK_H
#define SPINLOCK_H

#include "common.h"

typedef int32 Spinlock;

void Spinlock_Init(Spinlock* spinlock);
void Spinlock_Lock(Spinlock* spinlock);
void Spinlock_Unlock(Spinlock* spinlock);

#endif // SPINLOCK_H
