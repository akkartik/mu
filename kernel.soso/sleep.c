#include "sleep.h"
#include "timer.h"

void sleepMilliseconds(Thread* thread, uint32 ms)
{
    uint32 uptime = getUptimeMilliseconds();

    //target uptime to wakeup
    uint32 target = uptime + ms;

    thread->state = TS_SLEEP;
    thread->state_privateData = (void*)target;

    enableInterrupts();

    halt();
}
