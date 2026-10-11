ASM      = nasm
ASMFLAGS = -f elf32 -I src/lib/
LD       = ld -m elf_i386
TARGET   = vending
OBJ_DIR  = build

SRCS     = $(wildcard src/*.asm src/screens/*.asm src/lib/*.asm)
OBJS     = $(addprefix $(OBJ_DIR)/,$(notdir $(SRCS:.asm=.o)))
INCS     = $(wildcard src/lib/*.inc)

vpath %.asm src src/screens src/lib

all: $(TARGET)

$(TARGET): $(OBJS)
	$(LD) -o $@ $^

$(OBJ_DIR)/%.o: %.asm $(INCS) | $(OBJ_DIR)
	$(ASM) $(ASMFLAGS) -o $@ $<

$(OBJ_DIR):
	mkdir -p $@

run: $(TARGET)
	./$(TARGET)

clean:
	rm -rf $(TARGET) $(OBJ_DIR)

.PHONY: all run clean
