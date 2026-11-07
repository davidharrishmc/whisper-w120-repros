WHISPER ?= whisper
run: whisper_vs_sdt.elf
	-$(WHISPER) --config whisper.json --log whisper_vs_sdt.elf 2>&1 | grep "slli     x5, x31, 1"
whisper_vs_sdt.elf: whisper_vs_sdt.S exit.h link.ld
	riscv64-unknown-elf-gcc -nostdlib -nostartfiles -T link.ld -I. -march=rv64gh_zicsr -mabi=lp64 $< -o $@
clean:
	rm -f *.elf
