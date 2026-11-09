# Whisper: Zalasr load-acquire and store-release raise on any misaligned address, even inside one misaligned atomicity granule

- unpriv/zalasr.adoc:27-28, norm:Zalasr_misaligned_pma_relax and norm:Zalasr_misaligned_single_op: "The misaligned
  atomicity granule PMA ... optionally relaxes this alignment requirement. If all accessed bytes lie within the same
  misaligned atomicity granule, the instruction will not raise an exception for reasons of address alignment, and
  the instruction will give rise to only one memory operation for the purposes of RVWMO--i.e., it will execute
  atomically."
- priv/machine.adoc:3088-3098, norm:pma_mag_insts / norm:pma_mag_op_within: the PMA applies to "the load-acquire and
  store-release instructions defined in the Zalasr extension" (this list gained Zalasr on main in July 2026;
  the Zalasr chapter has always had the rule above).

`whisper.json` is the riscv-arch-test whisper-rv64-max configuration with `zalasr` added to the ISA string (the
stock one does not enable Zalasr). Its main memory has the `mag16` attribute (a 16-byte misaligned atomicity
granule), and misaligned AMOs inside a granule already complete on Whisper.

`whisper-zalasr-misaligned-granule.S` (M-mode, 16-byte-aligned buffer holding bytes 00 11 ... ff) does `lw.aq`,
`lh.aq`, `ld.aq` at offset 1 and `sw.rl` at offset 5, `sh.rl` at offset 7, `sd.rl` at offset 3 (all inside the
granule) and checks that none traps and that the values are right; then `ld.aq` at offset 9 and `sd.rl` at offset
12, which cross the granule, must raise a misaligned or access fault. It is skipped (passes) if an aligned `lw.aq`
traps (Zalasr not enabled). It fails with a bitmask of failed checks; `run.sh` decodes it.

Run: `./run.sh path/to/whisper`. The ELF was built with the riscv-arch-test (ACT4) framework (`tests_ai`
self-checking harness, Sail as the reference model); the `.S` file is the source.

Whisper master fa18e475 (`master.out`): all six accesses inside the granule trap (mcause 5 for the loads, 7 for the
stores, mtval = the misaligned address); the two granule-crossing accesses trap as required. With the natural
alignment check applied only to LR and SC (`fixed.out`), it passes.

Other simulators: Spike c20813c with `zalasr` added to its `--isa` string (it implements Zama16b) passes. Sail
master 81184531 and Imperas Y-2026.09 do not implement Zalasr, so the test cannot run on them.
