# whisper-ssamoswap-zaamo

Whisper raises an illegal-instruction exception for `ssamoswap.w` / `ssamoswap.d` unless A is enabled.
`shadow-stack.cpp` `execSsamoswap_w` and `execSsamoswap_d` (master f069895c, lines 177 and 247) check
`isRva()`. cfi.adoc: "The Zicfiss extension depends on the Zicsr, Zimop and Zaamo extensions." So a hart with
Zicfiss and Zaamo but without Zalrsc (and therefore without A) must decode them. This is the shadow-stack twin
of #116 (amocas).

`W120Zicfiss_ssamoswap-00.S` is a small act4-format test. The hart is the act4 whisper RV64 max configuration
without Zalrsc (so Zaamo but not A; derived configuration rv64-max-no-zalrsc; Spike with the matching
`--isa`). In M-mode it executes `ssamoswap.w` and `ssamoswap.d`. priv cfi.adoc: "When the effective privilege
mode is M, memory access by an ssamoswap.w or ssamoswap.d instruction results in a store/AMO access-fault
exception", so the trap handler must record mcause 7 for both.

The ELFs are self-checking: expected values come from Sail. There is one ELF per simulator because the act4
model macros (halt, console) differ.

Expected (Sail, Spike): `RVCP-SUMMARY: TEST PASSED`. Whisper master f069895c:

    RVCP: Mismatching field: XCAUSE (trap signature word 1)
    RVCP: Expected value: 0x0000000000000007
    RVCP: Actual value:   0x0000000000000002
    RVCP: XEPC:    0x00000000800000ac
    RVCP: XTVAL:   0x00000000488324af

## Run

    ./run.sh [path/to/whisper] [path/to/spike] [path/to/sail_riscv_sim]

prints PASS/FAIL per simulator. On whisper f069895c:

    == W120Zicfiss_ssamoswap-00
    whisper: FAIL
    spike:   PASS
    sail:    PASS

With the fix (check Zaamo instead of A), whisper prints PASS.

Files: `whisper.json`, `spike_args.txt` (spike options), `sail.json` (Sail 0.15 configuration) and the three
ELFs built from the .S by the act4 framework.
