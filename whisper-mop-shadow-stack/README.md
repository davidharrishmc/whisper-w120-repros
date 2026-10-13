# whisper-mop-shadow-stack

With shadow stacks active, Whisper treats every `mop.r.N` and `mop.rr.N` as a shadow-stack instruction. The
decoder maps all 32 mop.r.N and all 8 mop.rr.N encodings to the same `mop_r` / `mop_rr` entries
(`Decoder.cpp`, master f069895c, lines 3182-3223), and `execMop_r` / `execMop_rr` (`Hart.cpp` lines 15019 and
15048) look only at the registers: with `isShadowStackEnabled`, any mop.r.N with rd=0 and rs1 in {x1, x5} runs
sspopchk, any mop.r.N with rd!=0 and rs1=0 runs ssrdp, and any mop.rr.N with rd=rs1=0 and rs2 in {x1, x5} runs
sspush. cfi.adoc: sspush is encoded using mop.rr.7, sspopchk and ssrdp using mop.r.28, and "When a mop.rr.7 or
mop.r.28 encoding is not used by the Zicfiss extension, the corresponding instruction adheres to its
Zimop-defined behavior"; all other mop encodings are plain Zimop (write 0 to rd).

`W120Zicfiss_mop-00.S` is a small act4-format test. The hart is the act4 whisper RV64 max configuration
(derived configuration rv64-max-base; Spike with the matching `--isa`). It sets menvcfg.SSE and ssp
(0x80001000) in M-mode, enters S-mode (satp Bare), and executes:

- `mop.r.28 x10, x0` (ssrdp): positive control, x10 = ssp;
- `mop.r.0 x10, x0` and `mop.r.27 x10, x0`: x10 must be 0;
- `mop.r.0 x0, x1`, `mop.rr.0 x0, x0, x1`, `mop.rr.3 x0, x0, x5`: no effect (no shadow-stack access, no trap,
  ssp unchanged).

The ELFs are self-checking: expected values come from Sail. There is one ELF per simulator because the act4
model macros (halt, console) differ.

Expected (Sail, Spike): `RVCP-SUMMARY: TEST PASSED`. Whisper master f069895c runs ssrdp for mop.r.0:

    RVCP: Test Info: mop.r.0 rd!=0, rs1=x0
    RVCP: Instruction: 0x81c04573
    RVCP: Register: x10
    RVCP: Bad Value:      0x0000000080001000
    RVCP: Expected Value: 0x0000000000000000

## Run

    ./run.sh [path/to/whisper] [path/to/spike] [path/to/sail_riscv_sim]

prints PASS/FAIL per simulator. On whisper f069895c:

    == W120Zicfiss_mop-00
    whisper: FAIL
    spike:   PASS
    sail:    PASS

With the fix (`execMop_r` / `execMop_rr` take the shadow-stack paths only for mop.r.28 / mop.rr.7), whisper
prints PASS.

Files: `whisper.json`, `spike_args.txt` (spike options), `sail.json` (Sail 0.15 configuration) and the three
ELFs built from the .S by the act4 framework.
