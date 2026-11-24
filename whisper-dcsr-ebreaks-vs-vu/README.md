# dcsr.ebreaks/ebreaku also apply to VS-mode and VU-mode EBREAK

Whisper reproducer, 2026-11-21. Found by a four-simulator spec review against riscv-isa-manual 3142f66f (plus
riscv-aia 9507866 and riscv-debug-spec 40e5c35); failing on Whisper master a0288feb (and on a5554a17).

## What is wrong

With dcsr.ebreaks = 1 and dcsr.ebreakvs = 0, an EBREAK in VS-mode enters Debug Mode instead of raising a
breakpoint exception; with dcsr.ebreaku = 1 and ebreakvu = 0, an EBREAK in VU-mode does the same.

## Correct behavior

ebreaks/ebreaku govern S-mode and U-mode only (V = 0). With ebreakvs/ebreakvu = 0, VS/VU-mode EBREAK
"behave[s] as described in the Privileged Spec": a breakpoint exception (cause 3).

```
dcsr = 0x40003003 (ebreaks = ebreaku = 1, ebreakvs = ebreakvu = 0); EBREAK in VS-mode
  Expected: breakpoint exception to M, mcause 3, MPV = 1 (tohost = 1)
  Observed: enters Debug Mode (dcsr.cause = ebreak, v = 1, prv = S) (tohost = 3)
dcsr = 0x40001003 (ebreaku = 1); EBREAK in VU-mode
  Expected: mcause 3 (tohost = 1)   Observed: enters Debug Mode (tohost = 7)
```

## How to run

```
./run.sh /path/to/whisper
```

Cases:
- rv64, dcsr reset 0x40003003 (ebreaks = ebreaku = 1): `v2-u21w-05-ebreak-vs-vu.rv64.elf` with `whisper-rv64-ebreaks.json`
- rv64, dcsr reset 0x40001003 (ebreaku = 1): `v2-u21w-05-ebreak-vs-vu.rv64.elf` with `whisper-rv64-ebreaku.json`
- rv32, dcsr reset 0x40003003: `v2-u21w-05-ebreak-vs-vu.rv32.elf` with `whisper-rv32-ebreaks.json`
- rv64, control: stock ACT config (dcsr.ebreak* = 0): `v2-u21w-05-ebreak-vs-vu.rv64.elf` with `whisper-rv64-max.json`

Files:
- `run.sh`: runs every case below on the Whisper binary given as argument.
- `v2-u21w-05-ebreak-vs-vu.rv64.elf` (+ `.objdump`)
- `v2-u21w-05-ebreak-vs-vu.rv32.elf` (+ `.objdump`)
- `whisper-rv64-ebreaks.json`: whisper.json used for the run
- `whisper-rv64-ebreaku.json`: whisper.json used for the run
- `whisper-rv32-ebreaks.json`: whisper.json used for the run
- `whisper-rv64-max.json`: whisper.json used for the run
- `src/`: test source (bare: build with `riscv64-unknown-elf-gcc -march=rv64gc -mabi=lp64 -nostdlib -T link.ld`, rv32 likewise)

## Output on Whisper master a5554a17 (key lines)

```
=== rv64, dcsr reset 0x40003003 (ebreaks = ebreaku = 1)
Error: Failed stop: Hart 0: write to to-host
tohost = 0x0000000000000003
=== rv64, dcsr reset 0x40001003 (ebreaku = 1)
Error: Failed stop: Hart 0: write to to-host
tohost = 0x0000000000000007
=== rv32, dcsr reset 0x40003003
Error: Failed stop: Hart 0: write to to-host
tohost = 0x00000003
=== rv64, control: stock ACT config (dcsr.ebreak* = 0)
Successful stop: Hart 0: write to to-host
tohost = 0x0000000000000001
```
