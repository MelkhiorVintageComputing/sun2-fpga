
#

MUSASHI=../../Musashi

INCS = -I/usr/include/cver/ \
	-I$(MUSASHI)

CFLAGS= -fPIC -Wall -g $(INCS) -m32
LFLAGS= -G -shared -export-dynamic -m elf_i386

all: cosim_mc68010.so
#all: cosim_mc68010.so cosim_mc68010.vpi test
#all: test

cosim_mc68010.o: cosim_mc68010.c 
	$(CC) $(CFLAGS) -D__CVER__ -c cosim_mc68010.c

cosim_mc68010.so: cosim_mc68010.o
	$(LD) $(LFLAGS) cosim_mc68010.o -o cosim_mc68010.so \
	$(MUSASHI)/m68kcpu.o $(MUSASHI)/m68kops.o $(MUSASHI)/softfloat/softfloat.o \
	-lpthread

cosim_mc68010.vpi: cosim_mc68010.o
	$(LD) $(LFLAGS) cosim_mc68010.o -o cosim_mc68010.vpi

test:
	$(CC) $(CFLAGS) -D__TEST__ -g -o test_cosim cosim_mc68010.c \
	$(MUSASHI)/m68kcpu.o $(MUSASHI)/m68kops.o $(MUSASHI)/softfloat/softfloat.o \
	-lpthread

clean:
	rm -f *.o *.so *.vpi
