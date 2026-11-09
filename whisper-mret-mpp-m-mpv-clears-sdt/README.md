# Whisper: MRET with mstatus.MPP = M and MPV = 1 clears sstatus.SDT

MRET ignores MPV when MPP = M (hypervisor.adoc norm:mstatus_mpv_op: V "remains 0"), so the new privilege mode is M.
With Smdbltrp and Ssdbltrp, MRET clears `sstatus.SDT` only when the new privilege mode is U, VS or VU
(machine.adoc norm:sstatus_sdt_clr_mret_sret). Whisper clears SDT whenever MPV = 1.

`whisper-mret-mpv-sdt.S` runs in M-mode: it sets `menvcfg.DTE` (`menvcfgh` on RV32) and `mstatus.SDT` (and checks
nothing if SDT cannot be set), sets MPP = M and MPV = 1 (`mstatush.MPV` on RV32), sets `mepc` to the next
instruction, executes `mret` and checks that `mstatus.SDT` is still 1.

Run: `./run.sh path/to/whisper` (exit status 0 = pass). It runs `whisper-mret-mpv-sdt-rv64.elf` with
`whisper-rv64.json` and `whisper-mret-mpv-sdt-rv32.elf` with `whisper-rv32.json`, which are riscv-arch-test's
`config/whisper/whisper-rv64-max/whisper.json` and `whisper-rv32-max/whisper.json`, unchanged.

Whisper master fa18e475:

```
FAIL whisper-mret-mpv-sdt-rv64.elf
  RVCP: Test Info: mstatus.SDT after MRET with MPP=M, MPV=1 (new mode M: SDT unchanged)
FAIL whisper-mret-mpv-sdt-rv32.elf
  RVCP: Test Info: mstatus.SDT after MRET with MPP=M, MPV=1 (new mode M: SDT unchanged)
```

With the fix, both pass.

The ELFs were built with the riscv-arch-test act4 framework (riscv/riscv-arch-test#3162, commit 205129dbd8, for
the whisper-rv64-max and whisper-rv32-max configurations); `sa.h` has the `SA_CHECK` macro. Rebuilding needs that
framework.

Other simulators (Spike c20813c, Sail master 81184531, stock Imperas Y-2026.09), with the same test built for each: Spike, Sail and Imperas pass on RV64, and Spike and Sail on RV32 (riscv-arch-test's RV32 Imperas configuration has no H, so the test is not built for it).
