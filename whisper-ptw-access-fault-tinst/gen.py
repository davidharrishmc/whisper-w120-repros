#!/usr/bin/env python3
# Copyright 2026 David_Harris@hmc.edu.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Generate tinst-ptw.S, a self-checking mtinst/htinst reproducer for access faults on
implicit page-table-walk accesses (PTE reads and A/D updates).

Each case runs one instruction in S, U or VS mode. The trap goes to M (medeleg = 0) or to
HS (memory-fault causes delegated). The handler records cause, tval, mtinst, htinst and
mtval2/htval; M-mode then checks the cause and the trap-instruction register of the trap's
destination (mtinst for M, htinst for HS), prints one line per case and halts through
tohost (pass if every case passes).
"""
import sys

DPAGE = 0x80100000   # ordinary data page
NOACC = 0x80101000   # PMP: no S/U access
S_ROOT = 0x80200000
U_ROOT = 0x80201000
S_L1_0 = 0x80202000
S_L0_0 = 0x80203000
VS_ROOT = 0x80204000
RO_PT = 0x80207000   # PMP: S/U read-only; holds a level-1 table with an A=0 leaf
G_ROOT = 0x80210000  # 16 KiB aligned
G_L1_0 = 0x80214000
G_L0_0 = 0x80215000
RECS = 0x80300000
SENT = 0xBAD0BAD1    # written to mtinst/htinst before each case

V, R, W, X, U, A, D = 1, 2, 4, 8, 0x10, 0x40, 0x80


def pte(pa, flags):
    return ((pa >> 12) << 10) | flags


PTES = [
    # S-stage (satp) tables
    (S_ROOT, 0, pte(S_L1_0, V)),
    (S_ROOT, 1, pte(NOACC, V)),                     # VA 0x4000_0000: walk reads the PMP no-access page
    (S_ROOT, 2, pte(0x80000000, V | R | W | X | A | D)),
    (S_ROOT, 3, pte(RO_PT, V)),                     # VA 0xC000_0000: leaf with A=0 in a PMP read-only page
    (U_ROOT, 1, pte(NOACC, V)),
    (U_ROOT, 2, pte(0x80000000, V | R | W | X | U | A | D)),
    (S_L1_0, 0, pte(S_L0_0, V)),
    (S_L0_0, 0, pte(DPAGE, V | R | W | A | D)),     # VA 0x0000 -> DPAGE; VA 0x1000 invalid
    (RO_PT, 0, pte(0x80000000, V | R | W)),         # 2 MiB leaf, A=0 D=0: needs an A/D update
    # VS-stage (vsatp) tables
    (VS_ROOT, 1, pte(NOACC, V)),                    # VA 0x4000_0000: walk reads the PMP no-access page
    (VS_ROOT, 2, pte(0x80000000, V | R | W | X | A | D)),
    (VS_ROOT, 4, pte(RO_PT, V)),                    # VA 0x1_0000_0000: leaf with A=0 in a PMP read-only page
    (VS_ROOT, 5, pte(0x40000000, V)),               # VA 0x1_4000_0000: walk reads GPA 0x4000_0000 (G-stage hole)
    # G-stage (hgatp Sv39x4) tables
    (G_ROOT, 0, pte(G_L1_0, V)),
    (G_ROOT, 2, pte(0x80000000, V | R | W | X | U | A | D)),
    (G_ROOT, 3, pte(NOACC, V)),                     # GPA 0xC000_0000: G-stage walk reads the PMP no-access page
    (G_L1_0, 0, pte(G_L0_0, V)),
    (G_L0_0, 0, pte(DPAGE, V | R | W | U | A | D)),  # GPA 0x0000 -> DPAGE
]

SV39 = 8 << 60
SATP = {'bare': 0, 'sv39': SV39 | (S_ROOT >> 12), 'sv39u': SV39 | (U_ROOT >> 12)}
VSATP = {'bare': 0, 'sv39': SV39 | (VS_ROOT >> 12)}
HGATP = {'bare': 0, 'sv39x4': SV39 | (G_ROOT >> 12)}
DELEG_HS = sum(1 << c for c in (5, 7, 13, 15, 21, 23))
MPP = {'M': 3 << 11, 'S': 1 << 11, 'U': 0, 'VS': (1 << 11) | (1 << 39)}

INSN = {
    'ld': "ld a2, 24(a1)", 'sd': "sd a3, 24(a1)", 'amoadd.d': "amoadd.d a2, a3, (a1)",
    'c.lw': ".option push; .option arch, +c; c.lw a2, 24(a1); .option pop",
    'hlv.d': "hlv.d a2, (a1)",
}
OFFSET = {'ld': 24, 'sd': 24, 'c.lw': 24}
LOAD = {'ld', 'c.lw', 'hlv.d'}

cases = []


def case(name, op, mode, deleg, target, cause, expect, satp='bare', vsatp='bare', hgatp='bare'):
    """expect: ('zero',) | ('zero-or', T) | ('pseudo', P): P required when xtval2 != 0, else 0 or P."""
    cases.append({'name': name, 'insn': INSN[op], 'base': target - OFFSET.get(op, 0), 'mode': mode,
                  'deleg': deleg, 'cause': cause, 'expect': expect, 'satp': satp, 'vsatp': vsatp, 'hgatp': hgatp})


def fault(op, kind):
    return {'acc': 5, 'pf': 13, 'gpf': 21}[kind] + (0 if op in LOAD else 2)


for deleg in ('M', 'HS'):
    for op in ('ld', 'sd', 'amoadd.d', 'c.lw'):
        case(f"{op}: S-stage PTE read PMP-denied, S->{deleg}", op, 'S', deleg, 0x40000000 + 0x40,
             fault(op, 'acc'), ('zero',), satp='sv39')
case("ld: S-stage PTE read PMP-denied, U->M", 'ld', 'U', 'M', 0x40000000 + 0x40, 5, ('zero',), satp='sv39u')
for op in ('ld', 'sd'):
    case(f"{op}: S-stage A/D update PMP-denied, S->M", op, 'S', 'M', 0xC0100000 + 0x40,
         fault(op, 'acc'), ('zero',), satp='sv39')
for deleg in ('M', 'HS'):
    for op in ('ld', 'sd'):
        case(f"{op}: VS-stage PTE read PMP-denied (hgatp Bare), VS->{deleg}", op, 'VS', deleg,
             0x40000000 + 0x40, fault(op, 'acc'), ('zero',), vsatp='sv39')
case("ld: VS-stage PTE read PMP-denied (hgatp Sv39x4), VS->HS", 'ld', 'VS', 'HS', 0x40000000 + 0x40, 5,
     ('zero',), vsatp='sv39', hgatp='sv39x4')
case("ld: VS-stage A/D update PMP-denied, VS->HS", 'ld', 'VS', 'HS', 0x100100000 + 0x40, 5, ('zero',),
     vsatp='sv39')
case("ld: G-stage PTE read PMP-denied, VS->HS", 'ld', 'VS', 'HS', 0xC0000000 + 0x40, 5, ('zero',),
     hgatp='sv39x4')
case("hlv.d: VS-stage PTE read PMP-denied, HS->HS", 'hlv.d', 'S', 'HS', 0x40000000 + 0x40, 5, ('zero',),
     vsatp='sv39')
# Explicit-access faults keep their transformation; a guest-page fault on a VS-stage PTE read
# writes the pseudoinstruction.
case("control ld: explicit PMP access fault, S->M", 'ld', 'S', 'M', NOACC + 0x40, 5, ('zero-or', 0x3603))
case("control ld: explicit page fault, S->HS", 'ld', 'S', 'HS', 0x1000 + 0x40, 13, ('zero-or', 0x3603),
     satp='sv39')
case("control ld: VS-stage PTE read guest-page fault, VS->HS", 'ld', 'VS', 'HS', 0x140000000 + 0x40, 21,
     ('pseudo', 0x3000), vsatp='sv39', hgatp='sv39x4')

out = []
emit = out.append
emit(f"""// Generated by gen.py. mtinst/htinst reproducer, self-checking.
#include "rvmodel_macros.h"
#define RETMAGIC 0x52455431
.option norvc
.section .text.init
.globl rvtest_entry_point
rvtest_entry_point:
  la t0, m_handler
  csrw mtvec, t0
  la t0, s_handler
  csrw stvec, t0
