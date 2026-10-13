# whisper-mstatus-s-u-fields

tenstorrent/whisper#120 item 22: with the default mstatus masks (no `csr.mstatus` entry in
whisper.json), Whisper keeps mstatus fields writable that must be read-only zero when the
hart lacks S-mode, U-mode or the vector registers:

| field | read-only zero when (machine.adoc) |
|---|---|
| SIE, SPIE, MXR, SUM, TVM, TSR | S-mode not supported |
| SUM | satp.MODE is read-only zero (Bare only) |
| MPRV | U-mode not supported |
| TW | no mode less privileged than M |
| VS | neither the v registers nor S-mode |

`W120Mstatus_sfields-00.S` is a self-checking riscv-arch-test (ACT) test: it sets each field
with `csrs mstatus` and checks the value read back (expected values come from Sail). VS is
checked only on harts without S and V, because with S it is optionally read-only zero.

Configurations (one directory each, with `whisper.json`, `spike-args.txt`, `sail.json` and an
ELF built for each simulator). The whisper.json files are the riscv-arch-test derived
configurations with the `csr.mstatus` override removed, so Whisper uses its default masks:

| dir | hart |
|---|---|
| w120-rv64-m | RV64I, M-mode only |
| w120-rv64-mu | RV64I, M and U |
| w120-rv32-mu | RV32I, M and U |
| w120-rv64-msu | RV64I, M, S and U, satp Bare only |

Run `./run.sh [whisper] [spike] [sail_riscv_sim]`. Spike d6cfe9e and Sail 0.15 pass every
configuration. Whisper master f069895c fails all four:

```
whisper  w120-rv64-m            W120Mstatus_sfields-00       FAIL (first mismatch: bin: sie)
whisper  w120-rv64-mu           W120Mstatus_sfields-00       FAIL (first mismatch: bin: sie)
whisper  w120-rv32-mu           W120Mstatus_sfields-00       FAIL (first mismatch: bin: sie)
whisper  w120-rv64-msu          W120Mstatus_sfields-00       FAIL (first mismatch: bin: sum)
```

With the fix all four pass. The test source needs the riscv-arch-test framework to rebuild;
the ELFs are included.
