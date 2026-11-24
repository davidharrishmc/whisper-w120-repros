# amocas.d (RV32) and amocas.q (RV64) store the register pair as two trigger-checked stores: half-written pair on RV32, assertion abort on RV64

Whisper reproducer, 2026-11-21. Found by a four-simulator spec review against riscv-isa-manual 3142f66f (plus
riscv-aia 9507866 and riscv-debug-spec 40e5c35); failing on Whisper master a0288feb (and on a5554a17).

## What is wrong

When the compare succeeds, Whisper writes the pair as two XLEN-wide stores, and each store evaluates the
store-address and store-data triggers again for its own half. A trigger that matches only the upper half fires after the
lower half has been written. On RV32 `amocas.d` takes the breakpoint with the lower word of memory already holding the
new value and the upper word unchanged. On RV64 `amocas.q` stops Whisper with `amo.cpp:1420: ... Assertion 'ok0 == ok1'
failed`.

## Correct behavior

The pair CAS is one atomic 2*XLEN-bit access. A trigger on it either fires before the instruction executes
(memory unchanged) or does not fire (both halves written); it can never be observed half-written.

```
RV32 01a, store-address trigger (size 3) at A+4, amocas.d to A, compare equal
  Expected: breakpoint with mem[A], mem[A+4] unchanged, or no trap with both words written
  Observed: breakpoint, mem[A] = new low word, mem[A+4] = old word
RV64 01a (store-address at A+8) and 01b (store-data on the upper swap value), amocas.q
  Expected: as above
  Observed: amo.cpp:1420: ... Assertion `ok0 == ok1' failed (abort)
```

Case 01c is a question, not part of the report: should an mcontrol6 trigger with size = XLEN at A match
the 2*XLEN-bit pair CAS at A? Whisper matches it on the lower half; Sail and Imperas do not. Its check
prints an `SA-MISMATCH` line on Whisper.

## How to run

```
./run.sh /path/to/whisper
```

Cases:
- rv64 01a (store-address trigger on the upper half): `u04-atomics-whisper-01a.whisper-rv64-max.elf` with `whisper-rv64-max.json`
- rv64 01b (store-data trigger on the upper swap value): `u04-atomics-whisper-01b.whisper-rv64-max.elf` with `whisper-rv64-max.json`
- rv64 01c (question: size-64 trigger at A on amocas.q): `u04-atomics-whisper-01c.whisper-rv64-max.elf` with `whisper-rv64-max.json`
- rv32 01a: `u04-atomics-whisper-01a.whisper-rv32-max.elf` with `whisper-rv32-max.json`
- rv32 01b: `u04-atomics-whisper-01b.whisper-rv32-max.elf` with `whisper-rv32-max.json`
- rv32 01c (question: size-32 trigger at A on amocas.d): `u04-atomics-whisper-01c.whisper-rv32-max.elf` with `whisper-rv32-max.json`

Files:
- `run.sh`: runs every case below on the Whisper binary given as argument.
- `u04-atomics-whisper-01a.whisper-rv64-max.elf` (+ `.objdump`)
- `u04-atomics-whisper-01b.whisper-rv64-max.elf` (+ `.objdump`)
- `u04-atomics-whisper-01c.whisper-rv64-max.elf` (+ `.objdump`)
- `u04-atomics-whisper-01a.whisper-rv32-max.elf` (+ `.objdump`)
- `u04-atomics-whisper-01b.whisper-rv32-max.elf` (+ `.objdump`)
- `u04-atomics-whisper-01c.whisper-rv32-max.elf` (+ `.objdump`)
- `whisper-rv64-max.json`: whisper.json used for the run
- `whisper-rv32-max.json`: whisper.json used for the run
- `src/`: test source (riscv-arch-test act4 `tests_ai` format with `sa.h`; built by the ACT framework for the config named in the file name; self-checking, prints `SA-MISMATCH` lines on failure)

## Output on Whisper master a5554a17 (key lines)

```
=== rv64 01a (store-address trigger on the upper half)
SA-MISMATCH: INFO A0 tdata1 read back expect=0x0000000000000000 got=0x6000000000000042
SA-MISMATCH: INFO A0 number of traps expect=0x0000000000000000 got=0x0000000000000001
SA-MISMATCH: INFO A tdata1 read back expect=0x0000000000000000 got=0x6000000000050042
whisper: amo.cpp:1420: void WdRiscv::Hart<URV>::execAmocas_q(const WdRiscv::DecodedInst*) [with URV_ = long unsigned int]: Assertion `ok0 == ok1' failed.
=== rv64 01b (store-data trigger on the upper swap value)
SA-MISMATCH: INFO B tdata1 read back expect=0x0000000000000000 got=0x6000000000200042
whisper: amo.cpp:1420: void WdRiscv::Hart<URV>::execAmocas_q(const WdRiscv::DecodedInst*) [with URV_ = long unsigned int]: Assertion `ok0 == ok1' failed.
=== rv64 01c (size-64 trigger at A on amocas.q)
SA-MISMATCH: INFO L tdata1 read back expect=0x0000000000000000 got=0x6000000000050042
SA-MISMATCH: L Sdtrig mcontrol6.size: a size-W trigger matches only W-byte accesses; the pair CAS is one 2W-byte access: number of breakpoints expect=0x0000000000000000 got=0x0000000000000001
SA-MISMATCH: INFO S tdata1 read back expect=0x0000000000000000 got=0x6000000000060042
RVCP-SUMMARY: TEST FAILED - Test File "u04-atomics-whisper-01c.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
=== rv32 01a
SA-MISMATCH: INFO A0 tdata1 read back expect=0x00000000 got=0x60000042
SA-MISMATCH: INFO A0 number of traps expect=0x00000000 got=0x00000001
SA-MISMATCH: INFO A tdata1 read back expect=0x00000000 got=0x60030042
SA-MISMATCH: INFO A number of traps expect=0x00000000 got=0x00000001
SA-MISMATCH: A size=half store-address trigger at A+W: partial update (1 = only one half written) expect=0x00000000 got=0x00000001
RVCP-SUMMARY: TEST FAILED - Test File "u04-atomics-whisper-01a.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
=== rv32 01b
SA-MISMATCH: INFO B tdata1 read back expect=0x00000000 got=0x60200042
SA-MISMATCH: INFO B number of traps expect=0x00000000 got=0x00000001
SA-MISMATCH: B store-data trigger on the upper value: partial update (1 = only one half written) expect=0x00000000 got=0x00000001
RVCP-SUMMARY: TEST FAILED - Test File "u04-atomics-whisper-01b.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
=== rv32 01c (size-32 trigger at A on amocas.d)
SA-MISMATCH: INFO L tdata1 read back expect=0x00000000 got=0x60030042
SA-MISMATCH: L Sdtrig mcontrol6.size: a size-W trigger matches only W-byte accesses; the pair CAS is one 2W-byte access: number of breakpoints expect=0x00000000 got=0x00000001
SA-MISMATCH: INFO S tdata1 read back expect=0x00000000 got=0x60050042
RVCP-SUMMARY: TEST FAILED - Test File "u04-atomics-whisper-01c.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
```
