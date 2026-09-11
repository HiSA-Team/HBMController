#!/usr/bin/env bash
# Standalone check of nmp_exp2 with Verilator (>= 5.0, --timing).
# Exhaustive over every fractional part and every shift amount, plus a random
# sweep with a non zero maximum. Usage from the repo root:
#     src/sim/verilator/run_nmp_exp2.sh
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
RTL=$ROOT/src/rtl
WORK=$ROOT/build/nmp_exp2
mkdir -p "$WORK"

# regenerate the tables so the RTL and the golden model can never drift apart
python3 "$ROOT/utils/nmp_gen_exp2_lut.py" --out "$RTL/nmp_accelerator/nmp_exp2_lut.svh"

verilator --binary --timing -DDEBUG \
    -Wno-fatal -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-EOFNEWLINE -Wno-SYNCASYNCNET -Wno-WIDTH \
    -I"$RTL/include" -I"$RTL/nmp_accelerator" \
    --top-module nmp_exp2_tb \
    "$ROOT/src/sim/nmp_exp2_tb.sv" \
    "$RTL/nmp_accelerator/nmp_exp2.sv" \
    --Mdir "$WORK/obj_dir" -o Vexp2 -O2

"$WORK/obj_dir/Vexp2" | tail -20
