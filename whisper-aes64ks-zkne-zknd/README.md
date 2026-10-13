# whisper-aes64ks-zkne-zknd

Whisper executes `aes64ks1i` and `aes64ks2` only when both Zkne and Zknd are enabled. `crypto.cpp`
`execAes64ks1i` and `execAes64ks2` (master f069895c, lines 203 and 235) check
`if (not isRvzkne() or not isRvzknd() or not isRv64())`. zk.adoc: "The aes64ks1i and aes64ks2 instructions are
present in both the zknd and zkne extensions." So an RV64 hart with only one of them must execute both.

The four .S files are the riscv-arch-test (act4) tests of those names. They run on two harts:

- `zkne/`: RV64I + Zicsr + Zkne (derived configuration RVI20U64-zkne; Spike `--isa=rv64i_zicsr_zkne`).
- `zknd/`: RV64I + Zicsr + Zknd (derived configuration RVI20U64-zknd; Spike `--isa=rv64i_zicsr_zknd`).

The ELFs are self-checking: expected values come from Sail. There is one ELF per simulator because the act4
model macros (halt, console) differ.

Expected (Sail, Spike): `RVCP-SUMMARY: TEST PASSED` for all four. Whisper master f069895c raises an
illegal-instruction exception at the first aes64ks1i/aes64ks2 of each test and stops with
`Actual signature offset: 0x0` (expected 0xbf0 for Zkne-aes64ks1i-00). The other Zkne and Zknd tests pass.

## Run

    ./run.sh [path/to/whisper] [path/to/spike] [path/to/sail_riscv_sim]

prints PASS/FAIL per simulator for each test. On whisper f069895c every whisper line is FAIL and every spike
and sail line is PASS. With the fix (require Zkne or Zknd), whisper prints PASS for all four.

Files: per hart `whisper.json`, `spike_args.txt` (spike options), `sail.json` (Sail 0.15 configuration) and the
three ELFs per test built from the .S by the act4 framework.
