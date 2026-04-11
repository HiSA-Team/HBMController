#!/usr/bin/env bash
# Questa VCD -> SAIF for Vivado read_saif, using wave2saif.
# Direct VCD input often crashes wave2saif (r0–r9 aliases / nine-state parsing); GTKWave vcd2fst avoids that.
set -euo pipefail
WAVE2SAIF="${WAVE2SAIF:-$HOME/Desktop/wave2saif_linux/wave2saif}"
VCD="${1:?usage: $0 <in.vcd> [out.saif]}"
OUT="${2:-${VCD%.vcd}.saif}"
FST="$(mktemp -t hbmXXXXXX.fst)"
trap 'rm -f "$FST"' EXIT
vcd2fst -v "$VCD" -f "$FST"
"$WAVE2SAIF" "$FST" -o "$OUT"
echo "Wrote $OUT"
