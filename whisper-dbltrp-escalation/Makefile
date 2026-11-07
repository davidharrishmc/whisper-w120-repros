# make (riscv64-unknown-elf-gcc): w_rv64.elf, w_rv32.elf (Whisper, Spike, Sail, Imperas: HTIF tohost) and
# q_rv64.elf, q_rv32.elf (QEMU virt: SiFive test finisher, exit status = x31).
CC = riscv64-unknown-elf-gcc
SRC = dbltrp_entry.S exit.h link.ld
FLAGS = -nostdlib -nostartfiles -T link.ld -I.
all: w_rv64.elf w_rv32.elf q_rv64.elf q_rv32.elf
w_rv64.elf: $(SRC)
	$(CC) -march=rv64gh_zicsr -mabi=lp64 $(FLAGS) $< -o $@
w_rv32.elf: $(SRC)
	$(CC) -march=rv32gh_zicsr -mabi=ilp32 $(FLAGS) $< -o $@
q_rv64.elf: $(SRC)
	$(CC) -DQEMU -march=rv64gh_zicsr -mabi=lp64 $(FLAGS) $< -o $@
q_rv32.elf: $(SRC)
	$(CC) -DQEMU -march=rv32gh_zicsr -mabi=ilp32 $(FLAGS) $< -o $@
clean:
	rm -f *.elf
