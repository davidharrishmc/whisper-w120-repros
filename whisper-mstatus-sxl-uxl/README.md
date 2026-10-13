# whisper-mstatus-sxl-uxl

tenstorrent/whisper#120 item 23: on RV64, Whisper's default mstatus has SXL=UXL=2 even when
the hart has no S-mode or no U-mode. machine.adoc: "When MXLEN=64, if S-mode is not
supported, then SXL is read-only zero" and likewise UXL without U-mode.

`W120Mstatus_xl-00.S` is a self-checking riscv-arch-test (ACT) test that records
mstatus[35:32] after reset, after setting and after clearing those bits (expected values
come from Sail).

| dir | hart | expected SXL/UXL |
|---|---|---|
| w120-rv64-m | RV64I, M-mode only | 0 / 0 |
| w120-rv64-mu | RV64I, M and U | 0 / 2 |

Each directory has `whisper.json` (the riscv-arch-test derived configuration with the
`csr.mstatus` override removed, so Whisper uses its default reset value and masks),
`spike-args.txt`, `sail.json` and an ELF per simulator.

Run `./run.sh [whisper] [spike] [sail_riscv_sim]`. Spike d6cfe9e and Sail 0.15 pass. Whisper
master f069895c fails both (mstatus reads 0xa00001800 after reset):

```
whisper  w120-rv64-m            W120Mstatus_xl-00            FAIL (first mismatch: bin: reset)
whisper  w120-rv64-mu           W120Mstatus_xl-00            FAIL (first mismatch: bin: reset)
```

With the fix both pass.
