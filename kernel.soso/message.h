#ifndef MESSAGE_H
#define MESSAGE_H

#include "common.h"
#include "commonuser.h"

typedef struct Thread Thread;

void sendMesage(Thread* thread, SosoMessage* message);

uint32 getMessageQueueCount(Thread* thread);

//returns remaining message count
int32 getNextMessage(Thread* thread, SosoMessage* message);

#endif // MESSAGE_H
