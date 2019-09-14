#ifndef PIPE_H
#define PIPE_H

#include "common.h"

void initializePipes();
BOOL createPipe(const char* name, uint32 bufferSize);
BOOL destroyPipe(const char* name);
BOOL existsPipe(const char* name);

#endif // PIPE_H
