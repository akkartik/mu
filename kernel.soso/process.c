#include "process.h"
#include "common.h"
#include "alloc.h"
#include "vmm.h"
#include "descriptortables.h"
#include "elf.h"
#include "screen.h"
#include "debugprint.h"
#include "isr.h"
#include "timer.h"
#include "message.h"

#define MESSAGE_QUEUE_SIZE 64

Process* gKernelProcess = NULL;

Thread* gFirstThread = NULL;
Thread* gCurrentThread = NULL;

Thread* gDestroyedThread = NULL;

uint32 gProcessIdGenerator = 0;
uint32 gThreadIdGenerator = 0;

uint32 gSystemContextSwitchCount = 0;
uint32 gLastUptimeSeconds = 0;

extern Tss gTss;

uint32 generateProcessId()
{
    return gProcessIdGenerator++;
}

uint32 generateThreadId()
{
    return gThreadIdGenerator++;
}

uint32 getSystemContextSwitchCount()
{
    return gSystemContextSwitchCount;
}

void initializeTasking()
{
    Process* process = (Process*)kmalloc(sizeof(Process));
    memset((uint8*)process, 0, sizeof(Process));
    strcpy(process->name, "[kernel]");
    process->pid = generateProcessId();
    process->pd = (uint32*) KERN_PAGE_DIRECTORY;
    process->workingDirectory = getFileSystemRootNode();

    gKernelProcess = process;


    Thread* thread = (Thread*)kmalloc(sizeof(Thread));
    memset((uint8*)thread, 0, sizeof(Thread));

    thread->owner = gKernelProcess;

    thread->threadId = generateThreadId();

    thread->userMode = 0;
    thread->state = TS_RUN;
    thread->messageQueue = FifoBuffer_create(sizeof(SosoMessage) * MESSAGE_QUEUE_SIZE);
    Spinlock_Init(&(thread->messageQueueLock));
    thread->regs.cr3 = (uint32) process->pd;

    uint32 selector = 0x10;

    thread->regs.ss = selector;
    thread->regs.eflags = 0x0;
    thread->regs.cs = 0x08;
    thread->regs.eip = NULL;
    thread->regs.ds = selector;
    thread->regs.es = selector;
    thread->regs.fs = selector;
    thread->regs.gs = selector;

    thread->regs.esp = 0; //no need because this is already main kernel thread. ESP will written to this in first schedule.

    thread->kstack.ss0 = 0x10;
    thread->kstack.esp0 = 0;//For kernel threads, this is not required


    gFirstThread = thread;
    gCurrentThread = thread;
}

static int getStringArrayItemCount(char *const array[])
{
    if (NULL == array)
    {
        return 0;
    }

    int i = 0;
    const char* a = array[0];
    while (NULL != a)
    {
        a = array[++i];
    }

    return i;
}

static char** cloneStringArray(char *const array[])
{
    int itemCount = getStringArrayItemCount(array);

    char** newArray = kmalloc(sizeof(char*) * (itemCount + 1));

    for (int i = 0; i < itemCount; ++i)
    {
        const char* str = array[i];
        int len = strlen(str);

        char* newStr = kmalloc(len + 1);
        strcpy(newStr, str);

        newArray[i] = newStr;
    }

    newArray[itemCount] = NULL;

    return newArray;
}

static void destroyStringArray(char** array)
{
    char* a = array[0];

    int i = 0;

    while (NULL != a)
    {
        kfree(a);

        a = array[++i];
    }

    kfree(array);
}

