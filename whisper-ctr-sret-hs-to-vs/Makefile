# make whisper (WHISPER=path, CI pin 6b8cce1) or make qemu (QEMU_DIR=dir with qemu-system-riscv{32,64}).
# Whisper: the line printed computes tohost from x31, the bitmask of failed checks (x5 = x31 << 1).
# QEMU: exit status = x31 (0 = pass).
WHISPER ?= whisper
QEMU_DIR ?=
all: whisper qemu
%_rv64.elf: whisper_ctr_sret.S common.h exit.h link.ld
	riscv64-unknown-elf-gcc $(DEFS) -nostdlib -nostartfiles -T link.ld -I. -march=rv64gh_zicsr -mabi=lp64 $< -o $@
%_rv32.elf: whisper_ctr_sret.S common.h exit.h link.ld
	riscv64-unknown-elf-gcc $(DEFS) -nostdlib -nostartfiles -T link.ld -I. -march=rv32gh_zicsr -mabi=ilp32 $< -o $@
whisper: w_rv64.elf w_rv32.elf
	-$(WHISPER) --config whisper-rv64.json --log w_rv64.elf 2>&1 | grep "slli     x5, x31, 1"
	-$(WHISPER) --config whisper-rv32.json --log w_rv32.elf 2>&1 | grep "slli     x5, x31, 1"
qemu: DEFS = -DQEMU
qemu: q_rv64.elf q_rv32.elf
	-$(QEMU_DIR)qemu-system-riscv64 -nographic -machine virt -cpu max -bios q_rv64.elf; echo "qemu rv64: x31 = $$?"
	-$(QEMU_DIR)qemu-system-riscv32 -nographic -machine virt -cpu max -bios q_rv32.elf; echo "qemu rv32: x31 = $$?"
clean:
	rm -f *.elf
