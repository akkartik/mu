#include "syscalls.h"
#include "fs.h"
#include "process.h"
#include "screen.h"
#include "alloc.h"
#include "pipe.h"
#include "debugprint.h"
#include "timer.h"
#include "sleep.h"
#include "ttydriver.h"
#include "spinlock.h"
#include "message.h"
#include "commonuser.h"
#include "syscalltable.h"
#include "isr.h"
#include "sharedmemory.h"


/**************
 * All of syscall entered with interrupts disabled!
 * A syscall can enable interrupts if it is needed.
 *
 **************/

static void handleSyscall(Registers* regs);

static void* gSyscallTable[SYSCALL_COUNT];


int syscall_open(const char *pathname, int flags);
int syscall_close(int fd);
int syscall_read(int fd, void *buf, int nbytes);
int syscall_write(int fd, void *buf, int nbytes);
int syscall_lseek(int fd, int offset, int whence);
int syscall_stat(const char *path, struct stat *buf);
int syscall_fstat(int fd, struct stat *buf);
int syscall_ioctl(int fd, int32 request, void *arg);
int syscall_exit(int status);
void* syscall_sbrk(uint32 increment);
int syscall_fork();
int syscall_getpid();
int syscall_execute(const char *path, char *const argv[], char *const envp[]);
int syscall_execve(const char *path, char *const argv[], char *const envp[]);
int syscall_wait(int *wstatus);
int syscall_kill(int pid, int sig);
int syscall_mount(const char *source, const char *target, const char *fsType, unsigned long flags, void *data);
int syscall_unmount(const char *target);
int syscall_mkdir(const char *path, uint32 mode);
int syscall_rmdir(const char *path);
int syscall_getdents(int fd, char *buf, int nbytes);
int syscall_getWorkingDirectory(char *buf, int size);
int syscall_setWorkingDirectory(const char *path);
int syscall_managePipe(const char *pipeName, int operation, int data);
int syscall_readDir(int fd, void *dirent, int index);
int syscall_getUptimeMilliseconds();
int syscall_sleepMilliseconds(int ms);
int syscall_executeOnTTY(const char *path, char *const argv[], char *const envp[], const char *ttyPath);
int syscall_manageMessage(int command, void* message);
void* syscall_mmap(void *addr, int length, int flags, int fd, int offset);
int syscall_munmap(void *addr, int length);
int syscall_shm_open(const char *name, int oflag, int mode);
int syscall_shm_unlink(const char *name);
int syscall_ftruncate(int fd, int size);
int syscall_posix_openpt(int flags);
int syscall_ptsname_r(int fd, char *buf, int buflen);


void initialiseSyscalls()
{
    memset((uint8*)gSyscallTable, 0, sizeof(void*) * SYSCALL_COUNT);

    gSyscallTable[SYS_open] = syscall_open;
    gSyscallTable[SYS_close] = syscall_close;
    gSyscallTable[SYS_read] = syscall_read;
    gSyscallTable[SYS_write] = syscall_write;
    gSyscallTable[SYS_lseek] = syscall_lseek;
    gSyscallTable[SYS_stat] = syscall_stat;
    gSyscallTable[SYS_fstat] = syscall_fstat;
    gSyscallTable[SYS_ioctl] = syscall_ioctl;
    gSyscallTable[SYS_exit] = syscall_exit;
    gSyscallTable[SYS_sbrk] = syscall_sbrk;
    gSyscallTable[SYS_fork] = syscall_fork;
    gSyscallTable[SYS_getpid] = syscall_getpid;

    gSyscallTable[SYS_execute] = syscall_execute;
    gSyscallTable[SYS_execve] = syscall_execve;
    gSyscallTable[SYS_wait] = syscall_wait;
    gSyscallTable[SYS_kill] = syscall_kill;
    gSyscallTable[SYS_mount] = syscall_mount;
    gSyscallTable[SYS_unmount] = syscall_unmount;
    gSyscallTable[SYS_mkdir] = syscall_mkdir;
    gSyscallTable[SYS_rmdir] = syscall_rmdir;
    gSyscallTable[SYS_getdents] = syscall_getdents;
    gSyscallTable[SYS_getWorkingDirectory] = syscall_getWorkingDirectory;
    gSyscallTable[SYS_setWorkingDirectory] = syscall_setWorkingDirectory;
    gSyscallTable[SYS_managePipe] = syscall_managePipe;
    gSyscallTable[SYS_readDir] = syscall_readDir;
    gSyscallTable[SYS_getUptimeMilliseconds] = syscall_getUptimeMilliseconds;
    gSyscallTable[SYS_sleepMilliseconds] = syscall_sleepMilliseconds;
    gSyscallTable[SYS_executeOnTTY] = syscall_executeOnTTY;
    gSyscallTable[SYS_manageMessage] = syscall_manageMessage;
    gSyscallTable[SYS_UNUSED] = NULL;
    gSyscallTable[SYS_mmap] = syscall_mmap;
    gSyscallTable[SYS_munmap] = syscall_munmap;
    gSyscallTable[SYS_shm_open] = syscall_shm_open;
    gSyscallTable[SYS_shm_unlink] = syscall_shm_unlink;
    gSyscallTable[SYS_ftruncate] = syscall_ftruncate;
    gSyscallTable[SYS_posix_openpt] = syscall_posix_openpt;
    gSyscallTable[SYS_ptsname_r] = syscall_ptsname_r;

    // Register our syscall handler.
    registerInterruptHandler (0x80, &handleSyscall);
}

