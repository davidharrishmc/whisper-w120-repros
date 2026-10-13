# whisper-rorw-zbkb

Whisper raises an illegal-instruction exception for `rorw` on an RV64 hart with Zbkb but without Zbb.
`bitmanip.cpp` `execRorw` (master f069895c, line 359) checks `if (not isRv64() or not isRvzbb())`, while
`execRolw` (line 336) and `execRoriw` (line 382) accept either Zbb or Zbkb. zbkb.adoc lists rorw among the Zbkb
instructions (RV64 only).

`Zbkb-rorw-00.S` is the riscv-arch-test (act4) test of that name. The hart is RV64I + Zicsr + Zbkb, no Zbb
(derived configuration RVI20U64-zbkb; Spike `--isa=rv64i_zbkb_zicsr`).

The ELFs are self-checking: expected values come from Sail. There is one ELF per simulator because the act4
model macros (halt, console) differ.

Expected (Sail, Spike): `RVCP-SUMMARY: TEST PASSED`. Whisper master f069895c traps at the first rorw and stops
with `Actual signature offset: 0x0`, `Expected signature offset: 0x1248`.

## Run

    ./run.sh [path/to/whisper] [path/to/spike] [path/to/sail_riscv_sim]

prints PASS/FAIL per simulator. On whisper f069895c:

    == Zbkb-rorw-00
    whisper: FAIL
    spike:   PASS
    sail:    PASS

With the fix (`execRorw` accepts Zbkb like rolw/roriw), whisper prints PASS.

Files: `whisper.json`, `spike_args.txt` (spike options), `sail.json` (Sail 0.15 configuration) and the three
ELFs built from the .S by the act4 framework.
