CC=cc
LD=ld
# disable stack-protector to support Arch Linux
# (https://bugs.archlinux.org/task/18864)
CFLAGS=-nostdlib -nostdinc -fno-builtin -fno-stack-protector -m32 -c
LDFLAGS=-Tlink.ld -m elf_i386
ASFLAGS=-felf

OBJ = $(patsubst %.c,%.o,$(wildcard *.c)) $(patsubst %.asm,%.o,$(wildcard *.asm))

kernel.bin: $(OBJ)
	$(LD) $(LDFLAGS) -o kernel.bin $(OBJ) font/font.o

%.o:%.c
	$(CC) $(CFLAGS) $< -o $@

%.o:%.asm
	nasm $(ASFLAGS) $< -o $@

clean:
	-rm *.o kernel.bin
