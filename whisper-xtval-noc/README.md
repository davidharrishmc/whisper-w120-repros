# Illegal-instruction mtval on a hart without C/Zca (IALIGN = 32)

Issue: [tenstorrent/whisper#380](https://github.com/tenstorrent/whisper/issues/380).

M-mode bare-metal test, RV64 and RV32, built without C. It executes three words whose low two bits are not 11
(`0xABCD0004`, `0xABCD6101`, `0xABCD4002`; each low half is a reserved compressed encoding) and checks that the
illegal-instruction trap reports the whole 32-bit word in mtval. It also checks that misa.C reads 0 and that a jalr
to pc+2 raises instruction-address-misaligned (IALIGN = 32).

The test ends through HTIF `tohost`: tohost = 1 passes; tohost = 43 (exit code 21) means mtval held only the
16-bit parcel for all three words. Code bits are listed at the top of `xtval-noc.S`.

Spec: riscv-isa-manual#3549 (src/unpriv/intro.adoc, merged 2026-11-19): "Instructions are always a multiple of IALIGN
bits in length." Ruling in riscv-isa-manual#3547: with IALIGN = 32, "don't admit the existence of 16-bit
instructions. Report a 32-bit instruction in `tval`."

## Files

- `xtval-noc.S`, `link.ld`, `Makefile`: source (`make` builds `xtval-noc.rv64.elf` and `xtval-noc.rv32.elf`)
- `xtval-noc.rv{64,32}.elf` (+ `.objdump`): prebuilt with riscv64-unknown-elf-gcc
- `run.sh`: runs both ELFs on Whisper, QEMU, Spike, Sail and Imperas (paths in `WHISPER`, `QEMU_DIR`, `SPIKE`,
  `SAIL`, `ISS`; a simulator that is not found is skipped)
- `whisper-rv{64,32}-noc.json`: Whisper configuration (`rv64i_zicsr` / `rv32i_zicsr`)
- `sail-noc-override.json`: Sail `--config-override` turning off C/Zca/Zcf/Zcd/Zcb/Zcmop
- `logs/`: logs of the runs below

## Commands

```
whisper --configfile whisper-rv64-noc.json --logfile whisper.rv64.log xtval-noc.rv64.elf
qemu-system-riscv64 -nographic -machine spike -cpu rv64,c=false,zca=false -d int -bios xtval-noc.rv64.elf
spike --isa=rv64i_zicsr -l --log-commits xtval-noc.rv64.elf
sail_riscv_sim --config-override sail-noc-override.json --trace-exception xtval-noc.rv64.elf   (add --rv32 for RV32)
```

## Results (2026-11-23), mtval for 0xABCD0004 / 0xABCD6101 / 0xABCD4002, same on RV64 and RV32

| Simulator | mtval | Result |
|---|---|---|
| Whisper a0288feb (master 2026-11-23) and 2ba694b (riscv-arch-test pin) | 0x4 / 0x6101 / 0x4002 | fail, tohost 43 |
| QEMU 11.1.3 (`-cpu rvXX,c=false,zca=false`) | 0x4 / 0x6101 / 0x4002 | fail, exit 21 |
| Spike 982f078 (master 2026-11-20) | 0x4 / 0x6101 / 0x4002 | fail, exit 21 (riscv-isa-sim PR #2564 open) |
| Sail 0.16 | 0x4 / 0x6101 / 0x4002 | fail (fixed after 0.16 by sail-riscv#2123) |
| Sail 71312d53 (= weekly release 2026-11-23-71312d5) | 0xABCD0004 / 0xABCD6101 / 0xABCD4002 | pass |
| Imperas Y-2026.09, variant RV64I / RV32I | 0xABCD0004 / 0xABCD6101 / 0xABCD4002 | pass |

## Whisper extras

- `misa-c-cleared/`: the same check on riscv-arch-test's whisper-rv64-max / whisper-rv32-max configurations (C present, writable
  misa.C) after `csrc misa, 4`. `./run.sh path/to/whisper`; tohost = 9 (code 4) means mtval held the 16-bit parcel,
  tohost = 1 passes. Whisper a0288feb and 2ba694b: 9 on both.
- `whisper-fix.patch`: the fix ([tenstorrent/whisper#381](https://github.com/tenstorrent/whisper/pull/381)) against a0288feb (truncate to 16 bits at fetch and in `illegalInst` only when Zca is
  enabled). With it, both the no-C runs and the `misa-c-cleared` runs pass.