//This function must be called within the correct page directory for target process
static void copyArgvEnvToProcess(char *const argv[], char *const envp[])
{
    char** destination = (char**)USER_ARGV_ENV_LOC;
    int destinationIndex = 0;

    //Screen_PrintF("ARGVENV: destination:%x\n", destination);

    int argvCount = getStringArrayItemCount(argv);
    int envpCount = getStringArrayItemCount(envp);

    //Screen_PrintF("ARGVENV: argvCount:%d envpCount:%d\n", argvCount, envpCount);

    char* stringTable = (char*)USER_ARGV_ENV_LOC + sizeof(char*) * (argvCount + envpCount + 2);

    //Screen_PrintF("ARGVENV: stringTable:%x\n", stringTable);

    for (int i = 0; i < argvCount; ++i)
    {
        strcpy(stringTable, argv[i]);

        destination[destinationIndex] = stringTable;

        stringTable += strlen(argv[i]) + 2;

        destinationIndex++;
    }

    destination[destinationIndex++] = NULL;

    for (int i = 0; i < envpCount; ++i)
    {
        strcpy(stringTable, envp[i]);

        destination[destinationIndex] = stringTable;

        stringTable += strlen(envp[i]) + 2;

        destinationIndex++;
    }

    destination[destinationIndex++] = NULL;
}

Process* createUserProcessFromElfData(const char* name, uint8* elfData, char *const argv[], char *const envp[], Process* parent, FileSystemNode* tty)
{
    return createUserProcessEx(name, generateProcessId(), generateThreadId(), NULL, elfData, argv, envp, parent, tty);
}

Process* createUserProcessEx(const char* name, uint32 processId, uint32 threadId, Function0 func, uint8* elfData, char *const argv[], char *const envp[], Process* parent, FileSystemNode* tty)
{
    printkf("createUserProcessEx: %s %d %d\n", name, processId, threadId);
    if (0 == processId)
    {
        processId = generateProcessId();
    }

    if (0 == threadId)
    {
        threadId = generateThreadId();
    }

    Process* process = (Process*)kmalloc(sizeof(Process));
    memset((uint8*)process, 0, sizeof(Process));
    strcpy(process->name, name);
    process->pid = processId;
    process->pd = createPd();//our page directories are identity mapped so this is also a physical address.
    process->workingDirectory = getFileSystemRootNode();

    Thread* thread = (Thread*)kmalloc(sizeof(Thread));
    memset((uint8*)thread, 0, sizeof(Thread));

    thread->owner = process;

    thread->threadId = threadId;

    thread->userMode = 1;

    thread->state = TS_RUN;

    thread->messageQueue = FifoBuffer_create(sizeof(SosoMessage) * MESSAGE_QUEUE_SIZE);
    Spinlock_Init(&(thread->messageQueueLock));

    thread->regs.cr3 = (uint32) process->pd;

    //Since stack grows backwards, we must allocate previous page. So lets substract a small amount.
    uint32 stackp = USER_STACK-4;

    if (parent)
    {
        process->parent = parent;

        process->workingDirectory = parent->workingDirectory;

        process->tty = parent->tty;
    }

    if (tty)
    {
        process->tty = tty;
    }

    char** newArgv = cloneStringArray(argv);
    char** newEnvp = cloneStringArray(envp);

    //Change memory view (page directory)
    asm("mov %0, %%eax; mov %%eax, %%cr3"::"m"(process->pd));

    initializeProcessHeap(process);

    initializeProcessMmap(process);

    copyArgvEnvToProcess(newArgv, newEnvp);

    destroyStringArray(newArgv);
    destroyStringArray(newEnvp);

    uint32 selector = 0x23;

    thread->regs.ss = selector;
    thread->regs.eflags = 0x0;
    thread->regs.cs = 0x1B;
    thread->regs.eip = (uint32)func;
    thread->regs.ds = selector;
    thread->regs.es = selector;
    thread->regs.fs = selector;
    thread->regs.gs = selector;

    thread->regs.esp = stackp;

    char* p_addr = getPageFrame4M();
    char* v_addr = (char *) (USER_STACK - PAGESIZE_4M);
    addPageToPd(process->pd, v_addr, p_addr, PG_USER);

    thread->kstack.ss0 = 0x10;
    uint8* stack = (uint8*)kmalloc(KERN_STACK_SIZE);
    thread->kstack.esp0 = (uint32)(stack + KERN_STACK_SIZE - 4);
    thread->kstack.stackStart = (uint32)stack;

    Thread* p = gCurrentThread;

    while (p->next != NULL)
    {
        p = p->next;
    }

    p->next = thread;

    if (elfData)
    {
        printkf("about to load ELF data\n");
        uint32 startLocation = loadElf((char*)elfData);

        if (startLocation > 0)
        {
            thread->regs.eip = startLocation;
        }
    }

    //Restore memory view (page directory)
    asm("mov %0, %%eax ;mov %%eax, %%cr3":: "m"(gCurrentThread->regs.cr3));

    open_fs_forProcess(thread, process->tty, 0);//0: standard input
    open_fs_forProcess(thread, process->tty, 0);//1: standard output
    open_fs_forProcess(thread, process->tty, 0);//2: standard error

    printkf("running process %d\n", process->pid);
    return process;
}

