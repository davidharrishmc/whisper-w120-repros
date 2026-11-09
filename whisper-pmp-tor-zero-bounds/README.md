# Whisper: a TOR PMP entry with both bounds 0 matches physical addresses 0-3

A TOR entry matches pmpaddr[i-1] <= y < pmpaddr[i] (y < pmpaddr[0] for entry 0), so with a top bound of 0 it
matches nothing (machine.adoc, norm:pmp_a_field_tor and the note after it). Whisper makes such an entry match
physical addresses 0-3 when the bottom bound is also 0.

`pmp-tor-zero-bounds.S` needs memory at physical address 0: `whisper.json` is the riscv-arch-test whisper-rv64-max
configuration with the no-access PMA region 0-1023 made readable and writable (it does nothing when an M-mode load
from 0 traps). Entry 15 is NAPOT over all addresses with RWX.

- Case 1: entry 0 TOR, pmpaddr0 = 0, RWX; entry 1 NAPOT [0, 4 KiB) with no permissions.
- Case 2: entry 0 OFF, pmpaddr0 = 0; entry 1 TOR, pmpaddr1 = 0, RWX; entry 2 NAPOT [0, 4 KiB) with no permissions.

In both cases a U-mode `lw` from address 0 must take a load access fault (mcause 5).

Run: `./run.sh [path/to/whisper]` (prints PASS or FAIL and the failed checks; exit status 0 = pass). The ELF runs as
`whisper --maxinst 100000000:f --config whisper.json pmp-tor-zero-bounds.elf`.

Whisper master fa18e475 (`master.out`): both loads complete (the TOR entry matches 0-3 and grants RWX). With the
empty TOR range kept empty (`fixed.out`), the test passes.

Built with the riscv-arch-test act4 framework (`tests/env`, tree at 205129dbd8) and the check macros in
`include/sa.h` and `include/ai_macros.h` (the `.S` files include them as `../common/sa.h`): each `.S` was put in
a `<testdir>/ai/<Suite>/` directory and built with
`act <copy of config/whisper/whisper-rv64-max with this whisper.json>/test_config.yaml --test-dir <testdir> --extensions <Suite>`.

Other simulators (Spike c20813c, Sail master 81184531, stock Imperas Y-2026.09): Sail and Imperas, on copies of their configurations with memory at address 0, pass both cases. Spike was not run with memory at address 0.
