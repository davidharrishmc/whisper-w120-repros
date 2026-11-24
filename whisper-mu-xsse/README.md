# On a hart without S-mode, U-mode xSSE follows menvcfg.SSE (should be 0)

Whisper reproducer, 2026-11-21. Found by a four-simulator spec review against riscv-isa-manual 3142f66f (plus
riscv-aia 9507866 and riscv-debug-spec 40e5c35); failing on Whisper master a0288feb (and on a5554a17).

## What is wrong

With menvcfg.SSE = 1 on an M+U hart, U-mode `sspush x5` stores and decrements ssp, and `ssrdp x9` returns ssp,
instead of both being MOPs.

## Correct behavior

When S-mode is not implemented, xSSE is 0 in every mode, so sspush/ssrdp behave as Zimop MOPs: no store, ssp
unchanged, ssrdp writes 0.

```
M+U hart, menvcfg.SSE = 1, U-mode: sspush x5; ssrdp x9
  Expected: ssp unchanged, x9 = 0
  Observed: ssp - 8 (pushed), x9 = ssp (0x800086e8)
```

## How to run

```
./run.sh /path/to/whisper
```

Cases:
- rv64, whisper-rv64-mu + zicfiss + menvcfg mask 0x3000000fd (SSE writable): `u18-cfi-whisper-02.whisper-rv64-mu-ssw.elf` with `whisper-rv64-mu-ssw.json`

Files:
- `run.sh`: runs every case below on the Whisper binary given as argument.
- `u18-cfi-whisper-02.whisper-rv64-mu-ssw.elf` (+ `.objdump`)
- `whisper-rv64-mu-ssw.json`: whisper.json used for the run
- `src/`: test source (riscv-arch-test act4 `tests_ai` format with `sa.h`; built by the ACT framework for the config named in the file name; self-checking, prints `SA-MISMATCH` lines on failure)

## Output on Whisper master a5554a17 (key lines)

```
=== rv64, whisper-rv64-mu + zicfiss + menvcfg mask 0x3000000fd (SSE writable)
SA-MISMATCH: U ssrdp without S writes 0 expect=0x0000000000000000 got=0x00000000800086e8
SA-MISMATCH: U sspush without S: ssp unchanged expect=0x0000000000000000 got=0xfffffffffffffff8
RVCP-SUMMARY: TEST FAILED - Test File "u18-cfi-whisper-02.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
```
