# Whisper, RV32: accesses and fetches that run past 0xFFFFFFFF use address 0x1_0000_0000 instead of 0

Address computations wrap modulo 2^XLEN (unpriv/intro.adoc, "The memory address space is circular"), and in Bare
mode the 32-bit address is then zero-extended to the 34-bit physical address (supervisor.adoc note on Sv32). On
RV32, Whisper takes the bytes after 0xFFFFFFFF of a misaligned load or store, and the upper half of a 32-bit
instruction at 0xFFFFFFFE, from 0x1_0000_0000 when there is no translation.

- `rv32-address-wrap.S` runs on whisper-rv32-max as shipped (`whisper.json`: RAM at 0xFFFFFFFE and at
  0x1_0000_0000, no access at 0-1023). In M-mode: `lw` at 0xFFFFFFFE and `lhu` at 0xFFFFFFFF must raise a load
  access fault (or address-misaligned), `sw` at 0xFFFFFFFE a store access fault (or address-misaligned), and a
  32-bit instruction at 0xFFFFFFFE an instruction access fault with `mepc` = 0xFFFFFFFE; and in S-mode with `satp`
  = Bare, `lw` at 0xFFFFFFFE must raise a load access fault (or address-misaligned).
- `rv32-address-wrap-ram.S` runs with `whisper-wrapmem.json` (whisper-rv32-max with addresses 0-4095 made RAM) and
  checks the bytes the same accesses read and write: `lw` at 0xFFFFFFFE reads 0x2211bbaa, `lhu` at 0xFFFFFFFF
  reads 0x11bb, `sw` at 0xFFFFFFFE writes bytes 0 and 1, and the instruction at 0xFFFFFFFE takes its upper half
  from address 0 (`addi x7, x0, 0x55`).

Run: `./run.sh [path/to/whisper]` (prints PASS or FAIL per ELF and the failed checks; exit status 0 = all pass).
Each ELF runs as `whisper --maxinst 100000000:f --config <json> <elf>`.

Whisper master fa18e475 (`master.out`): in the first test every load and store completes and the instruction
executes with its upper half from 0x1_0000_0000, after which the next fetch, at 0x2, faults (`mepc` = 2); in the
second, `lw` reads 0x0000bbaa, `lhu` 0x00bb, `sw` leaves bytes 0 and 1 unchanged and the instruction is not built
from address 0. With the second part wrapped at 2^32 (`fixed.out`), both tests pass.

Built with the riscv-arch-test act4 framework (`tests/env`, tree at 205129dbd8) and the check macros in
`include/sa.h` and `include/ai_macros.h` (the `.S` files include them as `../common/sa.h`): each `.S` was put in
a `<testdir>/ai/<Suite>/` directory and built with
`act config/whisper/whisper-rv32-max/test_config.yaml --test-dir <testdir> --extensions <Suite>` (the second with a
copy of that configuration whose whisper.json is `whisper-wrapmem.json`).

Other simulators (Spike c20813c, Sail master 81184531, stock Imperas Y-2026.09): `rv32-address-wrap` passes on Spike and Sail; on Imperas imperas-rv32gck (no memory at 0xFFFFFFFE) it does nothing. Sail does not wrap either (sail-riscv#282): with RAM at 0 it fails `rv32-address-wrap-ram`.
