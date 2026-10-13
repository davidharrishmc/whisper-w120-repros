# whisper-vector-params (item 39 of whisper#120)

Whisper-only reproducer: two variants of whisper-rv64-max-VLEN-512 (RV64 with V) whose `vector`
section sets element sizes that no vector extension allows. f069895c accepts both.

- `whisper-max-bytes-16.json`: `max_bytes_per_elem = 16`. vsew encodings above 3 (SEW > 64) are reserved,
  but whisper accepts them: `vsew128.elf` (vsetvl with vsew = 4, exit code 1 when vill stays clear) ends
  with "Failed stop", i.e. vtype was accepted.
- `whisper-min-bytes-2.json`: `min_bytes_per_elem = 2` removes SEW=8, which every vector extension
  (V and every Zve*) supports.

With the patch each is a configuration error. `./run.sh path/to/whisper` runs the two cases. `vsew128.S`
is the source (`riscv64-unknown-elf-gcc -nostdlib -march=rv64imv_zicsr -mabi=lp64 -Ttext=0x80000000`).