static void handleSyscall(Registers* regs)
{
    if (regs->eax >= SYSCALL_COUNT)
    {
        return;
    }

    void *location = gSyscallTable[regs->eax];

    if (NULL == location)
    {
        regs->eax = -1;
        return;
    }

    //Screen_PrintF("We are in syscall_handler\n");
    //Screen_PrintInterruptsEnabled();

    //I think it is better to enable interrupts in syscall implementations if it is needed.

    int ret;
    asm volatile (" \
      pushl %1; \
      pushl %2; \
      pushl %3; \
      pushl %4; \
      pushl %5; \
      call *%6; \
      popl %%ebx; \
      popl %%ebx; \
      popl %%ebx; \
      popl %%ebx; \
      popl %%ebx; \
    " : "=a" (ret) : "r" (regs->edi), "r" (regs->esi), "r" (regs->edx), "r" (regs->ecx), "r" (regs->ebx), "r" (location));
    regs->eax = ret;
}

int syscall_open(const char *pathname, int flags)
{
    Process* process = getCurrentThread()->owner;
    if (process)
    {
        //Screen_PrintF("open():[%s]\n", pathname);
        FileSystemNode* node = getFileSystemNodeAbsoluteOrRelative(pathname, process);
        if (node)
        {
            //Screen_PrintF("open():node:[%s]\n", node->name);
            File* file = open_fs(node, flags);

            if (file)
            {
                return file->fd;
            }
        }
    }

    return -1;
}

int syscall_close(int fd)
{
    Process* process = getCurrentThread()->owner;
    if (process)
    {
        if (fd < MAX_OPENED_FILES)
        {
            File* file = process->fd[fd];

            if (file)
            {
                close_fs(file);

                return 0;
            }
            else
            {
                //TODO: error invalid fd
            }
        }
        else
        {
            //TODO: error invalid fd
        }
    }
    else
    {
        PANIC("Process is NULL!\n");
    }

    return -1;
}

int syscall_read(int fd, void *buf, int nbytes)
{
    //Screen_PrintF("syscall_read: begin - nbytes:%d\n", nbytes);

    Process* process = getCurrentThread()->owner;
    if (process)
    {
        if (fd < MAX_OPENED_FILES)
        {
            File* file = process->fd[fd];

            if (file)
            {
                //Debug_PrintF("syscall_read(%d): %s\n", process->pid, buf);

                //enableInterrupts();

                //Each handler is free to enable interrupts.
                //We don't enable them here.

                return read_fs(file, nbytes, buf);
            }
            else
            {
                //TODO: error invalid fd
            }
        }
        else
        {
            //TODO: error invalid fd
        }
    }
    else
    {
        PANIC("Process is NULL!\n");
    }

    return -1;
}

int syscall_write(int fd, void *buf, int nbytes)
{
    Process* process = getCurrentThread()->owner;
    if (process)
    {
        //Screen_PrintF("syscall_write() called from process: %d. fd:%d\n", process->pid, fd);

        if (fd < MAX_OPENED_FILES)
        {
            File* file = process->fd[fd];

            if (file)
            {
                /*
                for (int i = 0; i < nbytes; ++i)
                {
                    Debug_PrintF("pid:%d syscall_write:buf[%d]=%c\n", process->pid, i, ((char*)buf)[i]);
                }
                */

                uint32 writeResult = write_fs(file, nbytes, buf);

                return writeResult;
            }
            else
            {
                //TODO: error invalid fd
            }
        }
        else
        {
            //TODO: error invalid fd
        }
    }
    else
    {
        PANIC("Process is NULL!\n");
    }

    return -1;
}

