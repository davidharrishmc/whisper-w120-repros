# sspush decoded in M-mode (as a MOP) and later executed in S-mode aborts Whisper in createTrapInst

Whisper reproducer, 2026-11-21. Found by a four-simulator spec review against riscv-isa-manual 3142f66f (plus
riscv-aia 9507866 and riscv-debug-spec 40e5c35); failing on Whisper master a0288feb (and on a5554a17).

## What is wrong

`sspush x5` at physical address P is executed first in M-mode, where xSSE = 0 and it is a MOP; this fills the
decode cache with a DecodedInst whose shadow-stack flag is 0. The same instruction executed later in S-mode with
menvcfg.SSE = 1 and satp = Bare correctly raises a store/AMO access fault, but trap entry builds mtinst from the stale
DecodedInst, which is neither an sspush nor a store, and Whisper stops with `Hart.cpp:3649: ... createTrapInst ...
Assertion 'false' failed`. The same S-mode sspush without the earlier M-mode execution traps correctly.

## Correct behavior

The S-mode sspush raises a store/AMO access fault (mcause 7) with mtinst = 0 (no transformation is defined
for shadow-stack instructions). xSSE is evaluated when the instruction executes, and a change of privilege must not
change what the trap writes.

```
Part 2: sub_b {sspush x5; ret} run in M-mode, then in S-mode (menvcfg.SSE = 1, satp Bare)
  Expected: mcause = 7, mtinst = 0, ssp unchanged
  Observed: whisper: Hart.cpp:3649: ... createTrapInst ...: Assertion `false' failed. (abort)
Part 1 (control, same code only in S-mode): mcause = 7, mtinst = 0 (correct)
```

## How to run

```
./run.sh /path/to/whisper
```

Cases:
- rv64: `u18-cfi-whisper-01.whisper-rv64-max.elf` with `whisper-rv64-max.json`
- rv32: `u18-cfi-whisper-01.whisper-rv32-max.elf` with `whisper-rv32-max.json`

Files:
- `run.sh`: runs every case below on the Whisper binary given as argument.
- `u18-cfi-whisper-01.whisper-rv64-max.elf` (+ `.objdump`)
- `u18-cfi-whisper-01.whisper-rv32-max.elf` (+ `.objdump`)
- `whisper-rv64-max.json`: whisper.json used for the run
- `whisper-rv32-max.json`: whisper.json used for the run
- `src/`: test source (riscv-arch-test act4 `tests_ai` format with `sa.h`; built by the ACT framework for the config named in the file name; self-checking, prints `SA-MISMATCH` lines on failure)

## Output on Whisper master a5554a17 (key lines)

```
=== rv64
whisper: Hart.cpp:3649: uint32_t WdRiscv::Hart<URV>::createTrapInst(const WdRiscv::DecodedInst*, bool, unsigned int, URV, uint64_t) const [with URV_ = long unsigned int; uint32_t = unsigned int; URV = long unsigned int; uint64_t = long unsigned int]: Assertion `false' failed.
=== rv32
whisper: Hart.cpp:3649: uint32_t WdRiscv::Hart<URV>::createTrapInst(const WdRiscv::DecodedInst*, bool, unsigned int, URV, uint64_t) const [with URV_ = unsigned int; uint32_t = unsigned int; URV = unsigned int; uint64_t = long unsigned int]: Assertion `false' failed.
```
