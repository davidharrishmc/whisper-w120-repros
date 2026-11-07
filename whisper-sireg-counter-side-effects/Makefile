# make (prebuilt ELFs for Whisper/Spike/Sail/Imperas: w_rv64.elf, w_rv32.elf; QEMU: q_rv64.elf, q_rv32.elf)
all: w_rv64.elf w_rv32.elf q_rv64.elf q_rv32.elf
w_rv64.elf: sireg_counter.S exit.h link.ld
	riscv64-unknown-elf-gcc -nostdlib -nostartfiles -T link.ld -I. -march=rv64g_zicsr -mabi=lp64 $< -o $@
w_rv32.elf: sireg_counter.S exit.h link.ld
	riscv64-unknown-elf-gcc -nostdlib -nostartfiles -T link.ld -I. -march=rv32g_zicsr -mabi=ilp32 $< -o $@
q_rv64.elf: sireg_counter.S exit.h link.ld
	riscv64-unknown-elf-gcc -DQEMU -nostdlib -nostartfiles -T link.ld -I. -march=rv64g_zicsr -mabi=lp64 $< -o $@
q_rv32.elf: sireg_counter.S exit.h link.ld
	riscv64-unknown-elf-gcc -DQEMU -nostdlib -nostartfiles -T link.ld -I. -march=rv32g_zicsr -mabi=ilp32 $< -o $@
clean:
	rm -f *.elf
