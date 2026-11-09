# Whisper: on a misaligned superpage, a shadow-stack access raises the access fault instead of the page fault

All three tests use Sv39 with 2 MiB leaves whose PPN is only 4 KiB aligned (misaligned superpages) and, as
controls, aligned 2 MiB leaves. `menvcfg.SSE` = 1 (and `henvcfg.SSE` = 1 for the VS test).

- `whisper-ss-misaligned-superpage.S` (S-mode): `sd` to a misaligned shadow-stack megapage and `sspush` to a
  misaligned read-write megapage must raise a store/AMO page fault (15); the same accesses to aligned megapages
  raise a store/AMO access fault (7).
- `whisper-ss-misaligned-superpage-mprv.S` (M-mode, MPRV = 1, MPP = S): `lw` from a misaligned shadow-stack
  megapage must raise a load page fault (13), `sw` a store/AMO page fault (15).
- `whisper-ss-misaligned-superpage-vs.S` (M-mode, MPRV = 1, MPV = 1, MPP = S, so the VS-stage walk): `sd` to a
  misaligned shadow-stack megapage and `ssamoswap.d` to a misaligned read-write megapage must raise 15; the
  same accesses to aligned megapages raise 7.

Expected: 15 on the misaligned megapages (13 for the load). Whisper master (fa18e475, `master.out`): the
load gets 13, every store and shadow-stack access gets 7:

```
FAIL  whisper-ss-misaligned-superpage.elf
      RVCP: Test Info: case 1: sd to a misaligned SS megapage: cause (misaligned superpage: 15)
      RVCP: Bad Value:      0x0000000000000007
FAIL  whisper-ss-misaligned-superpage-mprv.elf
      RVCP: Test Info: sw to misaligned SS superpage: xcause (-1 = none)
      RVCP: Bad Value:      0x0000000000000007
FAIL  whisper-ss-misaligned-superpage-vs.elf
      RVCP: Test Info: case 1: VS sd to a misaligned SS megapage: cause (misaligned superpage: 15)
      RVCP: Bad Value:      0x0000000000000007
```

(The first test also gets 7 for the `sspush` case, which the program checks after case 1.) `fixed.out` is the
output with the fix.

## Run

`./run.sh path/to/whisper` (prints PASS or FAIL per ELF and overall; exit status 0 = pass).

## Build

Self-checking programs built with the riscv-arch-test framework (`act`) from riscv-arch-test PR #3162 (commit
205129dbd8, which adds the `tests_ai/common` helpers; `ai_macros.h` and `sa.h` are included here) for the
riscv-arch-test Whisper configuration named below; the `whisper*.json` files are the configurations they run with.
A test prints `RVCP-SUMMARY: TEST PASSED` or `TEST FAILED`; a failed check prints `RVCP: Test Info: <check>` and
the bad value, and soft checks print `SA-MISMATCH: <check> expect=... got=...` and fail the test at the end. Configuration: `whisper-rv64-max`.
