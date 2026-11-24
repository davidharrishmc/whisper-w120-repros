# dcsr.stopcount = 1 does not stop minstret in Debug Mode or on the EBREAK that enters it (batch run loops)

Whisper reproducer, 2026-11-21. Found by a four-simulator spec review against riscv-isa-manual 3142f66f (plus
riscv-aia 9507866 and riscv-debug-spec 40e5c35); failing on Whisper master a0288feb (and on a5554a17).

## What is wrong

With dcsr.stopcount = 1 (writable; reads back 1), minstret keeps counting in Debug Mode: (1) in Debug Mode,
`csrr minstret; nop; nop; csrr minstret` differ by 3. (2) After DRET with stopcount still 1: M-mode `csrr minstret`
(A); EBREAK (dcsr at entry 0x4003b443: stopcount = 1, cause 1); first Debug Mode `csrr minstret` (B): B - A = 2, so the
entering EBREAK was counted too. Seen with and without --logfile.

## Correct behavior

With stopcount = 1, hart-local counters, including instret, do not increment in Debug Mode or on the EBREAK
that enters Debug Mode: difference 0 in (1) and B - A = 1 (only the csrr A) in (2).

```
(1) Debug Mode, stopcount = 1: csrr minstret; nop; nop; csrr minstret
  Expected: difference 0      Observed: 3
(2) M-mode csrr minstret (A); ebreak -> Debug Mode (stopcount = 1); csrr minstret (B)
  Expected: B - A = 1         Observed: 2
```

## How to run

```
./run.sh /path/to/whisper
```

Cases:
- rv64, dcsr preset ebreakm = 1 (whisper-rv64-ebmall): `u32-debug-a-T-03.rv64.elf` with `whisper-rv64-ebmall.json`
- rv32, dcsr preset ebreakm = 1 (whisper-rv32-ebmall): `u32-debug-a-T-03.rv32.elf` with `whisper-rv32-ebmall.json`

Files:
- `run.sh`: runs every case below on the Whisper binary given as argument.
- `u32-debug-a-T-03.rv64.elf` (+ `.objdump`)
- `u32-debug-a-T-03.rv32.elf` (+ `.objdump`)
- `whisper-rv64-ebmall.json`: whisper.json used for the run
- `whisper-rv32-ebmall.json`: whisper.json used for the run
- `src/`: test source (bare: build with `riscv64-unknown-elf-gcc -nostdlib -nostartfiles -march=rv64gch_zicsr_zifencei_zicfilp_zawrs_zicond -mabi=lp64 -DHYP -DZICFILP -DHAS_S -DHAS_U -DUART=0x10000000 -DWHISPER -Isrc -T src/link.ld (RV32: -march=rv32gch_zicsr_zifencei_zicfilp_zawrs -mabi=ilp32); the test prints FAIL lines on the UART`)

## Output on Whisper master a5554a17 (key lines)

```
=== rv64, dcsr preset ebreakm = 1 (whisper-rv64-ebmall)
FAIL: T03: stopcount=1: csrr minstret; nop; nop; csrr minstret in Debug Mode differ by 0 exp=0x0000000000000000 got=0x0000000000000003
FAIL: T03: stopcount=1: M csrr minstret (A); ebreak -> Debug Mode; csrr minstret (B): B - A = 1 exp=0x0000000000000001 got=0x0000000000000002
u32-debug-a-T-03: checks=3 failures=2 RESULT=FAIL
Error: Failed stop: Hart 0: write to to-host
tohost = 0x0000000000000003
=== rv32, dcsr preset ebreakm = 1 (whisper-rv32-ebmall)
FAIL: T03: stopcount=1: csrr minstret; nop; nop; csrr minstret in Debug Mode differ by 0 exp=0x00000000 got=0x00000003
FAIL: T03: stopcount=1: M csrr minstret (A); ebreak -> Debug Mode; csrr minstret (B): B - A = 1 exp=0x00000001 got=0x00000002
u32-debug-a-T-03: checks=3 failures=2 RESULT=FAIL
Error: Failed stop: Hart 0: write to to-host
tohost = 0x00000003
```
