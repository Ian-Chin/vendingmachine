ASM      = nasm
ASMFLAGS = -f elf64
LD       = ld
TARGET   = vending

all: $(TARGET)

$(TARGET): $(TARGET).o
	$(LD) -o $(TARGET) $(TARGET).o

$(TARGET).o: $(TARGET).asm
	$(ASM) $(ASMFLAGS) -o $(TARGET).o $(TARGET).asm

run: $(TARGET)
	./$(TARGET)

clean:
	rm -f $(TARGET) $(TARGET).o

.PHONY: all run clean
