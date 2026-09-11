#!/usr/bin/env python3
"""Generate nmp_exp2_lut.svh: the lookup tables used by nmp_exp2.sv for 2^f.

nmp_exp2 splits its argument x <= 0 into x = floor(x) + f with f in [0, 1):

    2^x = 2^f * 2^floor(x)

2^floor(x) is a right shift; 2^f is read from the tables generated here.
f is taken with P_FRAC fractional bits, of which the top IDX_W index the table
and the remaining ones interpolate linearly between two consecutive entries:

    y = VAL[i] + (DLT[i] * r) >> REM_W        with  i = f[P_FRAC-1 -: IDX_W]
                                                    r = f[REM_W-1:0]

    VAL[i] = round( 2^(i/LEN) * 2^OUT_FRAC )          unsigned, VAL_W bits
    DLT[i] = VAL[i+1] - VAL[i]     (VAL[LEN] = 2^(OUT_FRAC+1))

Both tables are emitted as packed localparam vectors, entry i at [i*W +: W],
so the RTL can index them with a part select and no unpacked array is needed
(Verilator refuses NBAs to unpacked arrays inside loops).

Usage:  python3 utils/nmp_gen_exp2_lut.py [--out src/rtl/nmp_accelerator/nmp_exp2_lut.svh]
"""
import argparse
import math
import os

IDX_W    = 8                    # table index bits           -> LEN = 256 entries
REM_W    = 8                    # interpolation bits         -> P_FRAC = 16
OUT_FRAC = 31                   # 2^f in Q1.31, value in [1, 2)
VAL_W    = 32
DLT_W    = 24

LEN = 1 << IDX_W


def build():
    """VAL[0..LEN-1] and DLT[0..LEN-1] as Python ints."""
    val = [round(2.0 ** (i / LEN) * (1 << OUT_FRAC)) for i in range(LEN + 1)]
    assert val[0] == 1 << OUT_FRAC, "2^0 must be exactly 1.0"
    assert val[LEN] == 1 << (OUT_FRAC + 1), "2^1 must be exactly 2.0"
    dlt = [val[i + 1] - val[i] for i in range(LEN)]
    assert max(dlt) < (1 << DLT_W), f"a delta needs more than {DLT_W} bits"
    return val[:LEN], dlt


def check(val, dlt):
    """Worst case error of the interpolated table over every possible f."""
    worst = 0.0
    worst_f = 0
    top = 0
    for f in range(1 << (IDX_W + REM_W)):
        i = f >> REM_W
        r = f & ((1 << REM_W) - 1)
        y = val[i] + ((dlt[i] * r) >> REM_W)
        top = max(top, y)
        exact = 2.0 ** (f / (1 << (IDX_W + REM_W))) * (1 << OUT_FRAC)
        err = abs(y - exact) / exact
        if err > worst:
            worst, worst_f = err, f
    return worst, worst_f, top


def packed(name, width, values):
    """A packed localparam vector, entry i at [i*width +: width]."""
    digits = (width + 3) // 4
    items = [f"{v:0{digits}x}" for v in values]
    out = [f"localparam logic [P_NMP_EXP2_LEN*P_NMP_EXP2_{name}_W-1:0] P_NMP_EXP2_{name} = {{"]
    per_line = 6
    body = []
    # a concatenation puts the FIRST item in the most significant bits,
    # so entry LEN-1 comes first and entry 0 last
    for base in range(LEN - 1, -1, -per_line):
        chunk = [items[k] for k in range(base, max(base - per_line, -1), -1)]
        idx_hi, idx_lo = base, base - len(chunk) + 1
        body.append("    " + ", ".join(f"{width}'h{c}" for c in chunk)
                    + f",   /* {idx_hi} .. {idx_lo} */")
    body[-1] = body[-1].replace(",   /*", "    /*", 1)
    out += body
    out.append("};")
    return "\n".join(out)


def box(lines):
    """Comment lines padded to the 80 column box used across the repo."""
    bar = "/" + "*" * 78 + "/"
    body = [("/* " + t).ljust(78) + "*/" for t in lines]
    return "\n".join([bar] + body + [bar])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="src/rtl/nmp_accelerator/nmp_exp2_lut.svh")
    args = ap.parse_args()

    val, dlt = build()
    worst, worst_f, top = check(val, dlt)
    assert top < (1 << (OUT_FRAC + 1)), "the interpolated value must stay below 2.0"

    hdr = box([
        "2^f LOOKUP TABLES - GENERATED FILE, DO NOT EDIT BY HAND",
        "Produced by utils/nmp_gen_exp2_lut.py",
        "",
        f"f in [0, 1) carried on {IDX_W + REM_W} bits: i = f[{IDX_W+REM_W-1}:{REM_W}] indexes the table,",
        f"r = f[{REM_W-1}:0] interpolates linearly between VAL[i] and VAL[i+1]:",
        "",
        f"    y = VAL[i] + (DLT[i] * r) >> {REM_W}        is 2^f in Q1.{OUT_FRAC}",
        "",
        f"VAL[i] = round(2^(i/{LEN}) * 2^{OUT_FRAC}), so VAL[0] = 2^{OUT_FRAC} is exactly 1.0",
        f"DLT[i] = VAL[i+1] - VAL[i], with VAL[{LEN}] = 2^{OUT_FRAC+1} = 2.0",
        "",
        f"Worst case relative error over all 2^{IDX_W+REM_W} values of f: {worst:.3e}",
        f"Largest interpolated value: {top} < 2^{OUT_FRAC+1}, it fits in {VAL_W} bits",
        "",
        "Entry i lives at [i*W +: W] of the packed vectors below.",
    ])

    head = f"""`ifndef NMP_EXP2_LUT_SVH__
`define NMP_EXP2_LUT_SVH__

{hdr}

localparam int P_NMP_EXP2_IDX_W = {IDX_W};
localparam int P_NMP_EXP2_REM_W = {REM_W};
localparam int P_NMP_EXP2_LEN   = {LEN};
localparam int P_NMP_EXP2_VAL_W = {VAL_W};
localparam int P_NMP_EXP2_DLT_W = {DLT_W};
localparam int P_NMP_EXP2_FRAC  = {OUT_FRAC};

"""
    txt = head + packed("VAL", VAL_W, val) + "\n\n" + packed("DLT", DLT_W, dlt) \
        + "\n\n`endif // NMP_EXP2_LUT_SVH__\n"

    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w") as f:
        f.write(txt)

    print(f"{LEN} entries, {VAL_W} + {DLT_W} bits  ->  {LEN*(VAL_W+DLT_W)} bits "
          f"= {LEN*(VAL_W+DLT_W)/1024:.1f} Kib")
    print(f"worst relative error {worst:.3e} = 2^{math.log2(worst):.1f} at f = {worst_f}")
    print(f"VAL[0] = {val[0]}   VAL[255] = {val[255]}   max DLT = {max(dlt)}")
    print(f"written to {os.path.abspath(args.out)}")


if __name__ == "__main__":
    main()
