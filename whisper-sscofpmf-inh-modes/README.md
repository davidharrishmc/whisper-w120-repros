# whisper: Sscofpmf xINH bits writable for privilege modes that do not exist

tenstorrent/whisper#120 item 29. sscofpmf.adoc: "if the associated privilege mode is not
implemented, the bit is read-only zero." Whisper's mhpmevent write mask with Sscofpmf
only clears the reserved bits 57:56 (`CsRegs.cpp:4884-4893` at f069895c), so VSINH and
VUINH are writable on a hart without H (and SINH/UINH on a hart without S/U).
Smcntrpmf gates the same bits of mcyclecfg/minstretcfg correctly (`CsRegs.hpp:2353-2381`).

`W120Inh_modes-00.S` is a riscv-arch-test (ACT) test: it writes MINH, SINH, UINH, VSINH,
VUINH of mhpmevent3 (mhpmevent3h on RV32) and records the value read back. Configuration:
ACT derived configuration rv64-max-no-h (Sscofpmf, S and U, no H), expected 0x7000...0.

Files: `W120Inh_modes-00-whisper.elf`, `W120Inh_modes-00-sail.elf`, `whisper.json`,
`spike-args.txt`, `sail.json`. Spike runs the Sail ELF (pass/fail from its exit status):
the Spike derived row declares no writable HPM counters in its sail.json, which does not
match Spike, so the ELF built for that row cannot be used.

    ./run.sh [whisper] [spike] [sail_riscv_sim]

| whisper f069895c | whisper + fix | Spike d6cfe9e | Sail 0.15 |
|---|---|---|---|
| FAIL (reads 0x7c00000000000000) | PASS | PASS | PASS |

The same holds on rv32-max-no-h and RVI20U64-sscofpmf.
