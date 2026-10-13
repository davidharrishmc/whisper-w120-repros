# whisper-translation-modes-xlen (item 38 of whisper#120)

Whisper-only reproducer. `address_translation_modes` is not checked against XLEN or against H.
The configurations are whisper-rv64-max-VLEN-512 (RV64 + H) with a different
`address_translation_modes`:

- `whisper-rv64-sv32.json`: `["bare", "sv32", "sv39"]`. satp MODE=1 is reserved on RV64
  (supervisor.adoc satp MODE table), but whisper accepts the write, and translation then behaves as Bare.
  `satpmode1.elf` writes MODE=1 to satp from M-mode, reads it back, enters S-mode, and ecalls back; the
  exit code (tohost) is the MODE read back. f069895c: "Failed stop" (MODE 1 stuck, S-mode fetch untranslated).
- `whisper-rv64-sv64.json`: `["bare", "sv39", "sv64"]`. Sv64 is only reserved; `satpmode11.elf` writes
  MODE=11, and the first translated fetch hits `assert(0 and "Unsupported virtual memory mode.")`
  (`VirtMem.cpp:404`): whisper aborts.
- `whisper-rv64-h-bare.json`: `["bare"]` with H. hypervisor.adoc requires "Sv32 for RV32, or a minimum
  of Sv39 for RV64"; f069895c accepts the configuration.
- `whisper-rv64-sv48-no-sv39.json`: `["bare", "sv48"]`. supervisor.adoc: "Implementations that support Sv48
  must also support Sv39" (norm:Sv48_requires_Sv39); f069895c accepts the configuration.
- `whisper-rv64-sv57-no-sv48.json`: `["bare", "sv39", "sv57"]`. supervisor.adoc: "Implementations that
  support Sv57 must also support Sv48" (norm:Sv57_requires_Sv48); f069895c accepts the configuration.

For the last three, `satpmode1.elf` only writes the unsupported MODE=1, which reads back as 0, so the run
ends with "Successful stop". With the patch, each configuration is rejected with an error message.
`./run.sh path/to/whisper` runs the five cases. `satpmode.S` is the source
(`riscv64-unknown-elf-gcc -nostdlib -march=rv64i_zicsr -mabi=lp64 -DMODE=1 -Ttext=0x80000000`).
