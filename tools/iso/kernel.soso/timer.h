#ifndef TIMER_H
#define TIMER_H

#include "common.h"

void initializeTimer();
uint32 getSystemTickCount();
uint32 getUptimeSeconds();
uint32 getUptimeMilliseconds();
void enableScheduler();
void disableScheduler();

#endif
