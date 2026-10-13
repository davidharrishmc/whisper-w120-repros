# whisper: mstateen0.IMSIC is writable on a hart without an IMSIC

tenstorrent/whisper#120 item 33. smstateen.adoc: "Bits in any `stateen` CSR that are
defined to control state that a hart doesn't implement are read-only zeros for that
hart." Whisper makes mstateen0/hstateen0 bit 58 (IMSIC) writable whenever Smaia is
enabled (`CsRegs.cpp:2502` at f069895c), even when the configuration has no `imsic`
section and the hart has no IMSIC (stopei/mtopei/vstopei then raise illegal-instruction).

`W120Imsic_bit58-00.S` is a riscv-arch-test (ACT) test: it sets bit 58 of mstateen0 (bit
26 of mstateen0h on RV32) and of hstateen0 and records the bit. The configuration is the
hand-written ACT whisper-rv64-max (Smaia, Ssaia, H, Smstateen, no `imsic` section).
The ELFs are self-checking; expected values come from Sail.

Files: `W120Imsic_bit58-00-{whisper,spike,sail}.elf` (built by ACT for the whisper-rv64-max,
spike-rv64-max and a Sail twin of whisper-rv64-max), `whisper.json`, `spike-args.txt`, `sail.json`.

    ./run.sh [whisper] [spike] [sail_riscv_sim]

| whisper f069895c | whisper + fix | Spike d6cfe9e | Sail 0.15 |
|---|---|---|---|
| FAIL (mstateen0 bit 58 reads 1) | PASS | PASS | PASS |

Neither reference model implements Smaia here (Sail 0.15 has no Smaia; spike-rv64-max has
no smaia), so they pass because they have no IMSIC either, which is the property under
test. With the fix, a configuration that has an `imsic` section (for example the derived
whisper-rv64-max-base) still has a writable bit 58. The same failure shows up in ACT
`Smstateen-00` on whisper-rv64-max/rv32-max (`mstateen0_set_bit_58`).
