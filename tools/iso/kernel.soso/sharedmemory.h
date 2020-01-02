#ifndef SHAREDMEMORY_H
#define SHAREDMEMORY_H

#include "common.h"
#include "fs.h"

void initializeSharedMemory();
FileSystemNode* createSharedMemory(const char* name);
void destroySharedMemory(const char* name);
FileSystemNode* getSharedMemoryNode(const char* name);

#endif // SHAREDMEMORY_H
