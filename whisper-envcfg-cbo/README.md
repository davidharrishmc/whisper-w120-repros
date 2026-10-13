# whisper-envcfg-cbo

tenstorrent/whisper#120 item 25: without Zicbom and Zicboz, Whisper keeps CBIE, CBCFE and CBZE
writable in menvcfg, senvcfg and henvcfg. machine.adoc: "When the Zicbom extension is not
implemented, CBIE is read-only zero" (same for CBCFE; CBZE with Zicboz); supervisor.adoc and
hypervisor.adoc say the same for senvcfg and henvcfg.

`W120Envcfg_cbo-00.S` is a self-checking riscv-arch-test (ACT) test that sets bits 7:4 of
menvcfg, senvcfg (with S) and henvcfg (with H) and checks the value read back (expected values
come from Sail).

| dir | hart (no Zicbom, no Zicboz) |
|---|---|
| w120-rv64-mu | RV64I, M and U |
| w120-rv64-msu | RV64I, M, S and U |
| w120-rv64-h | RV64I, M, S, U and H |

Each directory has `whisper.json` (the riscv-arch-test derived configuration with the
mstatus/menvcfg/senvcfg/henvcfg/vsstatus overrides removed, so Whisper uses its default masks),
`spike-args.txt`, `sail.json` and an ELF per simulator.

Run `./run.sh [whisper] [spike] [sail_riscv_sim]`. Spike d6cfe9e and Sail 0.15 pass. Whisper
master f069895c fails all three (menvcfg reads back 0xf0; the test stops at the first
mismatch):

```
whisper  w120-rv64-mu           W120Envcfg_cbo-00            FAIL (first mismatch: bin: menvcfg)
whisper  w120-rv64-msu          W120Envcfg_cbo-00            FAIL (first mismatch: bin: menvcfg)
whisper  w120-rv64-h            W120Envcfg_cbo-00            FAIL (first mismatch: bin: menvcfg)
```

With the fix all three pass, including the senvcfg and henvcfg checks.