#ifdef RVMODEL_IO_INIT
  RVMODEL_IO_INIT(t0, t1, t2)
#endif
  // Smdbltrp: clear mstatus.MDT with an mret to M-mode
  la t0, 1f
  csrw mepc, t0
  li t0, (3 << 11)
  csrs mstatus, t0
  mret
1:
#ifdef SMRNMI
  csrsi 0x744, 8       // mnstatus.NMIE = 1, so M-mode traps are expected
#endif
  li t0, (3 << 13)     // FS = dirty
  csrs mstatus, t0
  csrs vsstatus, t0
  // PMP: entry 0 = NOACC page (no S/U access), entry 1 = RO_PT page (S/U read-only), entry 2 = all RWX
  li t0, {hex((NOACC >> 2) | 0x1FF)}
  csrw pmpaddr0, t0
  li t0, {hex((RO_PT >> 2) | 0x1FF)}
  csrw pmpaddr1, t0
  li t0, -1
  csrw pmpaddr2, t0
  li t0, 0x1F1918
  csrw pmpcfg0, t0
  // menvcfg/henvcfg: CBIE = 11, CBCFE, CBZE, ADUE (hardware A/D updates); senvcfg: CBIE = 11, CBCFE, CBZE
  li t0, 0xF0
  li t1, 1
  slli t1, t1, 61
  or t0, t0, t1
  csrs menvcfg, t0
  csrs henvcfg, t0
  li t0, 0xF0
  csrs senvcfg, t0
  li t0, (1 << 8)      // hstatus.SPVP = 1: HLV/HSV from HS-mode access as VS
  csrs hstatus, t0
  li t0, 0x80200000    // clear the page-table area
  li t1, 0x80220000