int syscall_lseek(int fd, int offset, int whence)
{
    Process* process = getCurrentThread()->owner;
    if (process)
    {
        //Screen_PrintF("syscall_lseek() called from process: %d. fd:%d\n", process->pid, fd);

        if (fd < MAX_OPENED_FILES)
        {
            File* file = process->fd[fd];

            if (file)
            {
                return lseek_fs(file, offset, whence);
            }
            else
            {
                //TODO: error invalid fd
            }
        }
        else
        {
            //TODO: error invalid fd
        }
    }
    else
    {
        PANIC("Process is NULL!\n");
    }

    return -1;
}

int syscall_stat(const char *path, struct stat *buf)
{
    Process* process = getCurrentThread()->owner;
    if (process)
    {
        //Screen_PrintF("syscall_stat() called from process: %d. path:%s\n", process->pid, path);

        FileSystemNode* node = getFileSystemNodeAbsoluteOrRelative(path, process);

        if (node)
        {
            return stat_fs(node, buf);
        }
    }
    else
    {
        PANIC("Process is NULL!\n");
    }

    return -1;
}

int syscall_fstat(int fd, struct stat *buf)
{
    Process* process = getCurrentThread()->owner;
    if (process)
    {
        if (fd < MAX_OPENED_FILES)
        {
            File* file = process->fd[fd];

            if (file)
            {
                return stat_fs(file->node, buf);
            }
            else
            {
                //TODO: error invalid fd
            }
        }
        else
        {
            //TODO: error invalid fd
        }
    }
    else
    {
        PANIC("Process is NULL!\n");
    }

    return -1;
}

int syscall_ioctl(int fd, int32 request, void *arg)
{
    Process* process = getCurrentThread()->owner;
    if (process)
    {
        if (fd < MAX_OPENED_FILES)
        {
            File* file = process->fd[fd];

            if (file)
            {
                return ioctl_fs(file, request, arg);
            }
            else
            {
                //TODO: error invalid fd
            }
        }
        else
        {
            //TODO: error invalid fd
        }
    }
    else
    {
        PANIC("Process is NULL!\n");
    }

    return -1;
}

int syscall_exit(int status)
{
    Process* process = getCurrentThread()->owner;
    if (process)
    {
        printkf("syscall_exit(%d)\n", status);
        printkf("process pid: %d\n", process->pid);
        if (process->parent) {
                printkf("process parent pid: %d\n", process->parent->pid);
                printkf("writing %d to %p\n", 1, &process->parent->childExitStatusPresent);
                process->parent->childExitStatusPresent = 1;
                printkf("writing %d to %x\n", status, &process->parent->childExitStatus);
                process->parent->childExitStatus = status;
        }

        destroyProcess(process);

        waitForSchedule();
    }
    else
    {
        PANIC("Process is NULL!\n");
    }

    return -1;
}

void* syscall_sbrk(uint32 increment)
{
    //Screen_PrintF("syscall_sbrk() !!! inc:%d\n", increment);

    Process* process = getCurrentThread()->owner;
    if (process)
    {
        return sbrk(process, increment);
    }
    else
    {
        PANIC("Process is NULL!\n");
    }

    return (void*)-1;
}

int syscall_fork()
{
    //Not implemented

    return -1;
}

int syscall_getpid()
{
    Process* process = getCurrentThread()->owner;
    if (process)
    {
        return process->pid;
    }
    else
    {
        PANIC("Process is NULL!\n");
    }

    return -1;
}

