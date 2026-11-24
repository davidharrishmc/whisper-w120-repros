# A misaligned store that crosses a 4 KiB boundary inside the CLINT aborts Whisper (assert pa1 == pa2)

Whisper reproducer, 2026-11-21. Found by a four-simulator spec review against riscv-isa-manual 3142f66f (plus
riscv-aia 9507866 and riscv-debug-spec 40e5c35); failing on Whisper master a0288feb (and on a5554a17).

## What is wrong

An M-mode `sd` at CLINT+0x4FFC (RV64) or `sw` at CLINT+0x4FFE (RV32), a misaligned store that crosses a 4 KiB
boundary inside the CLINT's mtimecmp array, stops Whisper with `Hart.cpp:2885: writeForStore: Assertion 'pa1 == pa2'
failed`. The program neither traps nor continues.

## Correct behavior

A misaligned store either raises an exception (address-misaligned or access fault) or proceeds (possibly
non-atomically); which one is the platform's choice. Stopping the simulator is neither.

```
sd x?, 0x4FFC(CLINT) (RV64) / sw x?, 0x4FFE(CLINT) (RV32)
  Expected: cause 4/6 or 5/7 trap, or the store completes and the next instruction runs
  Observed: whisper: Hart.cpp:2885: ... writeForStore ...: Assertion `pa1 == pa2' failed. (abort)
```

## How to run

```
./run.sh /path/to/whisper
```

Cases:
- rv64: sd at CLINT+0x4FFC: `v2-u21w-06-clint-misal-pagecross.whisper-rv64-max.elf` with `whisper-rv64-max.json`
- rv32: sw at CLINT+0x4FFE: `v2-u21w-06-clint-misal-pagecross.whisper-rv32-max.elf` with `whisper-rv32-max.json`

Files:
- `run.sh`: runs every case below on the Whisper binary given as argument.
- `v2-u21w-06-clint-misal-pagecross.whisper-rv64-max.elf` (+ `.objdump`)
- `v2-u21w-06-clint-misal-pagecross.whisper-rv32-max.elf` (+ `.objdump`)
- `whisper-rv64-max.json`: whisper.json used for the run
- `whisper-rv32-max.json`: whisper.json used for the run
- `src/`: test source (riscv-arch-test act4 `tests_ai` format with `sa.h`; built by the ACT framework for the config named in the file name; self-checking, prints `SA-MISMATCH` lines on failure)

## Output on Whisper master a5554a17 (key lines)

```
=== rv64: sd at CLINT+0x4FFC
whisper: Hart.cpp:2885: bool WdRiscv::Hart<URV>::writeForStore(uint64_t, uint64_t, uint64_t, STORE_TYPE) [with STORE_TYPE = long unsigned int; URV_ = long unsigned int; uint64_t = long unsigned int]: Assertion `pa1 == pa2' failed.
=== rv32: sw at CLINT+0x4FFE
whisper: Hart.cpp:2885: bool WdRiscv::Hart<URV>::writeForStore(uint64_t, uint64_t, uint64_t, STORE_TYPE) [with STORE_TYPE = unsigned int; URV_ = unsigned int; uint64_t = long unsigned int]: Assertion `pa1 == pa2' failed.
```
