# whisper: RV32 sieh/siph/vsieh/vsiph writable while their delegation/enable bits are zero

tenstorrent/whisper#120 item 31. On RV32 with Smaia/Ssaia and H, Whisper defines `sieh`, `siph`,
`vsieh` and `vsiph` with an all-ones write mask (`CsRegs.cpp:6040-6101` at f069895c), so they hold
whatever software writes, independent of `midelegh`/`mvienh` and `hidelegh`/`hvienh`. AIA
(riscv-aia 9507866):

- MSLevel.adoc:520-521: "A bit in `sip` is read-only zero when the corresponding bits in `mideleg`
  and `mvien` are both zero."
- MSLevel.adoc:543-546: "A bit in `sie` is writable if and only if the corresponding bit is set in
  either `mideleg` or `mvien`. [...] As usual, bits that are not writable in `sie` must be
  read-only zeros."
- VSLevel.adoc:319-320 and 332-338: the same rules for `vsip`/`vsie` with `hideleg`/`hvien`
  (interrupts 13-63).

`aia-high.S` (bare metal, HTIF tohost, RV32) writes 0 to `midelegh`, `mvienh`, `hidelegh` and
`hvienh`, reads them back (so it does not assume which of their bits are writable), writes all
ones to `sieh`, `siph`, `vsieh` and `vsiph`, and checks that every bit whose two control bits read
back 0 reads 0. It runs every check and writes `(failmask << 1) | 1` to tohost (bit 0 `sieh`,
bit 1 `siph`, bit 2 `vsieh`, bit 3 `vsiph`, bit 4 unexpected trap), or 1 if all pass.

Files: `aia-high-rv32.elf` (one ELF for all simulators; built with
`riscv64-unknown-elf-gcc -march=rv32gch_zicsr_smstateen_smaia_ssaia -mabi=ilp32 -nostdlib
-nostartfiles -T link.ld aia-high.S -o aia-high-rv32.elf`), `whisper-rv32.json` (riscv-arch-test
derived configuration whisper-rv32-max-base), `spike-args-rv32.txt`, `sail-rv32.json`.

    ./run.sh [whisper] [spike] [sail_riscv_sim]

| whisper f069895c | whisper + fix | Spike d6cfe9e | Sail 0.15 |
|---|---|---|---|
| FAIL (failmask 15: all four read 0xffffffff) | PASS | PASS | FAIL (failmask 16: trap, no Smaia/Ssaia) |

Sail 0.15 does not implement Smaia/Ssaia, so the CSRs trap there; Spike is the reference.
