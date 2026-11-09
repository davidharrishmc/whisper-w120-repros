// The hypervisor extension depends on S-mode (it turns S-mode into HS-mode), so a misa write that clears S must
// also clear H.
//   machine.adoc norm:misa_extensions_dependencies "If an ISA feature x depends on an ISA feature y, then
//     attempting to enable feature x but disable feature y results in both features being disabled. ...
//     setting u=0 and s=1 results in both u and s being cleared."
//   hypervisor.adoc: "The hypervisor extension changes supervisor mode into hypervisor-extended supervisor mode
//     (HS-mode)"; "HS-mode acts the same as S-mode, but with additional instructions and CSRs".
// Checks (each needs the misa bit it clears to be writable, and misa.H = 1; skipped otherwise):
//   1. csrc misa, S (H stays requested): misa.S = 0 and misa.H = 0
//   2. csrc misa, U (S and H stay requested): misa.U = misa.S = misa.H = 0

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'S', 'U', 'H']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

#define FIELD(_D, _R, _SH) srli _D, _R, _SH ; andi _D, _D, 1
// x11 = 1 if misa bit _B can be cleared
#define WRITABLE(_B) LI(x8, 1 << (_B)) ; csrc misa, x8 ; csrr x11, misa ; csrs misa, x8 ; srli x11, x11, _B ; andi x11, x11, 1 ; xori x11, x11, 1

RVTEST_BEGIN
  csrw mie, x0
  csrr x9, misa
  FIELD(x7, x9, 7)
  beqz x7, t_end                     // misa.H = 0: nothing to check

  WRITABLE(18)
  beqz x11, 1f
  LI(x8, 1 << 18)
  csrc misa, x8                        // S off, H requested on (unchanged)
  csrr x10, misa
  csrw misa, x9
  FIELD(x7, x10, 18)
  SA_SOFT(x7, 0, "1: misa.S after csrc misa, S")
  FIELD(x7, x10, 7)
  SA_SOFT(x7, 0, "1: misa.H after csrc misa, S (H depends on S)")
1:
  WRITABLE(20)
  beqz x11, 1f
  LI(x8, 1 << 20)
  csrc misa, x8                        // U off, S and H requested on (unchanged)
  csrr x10, misa
  csrw misa, x9
  FIELD(x7, x10, 20)
  SA_SOFT(x7, 0, "2: misa.U after csrc misa, U")
  FIELD(x7, x10, 18)
  SA_SOFT(x7, 0, "2: misa.S after csrc misa, U (S depends on U)")
  FIELD(x7, x10, 7)
  SA_SOFT(x7, 0, "2: misa.H after csrc misa, U (H depends on S)")
1:
  csrr x10, misa
  sub x7, x10, x9
  SA_SOFT(x7, 0, "misa restored (new - old)")
  SA_SOFT_END
t_end:
RVTEST_CODE_END

RVTEST_DATA_BEGIN
RVTEST_DATA_END
RVTEST_SIG_SETUP
