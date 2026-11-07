# whisper-pmp-roz-pmpaddr

Whisper skips a PMP entry whose `pmpaddr` register is read-only zero (write mask and poke mask 0, reset 0), whatever
its `pmpcfg` byte holds, and turns PMP off entirely when every `pmpaddr` is read-only zero. A read-only-zero
`pmpaddr` is still an implemented entry whose address is 0 (machine.adoc, norm:pmp_csrs_warl_access: "All PMP CSR
fields are *WARL* and may be read-only zero."). With NAPOT, `pmpaddr` = 0 is the 8-byte region at 0 when G = 0, or
the 2^(G+2)-byte region at 0 when G >= 2, since `pmpaddr`[G-2:0] then read as ones. With TOR, `pmpaddr` = 0 matches
nothing.

`pmp_roz.S` is a standalone bare-metal M-mode test, built without C. It runs on the whisper-rv64-max and
whisper-rv32-max configurations of the riscv-arch-test ext-cfg tree, with addresses 0-1023 made readable (ACT makes
them inaccessible) and with either `pmpaddr8` read-only zero (`whisper-rv*.json`) or every `pmpaddr` read-only zero
(`whisper-rv*-roall.json`). The grain is 0x1000 (G = 10). x31 is the bitmask of failed checks and `tohost` =
(x31 << 1) | 1.

- check 1: reference. With every entry OFF, an M-mode `lw` from address 0 does not trap. If it does (no memory at 0),
  check 2 cannot run.
- check 2: `pmpaddr8` = 0 and `pmp8cfg` = 0x98 (L = 1, A = NAPOT, R = W = X = 0). The entry covers address 0 and is
  locked, so an M-mode `lw` from 0 raises a load access fault (norm:pmp_rwx_check).
- check 3: entries 0-7 OFF, `mstatus.MPRV` = 1, MPP = S. A `lw` from RAM matches no entry, and at least one entry is
  implemented, so it raises a load access fault (norm:pmp_no_entry_match).
- bit 8: unexpected trap (s10 = mcause).

Whisper 6b8cce1a:

    whisper-rv64.json      x31 = 0x4 FAIL
    whisper-rv64-roall.json x31 = 0xc FAIL
    whisper-rv32.json      x31 = 0x4 FAIL
    whisper-rv32-roall.json x31 = 0xc FAIL

With `pmpaddr8` read-only zero, entry 8 is never defined (check 2). With every `pmpaddr` read-only zero, PMP is off,
so the S-mode access also succeeds (check 3). Cause: `Hart::updateMemoryProtection` (`Hart.cpp`, line 894) skips any
entry whose `pmpaddr` has poke mask 0 and reset value 0, and sets `pmpEnabled_` only from the entries it did not skip
(line 907).

The same ELFs on the other simulators, whose `pmpaddr8` is writable (the test writes 0 to it):

- Spike f90d5af with memory at 0 (`spike --no-dm -m0x0:0x1000,0x80000000:0x10000000 --isa=...`): x31 = 0, pass.
- Sail 0.16 with its ROM region moved to 0-0x1fff: pass. With `usable_count` = 0 (every entry read-only zero, `count`
  = 64), check 3 still passes; only check 2 fails, because `pmp8cfg` is then read-only zero too.
- Spike and Sail with their stock memory maps, QEMU 11.1.3 and master 76fdb33 (`-cpu max`, `q_rv*.elf`) and Imperas
  Y-2026.09: no memory at address 0, so reference check 1 fails and check 2 cannot run. Check 3 passes on all of them.

## Run

    ./run.sh [path/to/whisper]     # prebuilt w_rv64.elf and w_rv32.elf, both configurations
    make                           # rebuild with riscv64-unknown-elf-gcc (q_rv*.elf: QEMU test-finisher exit)
