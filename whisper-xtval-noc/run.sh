#!/bin/sh
# Run xtval-noc.rv{64,32}.elf on every simulator found. Override paths with the variables below.
# Result: tohost = 1 (exit status 0) passes; tohost = 43 (exit status 21) means all three probes reported only the
# low 16-bit parcel in mtval. See the header of xtval-noc.S for the code bits.
WHISPER=${WHISPER:-whisper}
QEMU_DIR=${QEMU_DIR:-}            # directory holding qemu-system-riscv64/32 (empty: use PATH)
SPIKE=${SPIKE:-spike}
SAIL=${SAIL:-sail_riscv_sim}
ISS=${ISS:-iss.exe}               # Imperas
cd "$(dirname "$0")" || exit 1
q() { if [ -n "$QEMU_DIR" ]; then echo "$QEMU_DIR/qemu-system-riscv$1"; else echo "qemu-system-riscv$1"; fi; }

for x in 64 32; do
  elf=xtval-noc.rv$x.elf
  echo "=== RV$x"

  if command -v "$WHISPER" > /dev/null 2>&1; then
    "$WHISPER" --maxinst 10000 --configfile whisper-rv$x-noc.json --logfile whisper.rv$x.log $elf > /dev/null 2>&1
    echo "whisper: tohost = 0x$(grep -a '\[0x80001000\]' whisper.rv$x.log | tail -n 1 | awk '{print $8}'); mtval:" \
      $(grep -a ' c 0*343 ' whisper.rv$x.log | awk '{print $8}' | tail -n 3)
  fi

  if command -v "$(q $x)" > /dev/null 2>&1; then
    "$(q $x)" -nographic -machine spike -cpu rv$x,c=false,zca=false -d int -D qemu.rv$x.log -bios $elf
    echo "qemu: exit $?; mtval:" $(grep -a illegal_instruction qemu.rv$x.log | sed 's/.*tval:\([^,]*\),.*/\1/')
  fi

  if command -v "$SPIKE" > /dev/null 2>&1; then
    "$SPIKE" --isa=rv${x}i_zicsr -l --log-commits --log=spike.rv$x.log $elf > /dev/null 2>&1
    echo "spike: exit $?; mtval:" $(grep -a -A1 'csrr    a7, mtval' spike.rv$x.log | grep -a ' x17 ' | awk '{print $NF}' | tail -n 3)
  fi

  if command -v "$SAIL" > /dev/null 2>&1; then
    r=""; [ $x = 32 ] && r=--rv32
    "$SAIL" $r --config-override sail-noc-override.json --trace-exception $elf > sail.rv$x.log 2>&1
    echo "sail: exit $?; mtval:" $(grep -a 'illegal-instruction at' sail.rv$x.log | sed 's/.*| tval=\([^ ]*\) .*/\1/')
  fi

  if command -v "$ISS" > /dev/null 2>&1; then
    "$ISS" --processorvendor riscv.ovpworld.org --processorname riscv --variant RV${x}I \
      --extlib iss/cpu0/cc=riscv.ovpworld.org/intercept/customControl/1.0 --override iss/cpu0/simulateexceptions=T \
      --override iss/cpu0/defaultsemihost=F --finishafter 100000 --trace --tracechange --program $elf > imperas.rv$x.log 2>&1
    echo "imperas: tohost value $(grep -a -A1 'ori     t0,t0,1' imperas.rv$x.log | tail -n 1 | awk '{print $NF}'); mtval:" \
      $(grep -a 'mtval .* -> ' imperas.rv$x.log | awk '{print $NF}' | tail -n 3)
  fi
done