1: sd zero, 0(t0)
  addi t0, t0, 8
  bltu t0, t1, 1b
  la t0, recptr
  li t1, {hex(RECS)}
  sd t1, 0(t0)
  li s8, 0             // failure count""")
for base, idx, val in PTES:
    emit(f"  li t0, {hex(base + 8 * idx)}\n  li t1, {hex(val)}\n  sd t1, 0(t0)")
emit("  sfence.vma\n  j run_cases")

emit("""
.balign 64
m_handler:
  la t1, trapcount
  ld t2, 0(t1)
  addi t2, t2, 1
  sd t2, 0(t1)
  li t3, 6
  bgeu t2, t3, m_runaway
  csrr t0, mcause
  li t1, RETMAGIC
  bne s9, t1, m_rec
  li t1, 8
  beq t0, t1, m_ret
  li t1, 9
  beq t0, t1, m_ret
  li t1, 10
  beq t0, t1, m_ret
m_rec:                 // record: case, 'M', cause, tval, mtinst, htinst, mtval2
  la t1, recptr
  ld t2, 0(t1)
  sd s10, 0(t2)
  li t3, 'M'
  sd t3, 8(t2)
  sd t0, 16(t2)
  csrr t3, mtval
  sd t3, 24(t2)
  csrr t3, mtinst
  sd t3, 32(t2)
  csrr t3, htinst
  sd t3, 40(t2)
  csrr t3, mtval2
  sd t3, 48(t2)
  addi t2, t2, 64
  sd t2, 0(t1)
  csrw mepc, s11
  mret
m_runaway:
  la t1, trapcount
  sd zero, 0(t1)
  li s9, 0
  la t1, next_case
  ld t1, 0(t1)
  j m_jump
m_ret:
  la t1, m_cont
  ld t1, 0(t1)
m_jump:                // continue in M-mode at t1 through mret (clears MDT)
  csrw mepc, t1
  li t1, (1 << 39)
  csrc mstatus, t1
  li t1, (3 << 11)
  csrs mstatus, t1
  li t1, (1 << 7)
  csrc mstatus, t1
  mret

.balign 64
s_handler:             // record: case, 'H', cause, tval, -, htinst, htval
  csrr t0, scause
  la t1, recptr
  ld t2, 0(t1)
  sd s10, 0(t2)
  li t3, 'H'
  sd t3, 8(t2)
  sd t0, 16(t2)
  csrr t3, stval
  sd t3, 24(t2)
  li t3, -1
  sd t3, 32(t2)
  csrr t3, htinst
  sd t3, 40(t2)
  csrr t3, htval
  sd t3, 48(t2)
  addi t2, t2, 64
  sd t2, 0(t1)
  csrw sepc, s11
  sret

// After each case (M-mode): add an 'N' record if nothing trapped.
post_case:
  la t1, trapcount
  sd zero, 0(t1)
  la t1, recptr
  ld t2, 0(t1)
  la t3, recstart
  ld t3, 0(t3)
  bne t2, t3, 1f
  sd s10, 0(t2)
  li t4, 'N'
  sd t4, 8(t2)
  sd zero, 16(t2)
  sd zero, 24(t2)
  sd zero, 32(t2)
  sd zero, 40(t2)
  sd zero, 48(t2)
  addi t2, t2, 64
  sd t2, 0(t1)
1:
  ret

// report: s1 = record, s2 = case name, s3 = trap-instruction value checked, s4 = 0 pass / 1 fail.
// Prints "<PASS|FAIL> <name>: mcause/scause=<c> xtinst=<v> xtval2=<v>".
report:
  mv s5, ra
  add s8, s8, s4
  la a0, linebuf
  la a5, str_pass
  beqz s4, 1f
  la a5, str_fail
1:
  jal ra, putstr
  mv a5, s2
  jal ra, putstr
  la a5, str_cause
  jal ra, putstr
  ld a1, 16(s1)
  jal ra, puthex
  la a5, str_tinst
  jal ra, putstr
  mv a1, s3
  jal ra, puthex
  la a5, str_tval2
  jal ra, putstr
  ld a1, 48(s1)
  jal ra, puthex
  li t0, 10
  sb t0, 0(a0)
  sb zero, 1(a0)
  la a0, linebuf
  RVMODEL_IO_WRITE_STR(t0, t1, t2, a0)
  mv ra, s5
  ret

putstr:                // copy NUL-terminated string a5 to a0, advance a0
  lbu t0, 0(a5)
  beqz t0, 1f
  sb t0, 0(a0)
  addi a0, a0, 1
  addi a5, a5, 1
  j putstr
1:
  ret

puthex:                // write a1 as 0x + 16 hex digits at a0, advance a0
  li t0, '0'
  sb t0, 0(a0)
  li t0, 'x'
  sb t0, 1(a0)
  addi a0, a0, 2
  li t1, 60
1:
  srl t2, a1, t1
  andi t2, t2, 15
  li t3, 10
  blt t2, t3, 2f
  addi t2, t2, 'a' - 10
  j 3f
2:
  addi t2, t2, '0'
3:
  sb t2, 0(a0)
  addi a0, a0, 1
  addi t1, t1, -4
  bgez t1, 1b
  ret
""")

