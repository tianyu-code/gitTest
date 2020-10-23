version1
#########################
# Makefile for Orange'S #
#########################

# Entry point of Orange'S
# It must have the same value with 'KernelEntryPointPhyAddr' in load.inc!
ENTRYPOINT	= 0x30400

# Offset of entry point in kernel file
# It depends on ENTRYPOINT
ENTRYOFFSET	=   0x400

# Programs, flags, etc.
ASM		= nasm
DASM	= ndisasm
CC		= gcc
LD		= ld
ASMBFLAGS	= -I boot/include/
ASMKFLAGS	= -I include/ -f elf
CFLAGS		= -I include/ -c  -m32 -fno-builtin
LDFLAGS		= -s -m elf_i386 -Ttext $(ENTRYPOINT)
DASMFLAGS	= -u -o $(ENTRYPOINT) -e $(ENTRYOFFSET)

IMG:=a.img
FLOPPY:=/mnt/

# This Program
ORANGESBOOT	= boot/boot.bin boot/loader.bin
ORANGESKERNEL	= kernel.bin
OBJS		= kernel/kernel.o kernel/start.o kernel/main.o kernel/clock.o kernel/proc.o kernel/syscall.o\
			kernel/i8259.o kernel/global.o kernel/protect.o\
			lib/kliba.o lib/klib.o lib/string.o
DASMOUTPUT	= kernel.bin.asm

# All Phony Targets
.PHONY : everything buildtarget image clean realclean disasm all buildimg

# Default starting position
image : buildtarget buildimg

buildtarget : all clean

all : realclean everything

everything : $(ORANGESBOOT) $(ORANGESKERNEL)

clean :
	rm -f $(OBJS)

realclean :
	rm -f $(OBJS) $(ORANGESBOOT) $(ORANGESKERNEL)


# We assume that "a.img" exists in current folder
buildimg :
	dd if=boot/boot.bin of=$(IMG) bs=512 count=1 conv=notrunc
	mount -o loop -t vfat $(IMG) $(FLOPPY)
	cp boot/loader.bin $(FLOPPY)
	cp kernel.bin $(FLOPPY)
	sync
	umount $(FLOPPY)

boot/boot.bin : boot/boot.asm boot/include/load.inc boot/include/fat12hdr.inc
	$(ASM) $(ASMBFLAGS) -o $@ $<

boot/loader.bin : boot/loader.asm boot/include/load.inc \
			boot/include/fat12hdr.inc boot/include/pm.inc
	$(ASM) $(ASMBFLAGS) -o $@ $<

$(ORANGESKERNEL) : $(OBJS)
	$(LD) $(LDFLAGS) -o $@ $^

kernel/kernel.o : kernel/kernel.asm
	$(ASM) $(ASMKFLAGS) -o $@ $<

kernel/start.o: kernel/start.c
	$(CC) $(CFLAGS) -o $@ $<

kernel/main.o: kernel/main.c
	$(CC) $(CFLAGS) -o $@ $<

kernel/clock.o: kernel/clock.c
	$(CC) $(CFLAGS) -o $@ $<

kernel/proc.o: kernel/proc.c
	$(CC) $(CFLAGS) -o $@ $<

kernel/syscall.o : kernel/syscall.asm
	$(ASM) $(ASMKFLAGS) -o $@ $<

kernel/i8259.o : kernel/i8259.c
	$(CC) $(CFLAGS) -o $@ $<

kernel/global.o : kernel/global.c
	$(CC) $(CFLAGS) -o $@ $<

kernel/protect.o : kernel/protect.c
	$(CC) $(CFLAGS) -o $@ $<

lib/klib.o : lib/klib.c
	$(CC) $(CFLAGS) -o $@ $<

lib/kliba.o : lib/kliba.asm
	$(ASM) $(ASMKFLAGS) -o $@ $<

lib/string.o : lib/string.asm
	$(ASM) $(ASMKFLAGS) -o $@ $<


