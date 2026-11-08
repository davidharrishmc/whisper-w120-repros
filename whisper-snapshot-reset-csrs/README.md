# Whisper: a snapshot leaves out mstatush = 0 on RV32, so the restore brings back MDT = 1 (and clears MIE)

`Hart::saveSnapshotRegs` leaves out a CSR whose value is 0 when its configured reset value is 0, assuming
that loading the snapshot (which starts from reset) gives it 0. Some CSR bits are set by reset code rather
than by the CSR's reset value. On RV32, `mstatush.MDT` (Smdbltrp) is set to 1 by `Hart::reset`, while the
`mstatush` reset value is 0. When software has cleared MDT, `mstatush` is 0 and is left out of the
snapshot, so the restored hart has MDT = 1 and its next trap into M-mode is a double trap ("Core entered
critical-error state due to an unexpected trap"). In the rv64-max and rv32-max configurations this is the
only CSR affected: the others whose value after reset differs from their configured reset value (`mstatus`
on RV64, `mideleg`, `sstatus`) are never 0.

The load order makes it worse: `loadSnapshotRegs` pokes `mstatus` before `mstatush`, so on RV32 the `mstatus`
poke sees MDT = 1 (still the reset value) and clears `mstatus.MIE` ("When MDT is set to 1, MIE is cleared");
the `mstatush` poke that follows, when the snapshot has one, restores MDT but not MIE.

`mdt.S` clears MDT, sets `mnstatus.NMIE` and `mstatus.MIE` (with `mie` = 0), runs a nop sled, then

- check 1: `mstatush` (RV32) / `mstatus` (RV64) shows MDT = 0;
- check 3: `mstatus.MIE` = 1;
- check 2: `ecall` from M-mode reaches the trap handler with mcause 11 (skipped if check 1 fails, because the
  ecall would then be a double trap; check 4 if the handler is not reached).

x31 = bitmask of failed checks; tohost = (x31 << 1) | 1. `run.sh` runs each ELF straight through, then
saves a snapshot after 40 instructions (in the sled; `--snapshotperiod 40 --snapshotdir snap-rv$x/s`) and
runs from it (`--loadfrom snap-rv$x/s0`). It prints the snapshot's `mstatus`/`mstatush` lines.

Expected: x31 = 0 for the straight and restored runs.

Whisper master 6b8cce1a (`master.out`): RV64 passes; the RV32 restored run gives x31 = 0xa (the snapshot has
no `mstatush` line, and MIE is cleared):

```
rv64 straight run: x31 = 0x0
  PASS
rv64 snapshot at instruction 40: pm 3 pc 0x8000005e c 0x300 0xa00001808 
rv64 restored from snapshot: x31 = 0x0
  PASS
rv32 straight run: x31 = 0x0
  PASS
rv32 snapshot at instruction 40: pm 3 pc 0x80000060 c 0x300 0x1808 
rv32 restored from snapshot: x31 = 0xa
  FAIL check 1: MDT = 1 after the restore
  FAIL check 3: MIE = 0 after the restore
```

With the post-reset CSR values recorded, a zero CSR left out only if reset also left it 0 (the snapshot now
has `c 0x310 0x0`), and `mstatush` poked before `mstatus` (`fixed.out`), all four runs pass.

Run: `./run.sh [path/to/whisper]` (prints the failed checks; exit status 0 = pass). Rebuild: `./build.sh`.

Other simulators: snapshot save/restore is a Whisper feature, so there is no equivalent to compare.
