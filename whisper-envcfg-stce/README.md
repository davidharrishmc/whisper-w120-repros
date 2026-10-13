# whisper-envcfg-stce

tenstorrent/whisper#120 item 24: without Sstc, Whisper's menvcfg.STCE (and henvcfg.STCE with
H) is writable. machine.adoc: "When the Sstc extension is not implemented, STCE is read-only
zero."

`W120Envcfg_stce-00.S` is a self-checking riscv-arch-test (ACT) test that sets STCE (menvcfg
bit 63, menvcfgh bit 31 on RV32) in menvcfg and, with H, in henvcfg, and checks the value read
back (expected values come from Sail).

| dir | hart (none has Sstc) |
|---|---|
| w120-rv64-mu | RV64I, M and U |
| w120-rv32-mu | RV32I, M and U |
| w120-rv64-h | RV64I, M, S, U and H |

Each directory has `whisper.json` (the riscv-arch-test derived configuration with the
mstatus/menvcfg/senvcfg/henvcfg/vsstatus overrides removed, so Whisper uses its default masks),
`spike-args.txt`, `sail.json` and an ELF per simulator.

Run `./run.sh [whisper] [spike] [sail_riscv_sim]`. Spike d6cfe9e and Sail 0.15 pass. Whisper
master f069895c fails all three:

```
whisper  w120-rv64-mu           W120Envcfg_stce-00           FAIL (first mismatch: bin: menvcfg)
whisper  w120-rv32-mu           W120Envcfg_stce-00           FAIL (first mismatch: bin: menvcfg)
whisper  w120-rv64-h            W120Envcfg_stce-00           FAIL (first mismatch: bin: menvcfg)
```

With the fix all three pass.
