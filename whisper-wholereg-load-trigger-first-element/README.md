# Whisper: a whole-register vector load aborts when a load-data trigger matches its first element

With an mcontrol6 load-data trigger armed, a whole-register vector load (`vl<nr>re<eew>.v`) whose first
element (the one at `vstart`) matches the trigger makes Whisper abort:

```
whisper: VecLdStInfo.hpp:125: void WdRiscv::VecLdStInfo::removeLastElem(): Assertion `not elems_.empty()' failed.
```

The trigger must instead raise a breakpoint exception (or, as the trigger "should" match, the load may
complete): riscv-debug-spec Sdtrig.adoc (norm:Sdtrig_mult_mem_access): "The Trigger Module should match such
accesses as if they all happened individually. E.g. a vector load should be treated as if it performed
multiple loads of size SEW". On the trap, vstart holds the element index (vector-common.adoc,
norm:epc_vstart_op_V_trap) and a nonzero mtval is the faulting address (machine.adoc,
norm:mtval_vaddr_wr_faulting_addr).

`wholereg-load-trigger-first-element.S` runs in M-mode with `mstatus.MIE` = 1. It sets trigger 0 to mcontrol6
select = 1 (data), match = 0 (equal), m = 1, load = 1, action = 0, with `tdata2` = 0x12345678, the value of the
first word of the data, and executes `vl1re32.v v1, (x6)`. It checks:

- exactly one trap, with mcause = 3 (breakpoint);
- vstart = 0 (the trigger fired before element 0) or 1 (right after element 0);
- mtval = 0 or the address of element 0.

Expected: PASS. Whisper master fa18e475 (`master.out`) aborts on the assertion on RV64 and RV32. With the fix
(`fixed.out`) both pass.

## Files

- `wholereg-load-trigger-first-element.S`: the test (riscv-arch-test framework, self-checking with the
  `tests_ai` `sa.h` macros of riscv-arch-test 205129dbd8).
- `wholereg-load-trigger-first-element_rv64.elf`, `..._rv32.elf`: built by riscv-arch-test's `act` for its
  `config/whisper/whisper-rv64-max` and `whisper-rv32-max` configurations.
- `whisper-rv64.json`, `whisper-rv32.json`: those configurations' Whisper config files.
- `master.out`, `fixed.out`: `run.sh` output for Whisper master fa18e475 and for the fix.

## Run

    ./run.sh path/to/whisper     # prints PASS or FAIL for each ELF; exit status 0 = pass

Each run is `whisper --maxinst 100000000:f --config whisper-rv64.json wholereg-load-trigger-first-element_rv64.elf`
(and the same for RV32); the test prints `RVCP-SUMMARY: TEST PASSED` or `TEST FAILED` on Whisper's console.

## Other simulators

The same test built for riscv-arch-test's RV64 configurations passes on Spike c20813c (`spike-rv64-max`), Sail
master 81184531 (`sail-RVA23-master`) and stock ImperasDV Y-2026.09 (`imperas-rv64-max`).
