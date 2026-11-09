// Whisper reproducer: Zalasr load-acquire / store-release at misaligned addresses inside one 16-byte misaligned
// atomicity granule of main memory (MAG16).
// Spec: unpriv/zalasr.adoc norm:Zalasr_misaligned_pma_relax, norm:Zalasr_misaligned_single_op ("If all accessed
//   bytes lie within the same misaligned atomicity granule, the instruction will not raise an exception for
//   reasons of address alignment"); priv/machine.adoc norm:pma_mag_insts (the PMA applies to "the load-acquire
//   and store-release instructions defined in the Zalasr extension"), norm:pma_mag_op_within.
// The test runs in M-mode on a 16-byte-aligned buffer. It is skipped (passes) if an aligned lw.aq traps
// (Zalasr not enabled).
// Result: the test fails with "Bad Value" = bitmask of failed checks (expected 0):
//   bit 0  lw.aq at offset 1 traps          bit 1  lw.aq at offset 1 returns a wrong value
//   bit 2  lh.aq at offset 1 traps          bit 3  lh.aq at offset 1 returns a wrong value
//   bit 4  ld.aq at offset 1 traps          bit 5  ld.aq at offset 1 returns a wrong value
//   bit 6  sw.rl at offset 5 traps          bit 7  sw.rl at offset 5 stores a wrong value
//   bit 8  sh.rl at offset 7 traps          bit 9  sh.rl at offset 7 stores a wrong value
//   bit 10 sd.rl at offset 3 traps          bit 11 sd.rl at offset 3 stores a wrong value
//   bit 12 ld.aq at offset 9 (crosses the granule) does not raise a load misaligned or access fault
//   bit 13 sd.rl at offset 12 (crosses the granule) does not raise a store misaligned or access fault

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'Zalasr', 'Zama16b']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

// funct3: 0 b, 1 h, 2 w, 3 d
#define LDAQ(_RD, _RS1, _F3) .word (0x6 << 27) | (1 << 26) | ((_RS1) << 15) | ((_F3) << 12) | ((_RD) << 7) | 0x2f
#define STRL(_RS2, _RS1, _F3) .word (0x7 << 27) | (1 << 25) | ((_RS2) << 20) | ((_RS1) << 15) | ((_F3) << 12) | 0x2f

// Set bit _B of the failure mask x20 (clobbers x10).
#define SETFAIL(_B) LI(x10, (1 << (_B))); or x20, x20, x10

// Restore the buffer bytes 00 11 22 ... ff.
#define RESET_BUF                                           \
  LA(x10, zbuf)                                            ;\
  LI(x11, 0x7766554433221100)                              ;\
  sd x11, 0(x10)                                           ;\
  LI(x11, 0xffeeddccbbaa9988)                              ;\
  sd x11, 8(x10)

// Load-acquire at zbuf+_OFF; expect no trap and value _VAL.
#define CHECK_LDAQ(_F3, _OFF, _VAL, _BIT)                   \
  LA(x11, zbuf + (_OFF))                                   ;\
  li x9, 0                                                 ;\
  SA_TRY(1)                                                ;\
  LDAQ(9, 11, _F3)                                         ;\
  AI_OUTCOME                                               ;\
  beqz x13, 71f                                            ;\
  SETFAIL(_BIT)                                            ;\
  j 72f                                                    ;\
71: LI(x10, _VAL)                                          ;\
  beq x9, x10, 72f                                         ;\
  SETFAIL((_BIT) + 1)                                      ;\
72:

// Store-release of _VAL at zbuf+_OFF; expect no trap and doublewords _D0/_D1 in the buffer.
#define CHECK_STRL(_F3, _OFF, _VAL, _D0, _D1, _BIT)         \
  RESET_BUF                                                ;\
  LA(x11, zbuf + (_OFF))                                   ;\
  LI(x9, _VAL)                                             ;\
  SA_TRY(1)                                                ;\
  STRL(9, 11, _F3)                                         ;\
  AI_OUTCOME                                               ;\
  beqz x13, 73f                                            ;\
  SETFAIL(_BIT)                                            ;\
  j 74f                                                    ;\
73: LA(x10, zbuf)                                          ;\
  ld x12, 0(x10)                                           ;\
  LI(x11, _D0)                                             ;\
  bne x12, x11, 75f                                        ;\
  ld x12, 8(x10)                                           ;\
  LI(x11, _D1)                                             ;\
  beq x12, x11, 74f                                        ;\
75: SETFAIL((_BIT) + 1)                                    ;\
74:

// Access crossing the granule: expect exactly one trap with cause _C1 or _C2.
#define CHECK_CROSS(_INSN, _OFF, _C1, _C2, _BIT)            \
  RESET_BUF                                                ;\
  LA(x11, zbuf + (_OFF))                                   ;\
  li x9, 0                                                 ;\
  SA_TRY(1)                                                ;\
  _INSN                                                    ;\
  AI_OUTCOME                                               ;\
  li x10, 1                                                ;\
  bne x13, x10, 76f                                        ;\
  li x10, _C1                                              ;\
  beq x14, x10, 77f                                        ;\
  li x10, _C2                                              ;\
  beq x14, x10, 77f                                        ;\
76: SETFAIL(_BIT)                                          ;\
77:

RVTEST_BEGIN
  li x20, 0
  RESET_BUF
  LA(x10, zbuf)
  SA_TRY(1)
  LDAQ(9, 10, 2)             // aligned lw.aq: skip the test if Zalasr is not enabled
  AI_OUTCOME
  bnez x13, zl_done

  CHECK_LDAQ(2, 1, 0x44332211, 0)                 // lw.aq, bytes 1-4
  CHECK_LDAQ(1, 1, 0x2211, 2)                     // lh.aq, bytes 1-2
  CHECK_LDAQ(3, 1, 0x8877665544332211, 4)         // ld.aq, bytes 1-8
  CHECK_STRL(2, 5, 0x5a5a5a5a, 0x5a5a5a4433221100, 0xffeeddccbbaa995a, 6)   // sw.rl, bytes 5-8
  CHECK_STRL(1, 7, 0xa5a5, 0xa566554433221100, 0xffeeddccbbaa99a5, 8)       // sh.rl, bytes 7-8
  CHECK_STRL(3, 3, 0x0123456789abcdef, 0x6789abcdef221100, 0xffeeddccbb012345, 10) // sd.rl, bytes 3-10
  CHECK_CROSS(LDAQ(9, 11, 3), 9, 4, 5, 12)        // ld.aq, bytes 9-16
  CHECK_CROSS(STRL(9, 11, 3), 12, 6, 7, 13)       // sd.rl, bytes 12-19
zl_done:
  SA_CHECK(x20, 0, "bitmask of failed Zalasr misaligned-granule checks (see the test header)")
RVTEST_CODE_END

RVTEST_DATA_BEGIN
.align 4
zbuf:
  .dword 0x7766554433221100
  .dword 0xffeeddccbbaa9988
  .dword 0
  .dword 0
RVTEST_DATA_END
RVTEST_SIG_SETUP
