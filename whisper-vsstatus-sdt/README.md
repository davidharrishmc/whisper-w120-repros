# whisper-vsstatus-sdt

tenstorrent/whisper#120 item 30: on a hart with H and Ssdbltrp, Whisper never lets software
set vsstatus.SDT. ssdbltrp.adoc: "If the hypervisor extension is additionally implemented,
then the extension adds the henvcfg.DTE and the vsstatus.SDT fields"; hypervisor.adoc: "When
henvcfg.DTE is zero, ... the vsstatus.SDT bit is read-only zero."

`W120Ssdbltrp_vsstatus-00.S` is a self-checking riscv-arch-test (ACT) test that sets
menvcfg.DTE and henvcfg.DTE, sets vsstatus.SDT and checks it reads back 1, then clears
henvcfg.DTE and checks that vsstatus.SDT reads 0 (expected values come from Sail).

| dir | hart |
|---|---|
| w120-rv64-h-ssdbltrp | RV64I, M, S, U, H, Ssdbltrp |
| w120-rv32-h-ssdbltrp | RV32I, M, S, U, H, Ssdbltrp |

Each directory has `whisper.json` (the riscv-arch-test RVI20U64/RVI20U32 + H derived
configuration plus Ssdbltrp, with the mstatus/vsstatus/menvcfg/senvcfg/henvcfg overrides
removed), `spike-args.txt`, `sail.json` and an ELF per simulator.

Run `./run.sh [whisper] [spike] [sail_riscv_sim]`. Spike d6cfe9e and Sail 0.15 pass. Whisper
master f069895c fails both:

```
whisper  w120-rv64-h-ssdbltrp   W120Ssdbltrp_vsstatus-00     FAIL (first mismatch: bin: sdt_dte1)
whisper  w120-rv32-h-ssdbltrp   W120Ssdbltrp_vsstatus-00     FAIL (first mismatch: bin: sdt_dte1)
```

With the fix both pass.