//NON-posix
int syscall_execute(const char *path, char *const argv[], char *const envp[])
{
    int result = -1;

    printkf("syscall_execute: %s\n", path);
    Process* process = getCurrentThread()->owner;
    if (process)
    {
        printkf("found current process\n");
        FileSystemNode* node = getFileSystemNodeAbsoluteOrRelative(path, process);
        if (node)
        {
            File* f = open_fs(node, 0);
            if (f)
            {
                printkf("file found\n");
                void* image = kmalloc(node->length);

                //Screen_PrintF("executing %s and its %d bytes\n", filename, node->length);

                int32 bytesRead = read_fs(f, node->length, image);

                //Screen_PrintF("syscall_execute: read_fs returned %d bytes\n", bytesRead);

                if (bytesRead > 0)
                {
                    printkf("creating user process from ELF data\n");
                    Process* newProcess = createUserProcessFromElfData("userProcess", image, argv, envp, process, NULL);

                    if (newProcess)
                    {
                        result = newProcess->pid;
                    }
                }
                close_fs(f);

                kfree(image);
            }

        }
    }
    else
    {
        PANIC("Process is NULL!\n");
    }

    return result;
}

int syscall_executeOnTTY(const char *path, char *const argv[], char *const envp[], const char *ttyPath)
{
    int result = -1;

    Process* process = getCurrentThread()->owner;
    if (process)
    {
        FileSystemNode* node = getFileSystemNodeAbsoluteOrRelative(path, process);
        FileSystemNode* ttyNode = getFileSystemNodeAbsoluteOrRelative(ttyPath, process);
        if (node && ttyNode)
        {
            File* f = open_fs(node, 0);
            if (f)
            {
                void* image = kmalloc(node->length);

                //Screen_PrintF("executing %s and its %d bytes\n", filename, node->length);

                int32 bytesRead = read_fs(f, node->length, image);

                //Screen_PrintF("syscall_execute: read_fs returned %d bytes\n", bytesRead);

                if (bytesRead > 0)
                {
                    Process* newProcess = createUserProcessFromElfData("userProcess", image, argv, envp, process, ttyNode);

                    if (newProcess)
                    {
                        result = newProcess->pid;
                    }
                }
                close_fs(f);

                kfree(image);
            }

        }
    }
    else
    {
        PANIC("Process is NULL!\n");
    }

    return result;
}

int syscall_execve(const char *path, char *const argv[], char *const envp[])
{
    Process* callingProcess = getCurrentThread()->owner;

    FileSystemNode* node = getFileSystemNode(path);
    if (node)
    {
        File* f = open_fs(node, 0);
        if (f)
        {
            void* image = kmalloc(node->length);

            if (read_fs(f, node->length, image) > 0)
            {
                disableInterrupts(); //just in case if a file operation left interrupts enabled.

                Process* newProcess = createUserProcessEx("fromExecve", callingProcess->pid, 0, NULL, image, argv, envp, NULL, callingProcess->tty);

                close_fs(f);

                kfree(image);

                if (newProcess)
                {
                    destroyProcess(callingProcess);

                    waitForSchedule();

                    //unreachable
                }
            }

            close_fs(f);

            kfree(image);
        }
    }


    //if it all goes well, this line is unreachable
    return 0;
}

int syscall_wait(int *wstatus)
{
    //TODO: return pid of exited child. implement with sendsignal
    Thread* currentThread = getCurrentThread();

    Process* process = currentThread->owner;
    if (process)
    {
        printkf("wait: I am %d at %x\n", process->pid, process);
        Thread* thread = getMainKernelThread();
        while (thread)
        {
            printkf("wait: checking %d at %x\n", thread->owner->pid, thread->owner);
            printkf("wait: parent is %d at %x\n", thread->owner->parent->pid, thread->owner->parent);
            if (process == thread->owner->parent)
            {
                //We have a child process
                printkf("wait: d\n");

                currentThread->state = TS_WAITCHILD;

                enableInterrupts();
                while (currentThread->state == TS_WAITCHILD);

                if (process->childExitStatusPresent) {
                        printkf("wait: reading from %x: %d\n", &process->childExitStatus, process->childExitStatus);
                        return process->childExitStatus;
                }
                break;
            }

            thread = thread->next;
        }
    }
    else
    {
        PANIC("Process is NULL!\n");
    }

    return -1;
}

int syscall_kill(int pid, int sig)
{
    Process* selfProcess = getCurrentThread()->owner;

    Thread* thread = getMainKernelThread();
    while (thread)
    {
        if (pid == thread->owner->pid)
        {
            //We have found the process

            //TODOif (sig==KILL)
            {
                destroyProcess(thread->owner);

                if (thread->owner == selfProcess)
                {
                    waitForSchedule();
                }
                else
                {
                    return 0;
                }
            }
            break;
        }

        thread = thread->next;
    }

    return -1;
}