//This function should be called in interrupts disabled state
void destroyThread(Thread* thread)
{
    Spinlock_Lock(&(thread->messageQueueLock));

    //TODO: signal the process somehow
    Thread* previousThread = getPreviousThread(thread);
    if (NULL != previousThread)
    {
        previousThread->next = thread->next;

        kfree((void*)thread->kstack.stackStart);

        FifoBuffer_destroy(thread->messageQueue);

        Debug_PrintF("destroying thread %d\n", thread->threadId);

        kfree(thread);

        if (thread == gCurrentThread)
        {
            gCurrentThread = NULL;
        }
    }
    else
    {
        printkf("Could not find previous thread for thread %d\n", thread->threadId);
        PANIC("This should not be happened!\n");
    }
}

//This function should be called in interrupts disabled state
void destroyProcess(Process* process)
{
    Thread* thread = gFirstThread;
    Thread* previous = NULL;
    while (thread)
    {
        if (process == thread->owner)
        {
            if (NULL != previous)
            {
                previous->next = thread->next;

                kfree((void*)thread->kstack.stackStart);

                Spinlock_Lock(&(thread->messageQueueLock));
                FifoBuffer_destroy(thread->messageQueue);

                Debug_PrintF("destroying thread id:%d (owner process %d)\n", thread->threadId, process->pid);

                kfree(thread);

                if (thread == gCurrentThread)
                {
                    gCurrentThread = NULL;
                }

                thread = previous->next;
                continue;
            }
        }

        previous = thread;
        thread = thread->next;
    }

    //Cleanup opened files
    for (int i = 0; i < MAX_OPENED_FILES; ++i)
    {
        if (process->fd[i] != NULL)
        {
            close_fs(process->fd[i]);
        }
    }

    if (process->parent)
    {
        thread = gFirstThread;
        while (thread)
        {
            if (process->parent == thread->owner)
            {
                if (thread->state == TS_WAITCHILD)
                {
                    thread->state = TS_RUN;
                }
            }

            thread = thread->next;
        }
    }

    Debug_PrintF("destroying process %d\n", process->pid);

    destroyPd(process->pd);
    kfree(process);
}

void threadStateToString(ThreadState state, uint8* buffer, uint32 bufferSize)
{
    if (bufferSize < 1)
    {
        return;
    }

    buffer[0] = '\0';

    if (bufferSize < 10)
    {
        return;
    }

    switch (state)
    {
    case TS_RUN:
        strcpy((char*)buffer, "run");
        break;
    case TS_SLEEP:
        strcpy((char*)buffer, "sleep");
        break;
    case TS_SUSPEND:
        strcpy((char*)buffer, "suspend");
        break;
    case TS_WAITCHILD:
        strcpy((char*)buffer, "waitchild");
        break;
    case TS_WAITIO:
        strcpy((char*)buffer, "waitio");
        break;
    case TS_YIELD:
        strcpy((char*)buffer, "yield");
        break;
    default:
        break;
    }
}

