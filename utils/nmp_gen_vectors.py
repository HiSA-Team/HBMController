#!/usr/bin/env python3
"""Generate stimulus and reference for nmp_head_engine_tb (one MHA head, decode step).

Writes, in --out-dir (default: current directory):
  nmp_seq_len.hex : one line, S in hex
  nmp_q.hex       : 8 lines, q_h as 8 beats of 16 fp16 (block j = q[16j .. 16j+15])
  nmp_k.hex       : 8*S lines, K_h block by block (token-major: line 8*t + j = k_t[16j .. 16j+15])
  nmp_v.hex       : 8*S lines, V_h in the same layout
  nmp_scores.hex  : S lines, s'_t as 32-bit two's complement words in Q15.16 (what the engine
                    writes into its score buffer during pass K, before the softmax)
  nmp_otilde.hex  : 128 lines, o~_i = sum_t p_t * v_t[i] as fp32 bit patterns (what the
                    engine streams out on o_o: the UNNORMALISED head output)
  nmp_lm.hex      : 2 lines, l as an fp32 bit pattern and m as a 32-bit Q15.16 word
  nmp_ref.hex     : 128 lines, o_h = o~ / l = softmax(q.K^T / sqrt(d)) . V as fp32 bit
                    patterns - the end to end reference, reconstructed by the consumer

Beat format: element i occupies bits [16i+15 : 16i] of the 256-bit word, so the
first hex digits of a line are element 15 (the same convention as the DUT).

The reference is the arithmetic of the v1 datapath, bit for bit:
  * fp16 x fp16 products are exact integers (11 x 11 bit significands);
  * every product is aligned to a fixed-point grid with ACC_FRAC fractional bits
    (shift left, or shift right with truncation toward zero) and summed as a
    plain integer: exact and order independent;
  * a score is the accumulator multiplied by the exact constant
    C = log2(e)/sqrt(d) in Q0.32 and shifted back to Q15.16 (floor), saturating;
  * the softmax is in base 2 and entirely integer: m' = max s'_t,
    p_t = 2^(s'_t - m') in unsigned Q1.31 from the same 256-entry interpolated
    table the RTL uses, l = sum_t p_t as a plain integer (no rounding at all);
  * in the V pass p_t (already Q1.31) is multiplied exactly by v (11-bit
    significand), aligned and accumulated as above;
  * an output is the accumulator converted to fp32 and nothing else: the engine
    emits (o~, l, m) and whoever consumes the head does o = o~ / l. That last
    division is the only floating point operation in the whole chain and it
    happens outside the accelerator.
"""
import argparse
import math
import os
import struct
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from nmp_gen_exp2_lut import build as exp2_build, IDX_W, REM_W, OUT_FRAC   # noqa: E402

D_HEAD = 128
ELEM_PER_BEAT = 16
BLK_PER_ROW = D_HEAD // ELEM_PER_BEAT
ACC_FRAC = 32                     # P_NMP_ACC_FRAC
ACC_W = 64                        # P_NMP_ACC_W
P_EXP = -21                       # p_fixed * 2^-31 = sig * 2^(exp - 10)

# Step 2: the scale and the change of base folded into one Q0.32 constant,
# the same literal the RTL carries as LP_SCALE
SCALE_Q32 = 0x20A4FB7B            # log2(e) / sqrt(128)
SCALE_FRAC = 32
SCORE_FRAC = 16                   # s' is Q15.16
SCORE_W = 32
SCORE_SHIFT = ACC_FRAC + SCALE_FRAC - SCORE_FRAC          # 48

EXP2_VAL, EXP2_DLT = exp2_build()


def f32(x):
    return np.float32(x)


def fp16_bits(v):
    return int(np.array(v, dtype=np.float16).view(np.uint16))


def fp32_bits(x):
    return struct.unpack("<I", struct.pack("<f", float(x)))[0]


def bits_fp32(b):
    return struct.unpack("<f", struct.pack("<I", b & 0xFFFFFFFF))[0]


def fp16_decode(h):
    """fp16 bit pattern -> (sign, significand 11 bit, exponent) with value = sig * 2^(exp-10)."""
    s = (h >> 15) & 1
    e = (h >> 10) & 0x1F
    m = h & 0x3FF
    if e == 0:
        return s, m, -14
    return s, m | 0x400, e - 15


