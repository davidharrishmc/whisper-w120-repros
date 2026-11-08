# Whisper: snapshots do not save the debug triggers

`Hart::saveSnapshotRegs` writes each implemented CSR from its CSR object. The trigger registers are kept in
the `Triggers` object instead: `tdata1`/`tdata2`/`tdata3` reach only the trigger that `tselect` selects, and
their CSR objects are not used, so a snapshot keeps no trigger state. After a restore every trigger is
disabled: `tdata1` reads 0, and breakpoints (mcontrol6), icount and itrigger triggers no longer fire.

`trig.S` sets two mcontrol6 triggers for U-mode, both with action 0 (breakpoint exception, delegated to
S-mode): trigger 0 on executing `bp_target` and trigger 1 on loading `data_word`, and leaves `tselect` = 0.
It enters U-mode, runs a nop sled, then loads `data_word` and executes `bp_target`. The S-mode handler
records each breakpoint (scause 3) and resumes after the load; an `ecall` ends the test.

- check 1: the load trigger (trigger 1, not the one `tselect` selects) fired;
- check 2: the execute trigger (trigger 0) fired;
- check 3: no unexpected trap.

x31 = bitmask of failed checks; tohost = (x31 << 1) | 1. `run.sh` runs each ELF straight through, then
saves a snapshot after 80 instructions (in the U-mode sled; `--snapshotperiod 80 --snapshotdir
snap-rv$x/s`) and runs from it (`--loadfrom snap-rv$x/s0`).

Expected: x31 = 0 for the straight and restored runs.

Whisper master 6b8cce1a (`master.out`): the straight runs pass; the restored runs give x31 = 0x6 on RV64 and
RV32 (neither trigger fires):

```
rv64 straight run: x31 = 0x0
  PASS
rv64 snapshot at instruction 80: pm 0 pc 0x800000de 
rv64 restored from snapshot: x31 = 0x6
  FAIL check 1: load trigger (trigger 1) did not fire
  FAIL check 2: execute trigger (trigger 0) did not fire
rv32 straight run: x31 = 0x0
  PASS
rv32 snapshot at instruction 80: pm 0 pc 0x800000de 
rv32 restored from snapshot: x31 = 0x6
  FAIL check 1: load trigger (trigger 1) did not fire
  FAIL check 2: execute trigger (trigger 0) did not fire
```

With the triggers saved as `t <n> <tdata1> <tdata2> <tdata3>` lines and poked back on load (`fixed.out`, which
also prints those lines from the snapshot), all four runs pass.

Run: `./run.sh [path/to/whisper]` (prints the failed checks; exit status 0 = pass). Rebuild: `./build.sh`.

Other simulators: snapshot save/restore is a Whisper feature, so there is no equivalent to compare. The
straight-through test is ordinary Sdtrig code.
