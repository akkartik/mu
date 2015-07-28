CFLAGS=-O3 -Wall -Wextra -D_XOPEN_SOURCE

libtermbox.a: utf8.o termbox.o
	ar rcs libtermbox.a *.o

termbox.o: termbox.h termbox.c input.inl output.inl bytebuffer.inl

clean:
	-rm *.o libtermbox.a
