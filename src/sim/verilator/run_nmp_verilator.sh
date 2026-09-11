#!/usr/bin/env bash
# Functional check of the NMP head engine with Verilator (>= 5.0, --timing),
# using the behavioural channel model instead of HBM_controller_top + Xilinx PHY.
# Usage: scripts run from the repo root:  src/sim/verilator/run_nmp_verilator.sh [SEQ_LEN] [SEED]
set -euo pipefail
S=${1:-256}
SEED=${2:-1}
ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
RTL=$ROOT/src/rtl
WORK=$ROOT/build/nmp_verilator
mkdir -p "$WORK/vec"

python3 "$ROOT/utils/nmp_gen_vectors.py" --seq-len "$S" --seed "$SEED" --out-dir "$WORK/vec"

verilator --binary --timing -DDEBUG \
    -Wno-fatal -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-EOFNEWLINE -Wno-SYNCASYNCNET -Wno-WIDTH \
    -I"$RTL/include" -I"$RTL/nmp_accelerator" \
    --top-module nmp_head_engine_tb \
    "$ROOT/src/sim/nmp_head_engine_tb.sv" \
    "$ROOT/src/sim/verilator/HBM_controller_top_model.sv" \
    "$RTL"/nmp_accelerator/*.sv \
    "$RTL/controller/dual_port_ram.sv" \
    --Mdir "$WORK/obj_dir" -o Vnmp

cd "$WORK/vec"
"$WORK/obj_dir/Vnmp" | grep -v "^\[ NMP ROB \]" | tail -20