emit("run_cases:")
names = []
for cid, c in enumerate(cases):
    nxt = f"case_{cid+1}" if cid + 1 < len(cases) else "finish"
    emit(f"// case {cid}: {c['name']}")
    emit(f"case_{cid}:\n  li s10, {cid}")
    emit(f"  la t0, {nxt}\n  la t1, next_case\n  sd t0, 0(t1)\n  li s9, 0")
    emit(f"  li t0, {hex(SATP[c['satp']])}\n  csrw satp, t0")
    emit(f"  li t0, {hex(VSATP[c['vsatp']])}\n  csrw vsatp, t0")
    emit(f"  li t0, {hex(HGATP[c['hgatp']])}\n  csrw hgatp, t0")
    emit("  sfence.vma\n  hfence.vvma\n  hfence.gvma")
    emit(f"  li t0, {hex(DELEG_HS if c['deleg'] == 'HS' else 0)}\n  csrw medeleg, t0")
    emit(f"  li t0, {hex(SENT)}\n  csrw mtinst, t0\n  csrw htinst, t0")
    emit("  la t1, recptr\n  ld t0, 0(t1)\n  la t1, recstart\n  sd t0, 0(t1)")
    insn = c['insn'].replace(';', '\n ')
    # enter the test mode with mret; ecall (with s9 = RETMAGIC) returns to M at 3f
    emit("  li t0, (3 << 11) | (1 << 39) | (1 << 17)\n  csrc mstatus, t0")
    if MPP[c['mode']]:
        emit(f"  li t0, {hex(MPP[c['mode']])}\n  csrs mstatus, t0")
    emit("  la t0, 2f\n  csrw mepc, t0\n  la t0, 3f\n  la t1, m_cont\n  sd t0, 0(t1)")
    emit(f"  li a1, {hex(c['base'])}")
    emit("  mret\n2:")
    emit(f"  la s11, 1f\n  {insn}\n1:")
    emit("  li s9, RETMAGIC\n  ecall\n3:\n  li s9, 0\n  jal ra, post_case")
    # check: first record of this case is a trap to the expected mode with the expected cause
    who = 'M' if c['deleg'] == 'M' else 'H'
    emit("  la t0, recstart\n  ld s1, 0(t0)")
    emit(f"  la s2, name_{cid}")
    emit(f"  ld s3, {32 if who == 'M' else 40}(s1)")
    emit(f"  ld t0, 8(s1)\n  li t1, '{who}'\n  bne t0, t1, 8f")
    emit(f"  ld t0, 16(s1)\n  li t1, {c['cause']}\n  bne t0, t1, 8f")
    kind = c['expect'][0]
    if kind == 'zero':
        emit("  beqz s3, 7f")
    elif kind == 'zero-or':
        emit(f"  beqz s3, 7f\n  li t1, {hex(c['expect'][1])}\n  beq s3, t1, 7f")
    else:  # pseudo
        emit(f"  li t1, {hex(c['expect'][1])}\n  beq s3, t1, 7f\n  ld t0, 48(s1)\n  bnez t0, 8f\n  beqz s3, 7f")
    emit("8:\n  li s4, 1\n  j 9f\n7:\n  li s4, 0\n9:\n  jal ra, report")
    names.append(c['name'])

emit("""
finish:
  li t0, (1 << 17)
  csrc mstatus, t0
  csrw satp, zero
  bnez s8, 1f
  RVMODEL_HALT_PASS
1:
  RVMODEL_HALT_FAIL

.data
.balign 8
recptr: .dword 0
recstart: .dword 0
m_cont: .dword 0
next_case: .dword 0
trapcount: .dword 0
linebuf: .space 256
str_pass: .string "PASS "
str_fail: .string "FAIL "
str_cause: .string ": xcause="
str_tinst: .string " xtinst="
str_tval2: .string " xtval2="
""")
for cid, n in enumerate(names):
    emit(f'name_{cid}: .string "{n}"')
emit("RVMODEL_DATA_SECTION")

with open('tinst-ptw.S', 'w') as f:
    f.write("\n".join(out) + "\n")
print(f"tinst-ptw.S: {len(cases)} cases", file=sys.stderr)
