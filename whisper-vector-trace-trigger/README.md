# A load-address trigger with action 2 (trace) ends a vector load at the matching element (vstart = k, no trap)

Whisper reproducer, 2026-11-21. Found by a four-simulator spec review against riscv-isa-manual 3142f66f (plus
riscv-aia 9507866 and riscv-debug-spec 40e5c35); failing on Whisper master a0288feb (and on a5554a17).

## What is wrong

With an mcontrol6 load-address trigger (m = 1, action = 2, "trace on") matching element 2 of `vle32.v`
(vl = 4), Whisper takes no trap but ends the instruction at element 2: vstart = 2, elements 2 and 3 are not written,
and the pc advances. `vlseg2e32.v`, `vlseg2e32ff.v` and `vluxseg2ei32.v` stop the same way at segment 2. A scalar `lw`
of the same address with the same trigger completes normally, as do vector stores.

## Correct behavior

A trigger with action 2-4 does not affect execution. The load completes: every body element is written and
vstart = 0 at the end of the instruction. (A hart without a trace encoder may legalize action 2 away instead, as Sail
and Imperas do, but Whisper keeps it.)

```
vle32.v v1, (t1), vl = 4, action-2 load-address trigger on element 2
  Expected: no trap, v1 elements 0-3 loaded, vstart = 0
  Observed: no trap, elements 2-3 unchanged (0), vstart = 2
vlseg2e32.v / vlseg2e32ff.v / vluxseg2ei32.v, trigger on field 0 of segment 2: same (vstart = 2, segments 2-3 not loaded)
```

## How to run

```
./run.sh /path/to/whisper
```

Cases:
- rv64 vle32.v: `u33-debug-b-whisper-02.whisper-rv64-max.elf` with `whisper-rv64-max.json`
- rv64 vlseg2e32.v / vlseg2e32ff.v / vluxseg2ei32.v: `u13-vec-a-whisper-01.whisper-rv64-max.elf` with `whisper-rv64-max.json`
- rv32 vle32.v: `u33-debug-b-whisper-02.whisper-rv32-max.elf` with `whisper-rv32-max.json`
- rv32 segment loads: `u13-vec-a-whisper-01.whisper-rv32-max.elf` with `whisper-rv32-max.json`

Files:
- `run.sh`: runs every case below on the Whisper binary given as argument.
- `u33-debug-b-whisper-02.whisper-rv64-max.elf` (+ `.objdump`)
- `u13-vec-a-whisper-01.whisper-rv64-max.elf` (+ `.objdump`)
- `u33-debug-b-whisper-02.whisper-rv32-max.elf` (+ `.objdump`)
- `u13-vec-a-whisper-01.whisper-rv32-max.elf` (+ `.objdump`)
- `whisper-rv64-max.json`: whisper.json used for the run
- `whisper-rv32-max.json`: whisper.json used for the run
- `src/`: test source (riscv-arch-test act4 `tests_ai` format with `sa.h`; built by the ACT framework for the config named in the file name; self-checking, prints `SA-MISMATCH` lines on failure)

## Output on Whisper master a5554a17 (key lines)

```
=== rv64 vle32.v
SA-MISMATCH: 02 Sdtrig.adoc:147-149 vle32.v completes: vstart = 0 afterwards expect=0x0000000000000000 got=0x0000000000000002
SA-MISMATCH: 02 vle32.v element 2 (the matching one) loaded expect=0x0000000000000033 got=0x0000000000000000
SA-MISMATCH: 02 vle32.v element 3 loaded expect=0x0000000000000044 got=0x0000000000000000
SA-MISMATCH: INFO 02 trigger 0 hit0 after both loads expect=0x0000000000000000 got=0x0000000000000001
RVCP-SUMMARY: TEST FAILED - Test File "u33-debug-b-whisper-02.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
=== rv64 vlseg2e32.v / vlseg2e32ff.v / vluxseg2ei32.v
SA-MISMATCH: A vlseg2e32.v completed: vstart = 0 expect=0x0000000000000000 got=0x0000000000000002
SA-MISMATCH: A segment 2 field 0 loaded (v2[2]) expect=0x0000000000000055 got=0x0000000000000000
SA-MISMATCH: A segment 3 field 0 loaded (v2[3]) expect=0x0000000000000077 got=0x0000000000000000
SA-MISMATCH: A segment 2 field 1 loaded (v3[2]) expect=0x0000000000000066 got=0x0000000000000000
SA-MISMATCH: B vlseg2e32ff.v: vstart = 0 expect=0x0000000000000000 got=0x0000000000000002
SA-MISMATCH: B segment 3 field 0 loaded expect=0x0000000000000077 got=0x0000000000000000
SA-MISMATCH: C vluxseg2ei32.v completed: vstart = 0 expect=0x0000000000000000 got=0x0000000000000002
SA-MISMATCH: C segment 3 field 0 loaded expect=0x0000000000000077 got=0x0000000000000000
RVCP-SUMMARY: TEST FAILED - Test File "u13-vec-a-whisper-01.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
=== rv32 vle32.v
SA-MISMATCH: 02 Sdtrig.adoc:147-149 vle32.v completes: vstart = 0 afterwards expect=0x00000000 got=0x00000002
SA-MISMATCH: 02 vle32.v element 2 (the matching one) loaded expect=0x00000033 got=0x00000000
SA-MISMATCH: 02 vle32.v element 3 loaded expect=0x00000044 got=0x00000000
SA-MISMATCH: INFO 02 trigger 0 hit0 after both loads expect=0x00000000 got=0x00000001
RVCP-SUMMARY: TEST FAILED - Test File "u33-debug-b-whisper-02.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
=== rv32 segment loads
SA-MISMATCH: A vlseg2e32.v completed: vstart = 0 expect=0x00000000 got=0x00000002
SA-MISMATCH: A segment 2 field 0 loaded (v2[2]) expect=0x00000055 got=0x00000000
SA-MISMATCH: A segment 3 field 0 loaded (v2[3]) expect=0x00000077 got=0x00000000
SA-MISMATCH: A segment 2 field 1 loaded (v3[2]) expect=0x00000066 got=0x00000000
SA-MISMATCH: B vlseg2e32ff.v: vstart = 0 expect=0x00000000 got=0x00000002
SA-MISMATCH: B segment 3 field 0 loaded expect=0x00000077 got=0x00000000
SA-MISMATCH: C vluxseg2ei32.v completed: vstart = 0 expect=0x00000000 got=0x00000002
SA-MISMATCH: C segment 3 field 0 loaded expect=0x00000077 got=0x00000000
RVCP-SUMMARY: TEST FAILED - Test File "u13-vec-a-whisper-01.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
```
