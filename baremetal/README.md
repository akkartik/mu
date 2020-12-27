Some apps written in SubX and Mu. Where the rest of this repo relies on a few
Linux syscalls, the apps in this subdirectory interface directly with hardware.

I'd like to eventually test these programs on real hardware, and to that end
they are extremely parsimonious in the hardware they assume:

  0. Lots (more than 640KB/1MB) of RAM
  1. Pure-graphics video mode (1280x1024 pixels) in 256-color mode.
  2. Keyboard

That's it:
  * No wifi, no networking
  * No multitouch, no touchscreen, no mouse
  * No graphics acceleration, no graphics
  * No virtual memory, no memory reclamation

Just your processor, gigabytes of RAM[1], a moderately-sized monitor and a
keyboard.

These programs don't convert to ELF, and there's also currently no code/data
segment separation. Just labels and bytes.

Most programs here assume `main` starts at address 0x8000 (1KB or 2 disk
sectors past the BIOS entrypoint). See baremetal/boot.hex for details.

So far the programs have only been tested in Qemu and Bochs emulators.

[1] Though we might need to start thinking of [the PC memory map](https://wiki.osdev.org/Memory_Map_(x86))
as our programs grow past the first 512KB of memory.
