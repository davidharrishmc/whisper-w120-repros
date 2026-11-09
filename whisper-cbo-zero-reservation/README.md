# Whisper: a cbo.zero by another hart does not invalidate this hart's reservation

Zalrsc (unpriv/zalrsc.adoc, norm:sc_other_hart_store_fail): "The SC must fail if a store to the reservation set
from another hart can be observed to occur between the LR and SC." Zicboz (unpriv/cmo.adoc, norm:cbo-zero_op):
"A cbo.zero instruction performs stores of zeros to the full set of bytes corresponding to the cache block".

`lrsc-cbo-zero-2h.S` is a standalone two-hart program (`--harts 2`). Hart 0 does `lr.d` on `A` and waits; hart 1
then does `cbo.zero` on `A`'s cache block, checks that `A` changed, and signals hart 0; hart 0 then does `sc.d` on
`A` with the value its LR read. The SC must fail. If it succeeds, it writes the old value back over the zeros (a
lost update). `lrsc-sw-control-2h.elf` is the same program with an ordinary `sw` instead of `cbo.zero` (control).

tohost: 1 = pass (SC failed), 3 = FAIL (SC succeeded after the other hart's write), 5 = setup problem.

Run: `./run.sh path/to/whisper` (runs both ELFs with `--deterministic 1:3 --seed 7` and threaded; prints PASS or
FAIL). Rebuild: `./build.sh` (riscv64-unknown-elf-gcc; `link.ld` puts the code at 0x80000000 and `tohost` at
0x80001000). `whisper.json` is the riscv-arch-test whisper-rv64-max configuration.

Whisper master fa18e475 (`master.out`): the `cbo.zero` program fails in both modes, the `sw` control passes. The
trace shows the LR, hart 1's eight zeroing stores, and the SC succeeding (rd = 0) and writing the old value back:

```
#15 0  M 000000008000002a 100433af r 0000000000000007 1111111111111111 lr.d x7, (x8) [0x80002000]
#17 1  M 0000000080000064 0044200f m 0000000080002000 0000000000000000 cbo.zero 0(x8) [0x80002000]  +
...
#17 1  M 0000000080000064 0044200f m 0000000080002038 0000000000000000 cbo.zero 0(x8) [0x80002000]
#39 0  M 000000008000003e 19c43eaf r 000000000000001d 0000000000000000 sc.d x29, x28, (x8) [0x80002000]  +
#39 0  M 000000008000003e 19c43eaf m 0000000080002000 1111111111111111 sc.d x29, x28, (x8) [0x80002000]
```

With `execCbo_zero` invalidating the other harts' reservations on the block (`fixed.out`), both pass.

Other simulators: Spike c20813c (`spike -p2`) makes the SC fail, but it also fails when hart 1 writes nothing
(Spike drops the reservation when it switches harts), so its result says nothing about this case. Stock Imperas
Y-2026.09 (`numHarts=2`) passes: its SC succeeds when hart 1 writes nothing and fails after hart 1's `cbo.zero`.
Sail is a single-hart model.
