#ifndef SYSCALLTABLE_H
#define SYSCALLTABLE_H

//This file will also be included by C library.
enum {
    SYS_open,  // 0
    SYS_close,  // 1
    SYS_read,  // 2
    SYS_write,  // 3
    SYS_lseek,  // 4
    SYS_stat,  // 5
    SYS_fstat,  // 6
    SYS_ioctl,  // 7
    SYS_exit,  // 8
    SYS_sbrk,  // 9
    SYS_fork,  // 10
    SYS_getpid,  // 11

    //non-posix
    SYS_execute,  // 12
    SYS_execve,  // 13
    SYS_wait,  // 14
    SYS_kill,  // 15
    SYS_mount,  // 16
    SYS_unmount,  // 17
    SYS_mkdir,  // 18
    SYS_rmdir,  // 19
    SYS_getdents,  // 20
    SYS_getWorkingDirectory,  // 21
    SYS_setWorkingDirectory,  // 22
    SYS_managePipe,  // 23
    SYS_readDir,  // 24
    SYS_getUptimeMilliseconds,  // 25
    SYS_sleepMilliseconds,  // 26
    SYS_executeOnTTY,  // 27
    SYS_manageMessage,  // 28
    SYS_UNUSED,  // 29

    SYS_mmap,  // 30
    SYS_munmap,  // 31
    SYS_shm_open,  // 32
    SYS_shm_unlink,  // 33
    SYS_ftruncate,  // 34
    SYS_posix_openpt,  // 35
    SYS_ptsname_r,  // 36

    SYSCALL_COUNT  // 37
};

#endif // SYSCALLTABLE_H
