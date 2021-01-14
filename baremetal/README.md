Some apps written in SubX and Mu. Where the rest of this repo relies on a few
Linux syscalls, the apps in this subdirectory interface directly with hardware.
We still need the top-level and apps to build them.

I'd like to eventually test these programs on real hardware, and to that end
they are extremely parsimonious in the hardware they assume:

  0. Lots (more than 640KB/1MB[1]) of RAM
  1. Pure-graphics video mode (1024x768 pixels) in 256-color mode. At 8x8
     pixels per grapheme, this will give us 160x128 graphemes. But it's still
     an open question if it's reasonably widely supported by modern hardware.
     If it isn't, I'll downsize.
  2. Keyboard. Just a partial US keyboard for now.

That's it:
  * No wifi, no networking
  * No multitouch, no touchscreen, no mouse
  * No graphics acceleration
  * No virtual memory, no memory reclamation

Just your processor, gigabytes of RAM[1], a moderately-sized monitor and a
keyboard. (The mouse should also be easy to provide.)

We can't yet read from or write to disk, except for the initial load of the
program. Enabling access to lots of RAM gives up access to BIOS helpers for
the disk.

These programs don't convert to formats like ELF that can load on other
operating systems. There's also currently no code/data segment separation,
just labels and bytes. I promise not to write self-modifying code. Security
and sandboxing is still an open question.

Programs start executing at address 0x9000. See baremetal/boot.hex for
details.

Mu programs always run all their automated tests first. `main` only runs if
there are no failing tests. See baremetal/mu-init.subx for details.

So far the programs have only been tested in Qemu and Bochs emulators.

[1] Though we might need to start thinking of [the PC memory map](https://wiki.osdev.org/Memory_Map_(x86))
as our programs grow past the first 512KB of memory. Writing to random
locations can damage hardware or corrupt storage devices.
