# Whisper: snapshot restore does not set virtual mode properly

`Hart::loadSnapshotRegs` restores the privilege mode with `setPrivilegeMode` but the virtualization mode with
a plain `virtMode_ = virtMode;`, not with `setVirtualMode`. The CSR file therefore stays at V = 0 (it maps
S-level CSR numbers to the VS CSRs only when its own V is 1), and the Smcntrpmf filtering that
`setPrivilegeMode` applies sees the old V. After a snapshot taken in VS-mode is loaded, the program continues
in VS-mode, but `csrr`/`csrw` of `sscratch`, `sstatus`, ... reach the HS CSRs, and instret is filtered with the
HS inhibit bit (`minstretcfg.SINH`) instead of `VSINH`.

`snapvirt.S` sets `sscratch` = 0x5a5a, `vsscratch` = 0x1234, `mstatus.SUM` = 0, `vsstatus.SUM` = 1,
`minstretcfg.SINH` = 1 and `VSINH` = 0 (`minstretcfgh` on RV32), delegates ecall-from-VS to HS, and enters
VS-mode with `mret`, where it runs a 64-instruction nop sled and then reads `sscratch`, `sstatus` and instret
(twice), writes `sscratch`, and executes `ecall`. The HS-mode handler checks the results:

- check 1: `csrr sscratch` read `vsscratch` (0x1234);
- check 2: `csrr sstatus` read `vsstatus` (SUM = 1);
- check 3: instret counted in VS-mode;
- check 4: `csrw sscratch` wrote `vsscratch` (0x777);
- check 5: ... and left the HS `sscratch` (0x5a5a) unchanged;
- check 6: scause = 10; check 7: unexpected trap into M-mode.

x31 is the bitmask of failed checks; tohost = (x31 << 1) | 1. The checks run in HS-mode so that no trap into
M-mode is needed: on RV32 the snapshot does not record `mstatush` when it is 0, so `mstatush.MDT` comes back
as its reset value 1 and a trap into M-mode after the restore would be a double trap (a separate problem).

`run.sh` runs each ELF straight through, then saves a snapshot after 80 instructions (`--snapshotperiod 80
--snapshotdir snap-rv$x/s`; the snapshot's `registers` file has `pm 1`, `vm 1`, a pc in the sled), then runs
from it (`--loadfrom snap-rv$x/s0`).

Expected: x31 = 0 for the straight run and for the run restored from the snapshot.

Whisper master 6b8cce1a (`master.out`): the straight runs pass; the restored runs give x31 = 0x3e on RV64
and RV32 (sscratch reads 0x5a5a, sstatus reads the HS view with SUM = 0, instret does not advance, and the
write goes to the HS `sscratch`):

```
rv64 straight run: x31 = 0x0
  PASS
rv64 snapshot at instruction 80: pm 1 vm 1 pc 0x800000e4 
rv64 restored from snapshot: x31 = 0x3e
  FAIL check 1: csrr sscratch did not read vsscratch
  FAIL check 2: csrr sstatus did not read vsstatus (SUM)
  FAIL check 3: instret did not count in VS-mode (Smcntrpmf)
  FAIL check 4: csrw sscratch did not write vsscratch
  FAIL check 5: csrw sscratch changed the HS sscratch
rv32 straight run: x31 = 0x0
  PASS
rv32 snapshot at instruction 80: pm 1 vm 1 pc 0x800000ec 
rv32 restored from snapshot: x31 = 0x3e
  FAIL check 1: csrr sscratch did not read vsscratch
  FAIL check 2: csrr sstatus did not read vsstatus (SUM)
  FAIL check 3: instret did not count in VS-mode (Smcntrpmf)
  FAIL check 4: csrw sscratch did not write vsscratch
  FAIL check 5: csrw sscratch changed the HS sscratch
```

With `setVirtualMode` (`fixed.out`) all four runs pass.

Run: `./run.sh [path/to/whisper]` (prints the failed checks; exit status 0 = pass). Rebuild: `./build.sh`.

Other simulators: the snapshot save/restore feature is Whisper-specific, so there is no equivalent to compare.
The straight-through test is ordinary H-extension code.
