RISCV_CC ?= riscv64-unknown-elf-gcc
vstip.elf: vstip.S link.ld
	$(RISCV_CC) -march=rv64imah_zicsr -mabi=lp64 -nostdlib -nostartfiles -T link.ld -o $@ vstip.S
clean:
	rm -f vstip.elf