def aligned(sig_a, exp_a, sig_b, exp_b):
    """|product| placed on the accumulator grid, as a Python int (exact or truncated)."""
    prod = sig_a * sig_b
    sh = exp_a + exp_b - 20 + ACC_FRAC
    if sh >= 0:
        val = prod << sh
        assert val < (1 << (ACC_W - 1)), "aligned product does not fit in the accumulator"
        return val
    return prod >> (-sh)


def acc_to_fp32_bits(acc):
    """Fixed-point accumulator (value acc / 2^ACC_FRAC) -> fp32 bits, round to nearest even."""
    if acc == 0:
        return 0
    s = 1 if acc < 0 else 0
    mag = -acc if acc < 0 else acc
    msb = mag.bit_length() - 1
    if msb > 23:
        drop = msb - 23
        m24 = mag >> drop
        rest = mag & ((1 << drop) - 1)
        half = 1 << (drop - 1)
        if rest > half or (rest == half and (m24 & 1)):
            m24 += 1
            if m24 == (1 << 24):
                m24 = 1 << 23
                msb += 1
    elif msb == 23:
        m24 = mag
    else:
        m24 = mag << (23 - msb)
    e32 = msb - ACC_FRAC + 127
    if e32 >= 255:
        return (s << 31) | (0xFF << 23)
    if e32 <= 0:
        return s << 31
    return (s << 31) | (e32 << 23) | (m24 & 0x7FFFFF)


def scale_score(acc):
    """Accumulator (Q31.32) -> s' (Q15.16 signed), exactly as the RTL scaling block.

    Python's >> on a negative int already floors, which is what >>> does on a
    two's complement word, so the two cannot disagree.
    """
    shifted = (acc * SCALE_Q32) >> SCORE_SHIFT
    hi = (1 << (SCORE_W - 1)) - 1
    lo = -(1 << (SCORE_W - 1))
    if shifted > hi:
        return hi, True
    if shifted < lo:
        return lo, True
    return shifted, False


def exp2_q31(x):
    """x = s' - m' in Q15.16, x <= 0  ->  2^x in unsigned Q1.31, exactly as nmp_exp2."""
    if x > 0:                      # cannot happen, m' is the maximum
        x = 0
    n = x >> SCORE_FRAC            # floor toward -infinity, like slicing the top bits
    f = x - (n << SCORE_FRAC)      # 0 .. 2^SCORE_FRAC - 1
    nsh = -n
    if nsh >= OUT_FRAC + 1:        # below the resolution of Q1.31
        return 0
    i = f >> REM_W
    r = f & ((1 << REM_W) - 1)
    y = EXP2_VAL[i] + ((EXP2_DLT[i] * r) >> REM_W)
    return y >> nsh


def beat_hex(vals16):
    """16 fp16 values -> 64 hex digits, element 15 first."""
    assert len(vals16) == ELEM_PER_BEAT
    word = 0
    for i, v in enumerate(vals16):
        word |= fp16_bits(v) << (16 * i)
    return f"{word:064x}"


