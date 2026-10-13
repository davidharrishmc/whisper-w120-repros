# whisper: without S, mstateen0 does not gate U-mode access

tenstorrent/whisper#120 item 32. smstateen.adoc: "For every bit with a defined purpose in
an `sstateen` CSR, the same bit is defined in the matching `mstateen` CSR to control
access below machine level to the same state." On a hart with U but no S there is no
sstateen, so mstateen0 controls U-mode directly. `isStateEnabled` picks sstateen0 as the
controlling CSR for every U-mode access (`CsRegs.cpp:8699` at f069895c) and, because
sstateen0 is not implemented, returns "enabled" (line 8709): mstateen0 is ignored.

The only state whisper gates this way from U-mode is custom CSRs (mstateen0.C), so the
problem is visible only with a configuration that defines a custom CSR. `whisper.json` is
the ACT derived configuration rv64-max-no-s (M+U, Smstateen) plus a custom U-mode CSR
`ucustom800` at 0x800; `whisper-stock.json` is the unmodified configuration.

`W120UCustom_nos-00.S` (riscv-arch-test) clears mstateen0.C, switches to U-mode and reads
CSR 0x800, which must raise an illegal-instruction exception (it also traps on harts that
have no CSR 0x800, which is why Sail, Spike and stock whisper pass).

Files: `W120UCustom_nos-00-{whisper,spike,sail}.elf`, `whisper.json`, `whisper-stock.json`,
`spike-args.txt`, `sail.json`.

    ./run.sh [whisper] [spike] [sail_riscv_sim]

| | whisper f069895c | whisper + fix |
|---|---|---|
| whisper-stock.json | PASS | PASS |
| whisper.json (custom CSR 0x800) | FAIL (trap count mismatch: csrr 0x800 executes in U-mode) | PASS |

Spike d6cfe9e and Sail 0.15: PASS. The same holds on rv32-max-no-s.