void waitForSchedule()
{
    //Screen_PrintF("Waiting for a schedule()\n");

    enableInterrupts();
    while (TRUE)
    {
        halt();
    }
    disableInterrupts();
    PANIC("waitForSchedule(): Should not be reached here!!!\n");
}

void yield(uint32 count)
{
    gCurrentThread->yield = count;
    gCurrentThread->state = TS_YIELD;
    enableInterrupts();
    while (gCurrentThread->yield > 0)
    {
        halt();
    }
    disableInterrupts();
}

int32 getEmptyFd(Process* process)
{
    int32 result = -1;

    beginCriticalSection();

    for (int i = 0; i < MAX_OPENED_FILES; ++i)
    {
        if (process->fd[i] == NULL)
        {
            result = i;
            break;
        }
    }

    endCriticalSection();

    return result;
}

int32 addFileToProcess(Process* process, File* file)
{
    int32 result = -1;

    beginCriticalSection();

    //Screen_PrintF("addFileToProcess: pid:%d\n", process->pid);

    for (int i = 0; i < MAX_OPENED_FILES; ++i)
    {
        //Screen_PrintF("addFileToProcess: i:%d fd[%d]:%x\n", i, i, process->fd[i]);
        if (process->fd[i] == NULL)
        {
            result = i;
            file->fd = i;
            process->fd[i] = file;
            break;
        }
    }

    endCriticalSection();

    return result;
}

int32 removeFileFromProcess(Process* process, File* file)
{
    int32 result = -1;

    beginCriticalSection();

    for (int i = 0; i < MAX_OPENED_FILES; ++i)
    {
        if (process->fd[i] == file)
        {
            result = i;
            process->fd[i] = NULL;
            break;
        }
    }

    endCriticalSection();

    return result;
}

Thread* getThreadById(uint32 threadId)
{
    Thread* p = gFirstThread;

    while (p != NULL)
    {
        if (p->threadId == threadId)
        {
            return p;
        }
        p = p->next;
    }

    return NULL;
}

Thread* getPreviousThread(Thread* thread)
{
    Thread* t = gFirstThread;

    while (t->next != NULL)
    {
        if (t->next == thread)
        {
            return t;
        }
        t = t->next;
    }

    return NULL;
}

Thread* getMainKernelThread()
{
    return gFirstThread;
}

Thread* getCurrentThread()
{
    return gCurrentThread;
}

BOOL isThreadValid(Thread* thread)
{
    Thread* p = gFirstThread;

    while (p != NULL)
    {
        if (p == thread)
        {
            return TRUE;
        }
        p = p->next;
    }

    return FALSE;
}

BOOL isProcessValid(Process* process)
{
    Thread* p = gFirstThread;

    while (p != NULL)
    {
        if (p->owner == process)
        {
            return TRUE;
        }
        p = p->next;
    }

    return FALSE;
}

static void switchToTask(Thread* current, int mode);

static void updateMetrics(Thread* thread)
{
    uint32 seconds = getUptimeSeconds();

    if (seconds > gLastUptimeSeconds)
    {
        gLastUptimeSeconds = seconds;

        Thread* t = gFirstThread;

        while (t != NULL)
        {
            t->contextSwitchCount = t->totalContextSwitchCount - t->totalContextSwitchCountPrevious;
            t->totalContextSwitchCountPrevious = t->totalContextSwitchCount;

            t = t->next;
        }
    }

    ++gSystemContextSwitchCount;

    ++thread->totalContextSwitchCount;
}