def reference(q, K, V):
    """q: (d,) fp16 ; K, V: (S, d) fp16 -> (scores fp32 bits, o fp32 bits), v1 arithmetic."""
    S = K.shape[0]
    qd = [fp16_decode(fp16_bits(x)) for x in q]
    Kd = [[fp16_decode(fp16_bits(x)) for x in row] for row in K]
    Vd = [[fp16_decode(fp16_bits(x)) for x in row] for row in V]

    # pass K: exact integer accumulation of the 128 aligned products, then s' = acc * C
    s_bits = []
    s_val = []
    n_sat = 0
    for t in range(S):
        acc = 0
        for i in range(D_HEAD):
            sa, ga, ea = qd[i]
            sb, gb, eb = Kd[t][i]
            term = aligned(ga, ea, gb, eb)
            acc += -term if (sa ^ sb) else term
        sv, sat = scale_score(acc)
        n_sat += sat
        s_bits.append(sv & 0xFFFFFFFF)
        s_val.append(sv)

    # softmax in base 2, all integer: m' = max s', p = 2^(s' - m'), l = sum p
    m = max(s_val)
    p_q31 = [exp2_q31(s - m) for s in s_val]
    l = sum(p_q31)

    # pass V: p_t already in Q1.31 times v, exact integer accumulation
    o_acc = [0] * D_HEAD
    for t in range(S):
        pq = p_q31[t]
        for i in range(D_HEAD):
            sv_, gv, ev = Vd[t][i]
            term = aligned(pq, P_EXP, gv, ev)
            o_acc[i] += -term if sv_ else term

    # what the engine actually emits: o~ in fp32, l in fp32, m in Q15.16.
    # l is an exact integer in Q1.31; acc_to_fp32_bits reads a Q_.32 word, so it
    # is doubled on the way in, exactly like the RTL does.
    ot_bits = [acc_to_fp32_bits(o_acc[i]) for i in range(D_HEAD)]
    l_bits  = acc_to_fp32_bits(l << 1)
    m_word  = m & 0xFFFFFFFF

    # what the consumer reconstructs: o = o~ / l, in fp32
    l_real = bits_fp32(l_bits)
    o_bits = []
    for i in range(D_HEAD):
        ov = f32(np.float64(bits_fp32(ot_bits[i])) / np.float64(l_real))
        o_bits.append(fp32_bits(ov))
    return s_bits, ot_bits, l_bits, m_word, o_bits, m / float(1 << SCORE_FRAC), l_real, n_sat


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seq-len", type=int, default=256, help="S, tokens in the context (1..2048)")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--out-dir", default=".")
    ap.add_argument("--dist", default="normal", choices=["normal", "wide", "extreme"],
                    help="normal: N(0,1); wide: log-normal magnitudes over ~8 decades; "
                         "extreme: wide plus zeros, fp16 subnormals and values up to ~1e4")
    args = ap.parse_args()

    S = args.seq_len
    assert 1 <= S <= 2048
    rng = np.random.default_rng(args.seed)

    # q, k ~ N(0,1): scores q.k/sqrt(d) ~ N(0,1), a realistic softmax spread
    def draw(shape):
        if args.dist == "normal":
            x = rng.standard_normal(shape)
        else:
            x = rng.standard_normal(shape) * np.exp(rng.uniform(-9, 5, shape))   # magnitudes 1e-4 .. 1e2
            if args.dist == "extreme":
                sel = rng.uniform(size=shape)
                x = np.where(sel < 0.05, 0.0, x)
                x = np.where((sel >= 0.05) & (sel < 0.10), rng.uniform(-6e-5, 6e-5, shape), x)   # fp16 subnormals
                x = np.where((sel >= 0.10) & (sel < 0.12), rng.uniform(-1e4, 1e4, shape), x)
        return x.astype(np.float16)
    q = draw(D_HEAD)
    K = draw((S, D_HEAD))
    V = draw((S, D_HEAD))

    s_bits, ot_bits, l_bits, m_word, o_bits, m, l, n_sat = reference(q, K, V)

    os.makedirs(args.out_dir, exist_ok=True)
    with open(os.path.join(args.out_dir, "nmp_seq_len.hex"), "w") as f:
        f.write(f"{S:x}\n")
    with open(os.path.join(args.out_dir, "nmp_q.hex"), "w") as f:
        for j in range(BLK_PER_ROW):
            f.write(beat_hex(q[j * ELEM_PER_BEAT:(j + 1) * ELEM_PER_BEAT]) + "\n")
    for name, M in (("nmp_k.hex", K), ("nmp_v.hex", V)):
        with open(os.path.join(args.out_dir, name), "w") as f:
            for t in range(S):
                for j in range(BLK_PER_ROW):
                    f.write(beat_hex(M[t, j * ELEM_PER_BEAT:(j + 1) * ELEM_PER_BEAT]) + "\n")
    with open(os.path.join(args.out_dir, "nmp_scores.hex"), "w") as f:
        for t in range(S):
            f.write(f"{s_bits[t]:08x}\n")
    with open(os.path.join(args.out_dir, "nmp_otilde.hex"), "w") as f:
        for i in range(D_HEAD):
            f.write(f"{ot_bits[i]:08x}\n")
    with open(os.path.join(args.out_dir, "nmp_lm.hex"), "w") as f:
        f.write(f"{l_bits:08x}\n{m_word:08x}\n")
    with open(os.path.join(args.out_dir, "nmp_ref.hex"), "w") as f:
        for i in range(D_HEAD):
            f.write(f"{o_bits[i]:08x}\n")

    o = [bits_fp32(b) for b in o_bits[:4]]
    print(f"S={S} seed={args.seed}  max score s'={m:.4f}  l={l:.4f}  saturated scores={n_sat}")
    print(f"o[0:4] = {o}")
    print(f"files written to {os.path.abspath(args.out_dir)}")


if __name__ == "__main__":
    main()