int syscall_mount(const char *source, const char *target, const char *fsType, unsigned long flags, void *data)//non-posix
{
    BOOL result = mountFileSystem(source, target, fsType, flags, data);

    if (TRUE == result)
    {
        return 0;//on success
    }

    return -1;//on error
}

int syscall_unmount(const char *target)//non-posix
{
    FileSystemNode* targetNode = getFileSystemNode(target);

    if (targetNode)
    {
        if (targetNode->nodeType == FT_MountPoint)
        {
            targetNode->nodeType = FT_Directory;

            targetNode->mountPoint = NULL;

            //TODO: check conditions, maybe busy. make clean up.

            return 0;//on success
        }
    }

    return -1;//on error
}

int syscall_mkdir(const char *path, uint32 mode)
{
    char parentPath[128];
    const char* name = NULL;
    int length = strlen(path);
    for (int i = length - 1; i >= 0; --i)
    {
        if (path[i] == '/')
        {
            name = path + i + 1;
            strncpy(parentPath, path, i);
            parentPath[i] = '\0';
            break;
        }
    }

    if (strlen(parentPath) == 0)
    {
        parentPath[0] = '/';
        parentPath[1] = '\0';
    }

    if (strlen(name) == 0)
    {
        return -1;
    }

    //Screen_PrintF("mkdir: parent:[%s] name:[%s]\n", parentPath, name);

    FileSystemNode* targetNode = getFileSystemNode(parentPath);

    if (targetNode)
    {
        BOOL success = mkdir_fs(targetNode, name, mode);
        if (success)
        {
            return 0;//on success
        }
    }

    return -1;//on error
}

int syscall_rmdir(const char *path)
{
    //TODO:
    //return 0;//on success

    return -1;//on error
}

int syscall_getdents(int fd, char *buf, int nbytes)
{
    Process* process = getCurrentThread()->owner;
    if (process)
    {
        if (fd < MAX_OPENED_FILES)
        {
            File* file = process->fd[fd];

            if (file)
            {
                //Screen_PrintF("syscall_getdents(%d): %s\n", process->pid, buf);

                int byteCounter = 0;

                int index = 0;
                FileSystemDirent* dirent = readdir_fs(file->node, index);

                while (NULL != dirent && (byteCounter + sizeof(FileSystemDirent) <= nbytes))
                {
                    memcpy((uint8*)buf + byteCounter, (uint8*)dirent, sizeof(FileSystemDirent));

                    byteCounter += sizeof(FileSystemDirent);

                    index += 1;
                    dirent = readdir_fs(file->node, index);
                }

                return byteCounter;
            }
            else
            {
                //TODO: error invalid fd
            }
        }
        else
        {
            //TODO: error invalid fd
        }
    }
    else
    {
        PANIC("Process is NULL!\n");
    }

    return -1;//on error
}

int syscall_readDir(int fd, void *dirent, int index)
{
    Process* process = getCurrentThread()->owner;
    if (process)
    {
        if (fd < MAX_OPENED_FILES)
        {
            File* file = process->fd[fd];

            if (file)
            {
                FileSystemDirent* direntFs = readdir_fs(file->node, index);

                if (direntFs)
                {
                    memcpy((uint8*)dirent, (uint8*)direntFs, sizeof(FileSystemDirent));

                    return 1;
                }
            }
            else
            {
                //TODO: error invalid fd
            }
        }
        else
        {
            //TODO: error invalid fd
        }
    }
    else
    {
        PANIC("Process is NULL!\n");
    }

    return -1;//on error
}

int syscall_getWorkingDirectory(char *buf, int size)
{
    Process* process = getCurrentThread()->owner;
    if (process)
    {
        if (process->workingDirectory)
        {
            return getFileSystemNodePath(process->workingDirectory, buf, size);
        }
    }
    else
    {
        PANIC("Process is NULL!\n");
    }

    return -1;//on error
}

int syscall_setWorkingDirectory(const char *path)
{
    Process* process = getCurrentThread()->owner;
    if (process)
    {
        FileSystemNode* node = getFileSystemNodeAbsoluteOrRelative(path, process);

        if (node)
        {
            process->workingDirectory = node;

            return 0; //success
        }
    }
    else
    {
        PANIC("Process is NULL!\n");
    }

    return -1;//on error
}

