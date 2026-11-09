# Whisper: another hart's hardware A/D update does not invalidate a reservation on the PTE

Zalrsc (unpriv/zalrsc.adoc, norm:sc_other_hart_store_fail): "The SC must fail if a store to the reservation set
from another hart can be observed to occur between the LR and SC." With Svadu (menvcfg.ADUE = 1), the page-table
walk's A/D update is a write of the PTE by the walking hart (priv/supervisor.adoc: "The PTE update must be atomic
with respect to other accesses to the PTE" and "must appear in the global memory order before the memory access
that caused the PTE update").

`lrsc-ad-update-2h.S` is a standalone two-hart program (`--harts 2`). Hart 1 sets up Sv39 so that VA 0x40000000
maps to page `D` through the leaf PTE `pt_l0[0]`, sets menvcfg.ADUE and (Smrnmi) mnstatus.NMIE. Hart 0 does `lr.d`
on the PTE and waits. Hart 1 then loads (`-a-bit`, PTE A = 0) or stores (`-d-bit`, PTE A = 1, D = 0) through the
VA with mstatus.MPRV = 1 and MPP = S, so its page-table walk sets A (or D); it checks that the bit is now set and
signals hart 0. Hart 0 then does `sc.d` on the PTE with the value its LR read. The SC must fail; if it succeeds, it
clears the A (or D) bit that the walk just set. `-sd-control` sets A with an ordinary `sd` instead (control).

tohost: 1 = pass (SC failed), 3 = FAIL (SC succeeded after the other hart's A/D update), 5 = setup problem.

Run: `./run.sh path/to/whisper` (runs the three ELFs with `--deterministic 1:3 --seed 7` and threaded; prints
PASS or FAIL). Rebuild: `./build.sh` (riscv64-unknown-elf-gcc). `whisper.json` is the riscv-arch-test
whisper-rv64-max configuration.

Whisper master fa18e475 (`master.out`): the A-bit and D-bit programs fail in both modes; the `sd` control passes.
In the A-bit run, hart 0's LR reads PTE 0x20001407, hart 1's walk sets A (0x20001447), and hart 0's `sc.d`
succeeds and writes 0x20001407 back:

```
#57 0  M 000000008000002a 100433af r 0000000000000007 0000000020001407 lr.d x7, (x8) [0x80004000]
#87 0  M 000000008000003e 19c43eaf r 000000000000001d 0000000000000000 sc.d x29, x28, (x8) [0x80004000]  +
#87 0  M 000000008000003e 19c43eaf m 0000000080004000 0000000020001407 sc.d x29, x28, (x8) [0x80004000]
```

With the A/D-update write callback invalidating the other harts' reservations (`fixed.out`), all pass.

Other simulators: stock Imperas Y-2026.09 (`numHarts=2`) passes all three: its SC succeeds when hart 1 writes
nothing and fails after hart 1's A/D update. Spike c20813c (`spike -p2`) makes the SC fail, but it also fails
when hart 1 writes nothing (Spike drops the reservation when it switches harts), so its result says nothing about
this case. Sail is a single-hart model.
