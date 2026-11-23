CC = riscv64-unknown-elf-gcc
OBJDUMP = riscv64-unknown-elf-objdump

all: xtval-noc.rv64.elf xtval-noc.rv32.elf

xtval-noc.rv64.elf: xtval-noc.S link.ld
	$(CC) -march=rv64i_zicsr -mabi=lp64 -nostdlib -nostartfiles -T link.ld -o $@ xtval-noc.S
	$(OBJDUMP) -d $@ > $(@:.elf=.objdump)

xtval-noc.rv32.elf: xtval-noc.S link.ld
	$(CC) -march=rv32i_zicsr -mabi=ilp32 -nostdlib -nostartfiles -T link.ld -o $@ xtval-noc.S
	$(OBJDUMP) -d $@ > $(@:.elf=.objdump)

clean:
	rm -f *.elf *.objdump

.PHONY: all clean
