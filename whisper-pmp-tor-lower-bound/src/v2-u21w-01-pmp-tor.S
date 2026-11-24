// verify-v2 repro for u21-mother-whisper-01 (adopted from work/u21-mother-whisper/u21w-pmp-tor-lowerbound.S)
// u21-mother walk (Whisper) probe: a write to pmpaddr{i-1} while entry i-1 is OFF must move the lower
// bound of a TOR entry i.
// Spec: specs/isa/src/priv/machine.adoc:3498 "If TOR is selected, the associated address register forms the top
//   of the address range, and the preceding PMP address register forms the bottom of the address range. If PMP
//   entry i's A field is set to TOR, the entry matches any address y such that pmpaddr_i-1 <= y < pmpaddr_i
//   (irrespective of the value of pmpcfg_i-1)."
//   machine.adoc:3629 (pmp_sfence) after PMP CSR writes and SFENCE.VMA x0,x0 every later access uses the new settings;
//   machine.adoc:3637 without paging the PMP settings are checked synchronously.
// Whisper: Hart.cpp:4927-4934 (postCsrUpdate) re-derives the PMP regions after a pmpaddr{i} write only when entry i
//   itself is not OFF, so a TOR entry i+1 keeps its old lower bound.
// Expected (spec): after pmpaddr1 = A'>>2 (entry 1 OFF, entry 2 TOR RW, top B) and sfence.vma, an S-mode (MPRV) load
//   from A' succeeds.  Whisper (code): load access fault (stale lower bound A).
// Addresses are 4 KiB aligned (whisper-* grain is 4 KiB, Sail/Spike grain 4 B, Imperas 64 B).
##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'S', 'U']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####
#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

// lw through MPRV with MPP = S, then clear MPRV.  Uses x7.
#define MPRV_S_LW(_rd, _ra)               \
  LI(x7, 0x1800)                         ;\
  csrc mstatus, x7                       ;\
  LI(x7, 0x20800)                        ;\
  csrs mstatus, x7                       ;\
  lw _rd, 0(_ra)                         ;\
  LI(x7, 0x21800)                        ;\
  csrc mstatus, x7                       ;\
  LI(x7, 0x1800)                         ;\
  csrs mstatus, x7

#define SOFT_TRAPS(_NT, _CAUSE, _MSG)     \
  AI_OUTCOME                             ;\
  SA_SOFT(x13, _NT, _MSG " (number of traps)") ;\
  SA_SOFT(x14, _CAUSE, _MSG " (xcause, -1 = none)")

RVTEST_BEGIN
  LA(x8, pmpbuf)            // A' (page aligned)
  LI(x9, 0x1000)
  add x10, x8, x9           // A  = A' + 4 KiB
  add x11, x10, x9          // B  = A' + 8 KiB

  csrw pmpcfg0, x0          // entries 0-7 (RV32: 0-3) OFF
  srli x6, x10, 2
  csrw pmpaddr1, x6         // entry 1 OFF, its pmpaddr = A>>2 (lower bound of entry 2)
  srli x6, x11, 2
  csrw pmpaddr2, x6         // entry 2 top = B>>2
  LI(x6, 0x0B0000)          // pmp2cfg = TOR | W | R
  csrw pmpcfg0, x6
  sfence.vma x0, x0

  SA_TRY(1)
  MPRV_S_LW(x6, x10)
  SOFT_TRAPS(0, -1, "S load at A inside TOR [A,B)")

  SA_TRY(1)
  MPRV_S_LW(x6, x8)
  SOFT_TRAPS(1, 5, "S load at A' below TOR [A,B), no other entry")

  // Move the lower bound down to A' by writing pmpaddr1 only (entry 1 stays OFF).
  srli x6, x8, 2
  csrw pmpaddr1, x6
  sfence.vma x0, x0
  csrr x12, pmpaddr1
  srli x6, x8, 2
  sub x12, x12, x6
  SA_SOFT(x12, 0, "pmpaddr1 reads back A'>>2")

  SA_TRY(1)
  MPRV_S_LW(x6, x8)
  SOFT_TRAPS(0, -1, "after pmpaddr1 = A'>>2 and sfence.vma: S load at A' inside TOR [A',B)")

  // Control: rewrite pmpcfg0 with the same value (Whisper then re-derives the regions).
  LI(x6, 0x0B0000)
  csrw pmpcfg0, x6
  sfence.vma x0, x0
  SA_TRY(1)
  MPRV_S_LW(x6, x8)
  SOFT_TRAPS(0, -1, "control: after rewriting pmpcfg0, S load at A' inside TOR [A',B)")

  // Restore the framework's background entry 0 (TOR RWX over everything).
  LI(x6, -1)
  csrw pmpaddr0, x6
  LI(x6, 0x0F)
  csrw pmpcfg0, x6
  sfence.vma x0, x0

  SA_SOFT_END
RVTEST_CODE_END

RVTEST_DATA_BEGIN
.align 12
pmpbuf: .fill 3*4096, 1, 0
RVTEST_DATA_END
RVTEST_SIG_SETUP