int syscall_managePipe(const char *pipeName, int operation, int data)
{
    int result = -1;

    switch (operation)
    {
    case 0:
        result = existsPipe(pipeName);
        break;
    case 1:
        result = createPipe(pipeName, data);
        break;
    case 2:
        result = destroyPipe(pipeName);
        break;
    }

    return result;
}

int syscall_getUptimeMilliseconds()
{
    return getUptimeMilliseconds();
}

int syscall_sleepMilliseconds(int ms)
{
    Thread* thread = getCurrentThread();

    sleepMilliseconds(thread, (uint32)ms);

    return 0;
}

int syscall_manageMessage(int command, void* message)
{
    Thread* thread = getCurrentThread();

    int result = -1;

    switch (command)
    {
    case 0:
        result = getMessageQueueCount(thread);
        break;
    case 1:
        sendMesage(thread, (SosoMessage*)message);
        result = 0;
        break;
    case 2:
        //make blocking
        result = getNextMessage(thread, (SosoMessage*)message);
        break;
    default:
        break;
    }

    return result;
}

void* syscall_mmap(void *addr, int length, int flags, int fd, int offset)
{
    if (addr)
    {
        //Mapping to a specified address is not implemented

        return (void*)-1;
    }

    Process* process = getCurrentThread()->owner;

    if (process)
    {
        if (fd < MAX_OPENED_FILES)
        {
            File* file = process->fd[fd];

            if (file)
            {
                void* ret = mmap_fs(file, length, offset, flags);

                if (ret)
                {
                    return ret;
                }
            }
            else
            {
                //TODO: error invalid fd
            }
        }
        else
        {
            //TODO: error invalid fd
        }
    }
    else
    {
        PANIC("Process is NULL!\n");
    }

    return (void*)-1;
}

int syscall_munmap(void *addr, int length)
{
    //TODO: fd

    /*
    Process* process = getCurrentThread()->owner;

    if (process)
    {
        if (fd < MAX_OPENED_FILES)
        {
            File* file = process->fd[fd];

            if (file)
            {
                if (munmap_fs(file, addr, length))
                {
                    return 0;//on success
                }
            }
            else
            {
                //TODO: error invalid fd
            }
        }
        else
        {
            //TODO: error invalid fd
        }
    }
    else
    {
        PANIC("Process is NULL!\n");
    }
    */

    return -1;
}

#define O_CREAT 0x200

int syscall_shm_open(const char *name, int oflag, int mode)
{
    FileSystemNode* node = NULL;

    if ((oflag & O_CREAT) == O_CREAT)
    {
        node = createSharedMemory(name);
    }
    else
    {
        node = getSharedMemoryNode(name);
    }

    if (node)
    {
        File* file = open_fs(node, oflag);

        if (file)
        {
            return file->fd;
        }
    }

    return -1;
}

int syscall_shm_unlink(const char *name)
{
    return -1;
}

int syscall_ftruncate(int fd, int size)
{
    Process* process = getCurrentThread()->owner;
    if (process)
    {
        if (fd < MAX_OPENED_FILES)
        {
            File* file = process->fd[fd];

            if (file)
            {
                return ftruncate_fs(file, size);
            }
            else
            {
                //TODO: error invalid fd
            }
        }
        else
        {
            //TODO: error invalid fd
        }
    }
    else
    {
        PANIC("Process is NULL!\n");
    }

    return -1;
}

int syscall_posix_openpt(int flags)
{
    Process* process = getCurrentThread()->owner;
    if (process)
    {
        FileSystemNode* node = createPseudoTerminal();
        if (node)
        {
            File* file = open_fs(node, flags);

            if (file)
            {
                return file->fd;
            }
        }
    }
    else
    {
        PANIC("Process is NULL!\n");
    }

    return -1;
}

int syscall_ptsname_r(int fd, char *buf, int buflen)
{
    Process* process = getCurrentThread()->owner;
    if (process)
    {
        if (fd < MAX_OPENED_FILES)
        {
            File* file = process->fd[fd];

            if (file)
            {
                /*
                int result = getSlavePath(file->node, buf, buflen);

                if (result > 0)
                {
                    return 0; //return 0 on success
                }
                */
            }
            else
            {
                //TODO: error invalid fd
            }
        }
        else
        {
            //TODO: error invalid fd
        }
    }
    else
    {
        PANIC("Process is NULL!\n");
    }

    return -1;//on error
}
