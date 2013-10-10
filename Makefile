AR = ar
DC = gdc
DFLAGS = -Wall -Wextra -pedantic -Isrc
GDB = -funittest -fdebug -ggdb3
#GDB = -O3
LIB = 

VPATH = src:src/compiler/codegen:src/compiler/parser:src/compiler/pretty:src/eval/gc:src/eval/smp:src/eval/vm

COMPILER_OBJS = token.o scanner.o parser.o ast.o compile.o print.o
VM_OBJS = alloc.o gc.o memory.o mqueue.o rqueue.o smp.o builtins.o bytecode.o eval.o state.o
OTHER_OBJS = main.o

OBJS = $(COMPILER_OBJS) $(VM_OBJS) $(OTHER_OBJS)

TARGET = tvm

all : $(TARGET)

$(TARGET) : $(OBJS) $(LIB)
	$(DC) $^ $(DLDLIBS) -o$@

%.o : %.d
	$(DC) $(DFLAGS) $(GDB) $< -c

clean:
	rm -f $(TARGET)
	rm -f *.o

# FIXME GDC isn't in the PATH of the flymake process.
# check-syntax:
#	/opt/gdc/bin/gdc $(DFLAGS) $(GDB) -c ${CHK_SOURCES} -o /dev/null
