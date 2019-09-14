#ifndef ALLOC_H
#define ALLOC_H

#include "common.h"
#include "process.h"

void initializeKernelHeap();
void *ksbrkPage(int n);
void *kmalloc(uint32 size);
void kfree(void *v_addr);

void initializeProcessHeap(Process* process);
void *sbrk(Process* process, int nBytes);

uint32 getKernelHeapUsed();

struct MallocHeader
{
    unsigned long size:31;
    unsigned long used:1;
} __attribute__ ((packed));

typedef struct MallocHeader MallocHeader;

#endif // ALLOC_H
