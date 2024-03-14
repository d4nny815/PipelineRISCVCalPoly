BUILD_DIR = build
CC = riscv32-unknown-elf-gcc
CFLAGS = -march=rv32i -mabi=ilp32 -O3 -g -Wall
DUMP = riscv32-unknown-elf-objdump
COPY = riscv32-unknown-elf-objcopy

MAIN = main
MAIN_OBJS = $(BUILD_DIR)/$(MAIN).o $(BUILD_DIR)/init.o
STARTUP_SRC = init.s


all: dirs $(BUILD_DIR)/$(MAIN).bin $(BUILD_DIR)/$(MAIN).txt $(BUILD_DIR)/$(MAIN).dump 

$(BUILD_DIR)/$(MAIN).o: $(MAIN).c
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/init.o: $(STARTUP_SRC) 
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/$(MAIN).elf: $(MAIN_OBJS)
	$(CC) $(CFLAGS) -T link.ld $^ -o $@

$(BUILD_DIR)/$(MAIN).dump: $(BUILD_DIR)/$(MAIN).elf
	$(DUMP) -D $< > $(BUILD_DIR)/raw.dump
	$(DUMP) --no-show-raw-insn -S -s $< > $@

$(BUILD_DIR)/$(MAIN).bin: $(BUILD_DIR)/$(MAIN).elf
	$(COPY) -O binary --only-section=.text* --only-section=.data* $< $@

$(BUILD_DIR)/$(MAIN).txt: $(BUILD_DIR)/$(MAIN).bin
	hexdump -v -e '"%08x\n"' $< > $@
	cp $@ ../otter_memory.mem

dirs:
	mkdir -p $(BUILD_DIR)

clean:
	rm -rf $(BUILD_DIR)
