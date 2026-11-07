# whisper-sireg-counter-side-effects

With Smcdeleg/Ssccfg, a write through `sireg`, `sireg2`, `sireg4` or `sireg5` to a delegated counter CSR changes the
aliased CSR's value but skips every side effect that a direct write of that CSR has. smcdeleg.adoc: "When a counter
_i_ is delegated (`mcounteren`[_i_]=1 and `menvcfg`.CDE=1), the register state associated with counter _i_ can be
read or written via `sireg*`, while `siselect` holds 0x40+__i__."

`sireg_counter.S` is a standalone bare-metal test, built without C, for the whisper-rv64-max and whisper-rv32-max
configurations of the riscv-arch-test ext-cfg tree (`whisper-rv64.json`, `whisper-rv32.json`; Smcdeleg, Ssccfg,
Sscofpmf, Smcntrpmf, Smcsrind enabled). M-mode sets `menvcfg(h).CDE`, `mcounteren` = all ones and `mstateen0` = all
ones, then runs the checks in S-mode. x31 is the bitmask of failed checks and `tohost` = (x31 << 1) | 1.

- check 1: `siselect` = 0x42, `sireg` (instret) := 1000, then `csrr sireg` reads the same value as check 6 (1000).
- check 2: `siselect` = 0x43, `sireg2` (RV64) / `sireg5` (RV32) sets `hpmevent3.OF`; `scountovf` reads 0x8.
- check 3: `siselect` = 0x42, `sireg2` (RV64) / `sireg5` (RV32) sets `instretcfg.SINH`; `instret` does not advance
  over the next 11 S-mode instructions (delta 0).
- checks 4, 5, 6: references, the same writes done directly from M-mode (`mhpmevent3(h)`, `minstretcfg(h)`,
  `minstret`).
- bit 8: unexpected trap (s10 = mcause).

Whisper 6b8cce1a: x31 = 0xe on both XLENs (checks 1, 2 and 3 fail; checks 4-6 pass). `scountovf` stays 0,
`instret` advances by 11, and `instret` reads 1001. On RV32, `sireg5` writes are also dropped on master (tenstorrent/whisper#244, fixed
by tenstorrent/whisper#248); with that PR applied, RV32 still gives x31 = 0xe.

    rv64: x31 = 0xe FAIL
    rv32: x31 = 0xe FAIL

QEMU 11.1.3 and master 76fdb33 (`-cpu max -icount shift=0`, `q_rv*.elf`): x31 = 0x40, checks 1-5 pass. Check 6
fails because QEMU's `instret` reads 1001 after a direct `csrw minstret, 1000` too, so its `sireg` write matches
its direct write.

## Run

    ./run.sh [path/to/whisper]     # prebuilt w_rv64.elf and w_rv32.elf
    make                           # rebuild with riscv64-unknown-elf-gcc (q_rv*.elf: QEMU test-finisher exit)
    qemu-system-riscv64 -nographic -machine virt -cpu max -icount shift=0 -bios q_rv64.elf; echo $?   # x31