void schedule(TimerInt_Registers* registers)
{
    Thread* current = gCurrentThread;

    if (NULL != current)
    {
        if (current->next == NULL && current == gFirstThread)
        {
            //We are the only process, no need to schedule
            return;
        }

        current->regs.eflags = registers->eflags;
        current->regs.cs = registers->cs;
        current->regs.eip = registers->eip;
        current->regs.eax = registers->eax;
        current->regs.ecx = registers->ecx;
        current->regs.edx = registers->edx;
        current->regs.ebx = registers->ebx;
        current->regs.ebp = registers->ebp;
        current->regs.esi = registers->esi;
        current->regs.edi = registers->edi;
        current->regs.ds = registers->ds;
        current->regs.es = registers->es;
        current->regs.fs = registers->fs;
        current->regs.gs = registers->gs;

        if (current->regs.cs != 0x08)
        {
            //Debug_PrintF("schedule() - 2.1\n");
            current->regs.esp = registers->esp_if_privilege_change;
            current->regs.ss = registers->ss_if_privilege_change;
        }
        else
        {
            //Debug_PrintF("schedule() - 2.2\n");
            current->regs.esp = registers->esp + 12;
            current->regs.ss = gTss.ss0;
        }

        //Save the TSS from the old process
        current->kstack.ss0 = gTss.ss0;
        current->kstack.esp0 = gTss.esp0;

        current = current->next;
        while (NULL != current)
        {
            if (current->state == TS_YIELD)
            {
                if (current->yield > 0)
                {
                    --current->yield;
                }

                if (current->yield == 0)
                {
                    current->state = TS_RUN;
                }
            }

            if (current->state == TS_SLEEP)
            {
                uint32 uptime = getUptimeMilliseconds();
                uint32 target = (uint32)current->state_privateData;

                if (uptime >= target)
                {
                    current->state = TS_RUN;
                    current->state_privateData = NULL;
                }
            }

            if (current->state == TS_RUN)
            {
                break;
            }
            current = current->next;
        }

        if (current == NULL)
        {
            //reached last process returning to first
            current = gFirstThread;
        }
    }
    else
    {
        //current is NULL. This means thread is destroyed, so start from the begining

        current = gFirstThread;
    }

    gCurrentThread = current;//Now gCurrentThread is the thread we are about to schedule to

    /*
    if (gCurrentThread->threadId == 5)
    {
        Screen_PrintF("I am scheduling to %d and its EIP is %x\n", gCurrentThread->threadId, gCurrentThread->regs.eip);
    }
    */

    updateMetrics(current);

    if (current->regs.cs != 0x08)
    {
        switchToTask(current, USERMODE);
    }
    else
    {
        switchToTask(current, KERNELMODE);
    }
}



//The mode indicates whether this process was in user mode or kernel mode
//When it was previously interrupted by the scheduler.
static void switchToTask(Thread* current, int mode)
{
    uint32 kesp, eflags;
    uint16 kss, ss, cs;

    //Set TSS values
    gTss.ss0 = current->kstack.ss0;
    gTss.esp0 = current->kstack.esp0;

    ss = current->regs.ss;
    cs = current->regs.cs;
    eflags = (current->regs.eflags | 0x200) & 0xFFFFBFFF;

    if (mode == USERMODE)
    {
        kss = current->kstack.ss0;
        kesp = current->kstack.esp0;
    }
    else
    {
        kss = current->regs.ss;
        kesp = current->regs.esp;
    }

    //switchTask is in task.asm

    asm("	mov %0, %%ss; \
        mov %1, %%esp; \
        cmpl %[KMODE], %[mode]; \
        je nextt; \
        push %2; \
        push %3; \
        nextt: \
        push %4; \
        push %5; \
        push %6; \
        push %7; \
        ljmp $0x08, $switchTask"
        :: \
        "m"(kss), \
        "m"(kesp), \
        "m"(ss), \
        "m"(current->regs.esp), \
        "m"(eflags), \
        "m"(cs), \
        "m"(current->regs.eip), \
        "m"(current), \
        [KMODE] "i"(KERNELMODE), \
        [mode] "g"(mode)
        );
}
