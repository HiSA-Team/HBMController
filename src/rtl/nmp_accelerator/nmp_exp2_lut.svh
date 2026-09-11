`ifndef NMP_EXP2_LUT_SVH__
`define NMP_EXP2_LUT_SVH__

/******************************************************************************/
/* 2^f LOOKUP TABLES - GENERATED FILE, DO NOT EDIT BY HAND                    */
/* Produced by utils/nmp_gen_exp2_lut.py                                      */
/*                                                                            */
/* f in [0, 1) carried on 16 bits: i = f[15:8] indexes the table,             */
/* r = f[7:0] interpolates linearly between VAL[i] and VAL[i+1]:              */
/*                                                                            */
/*     y = VAL[i] + (DLT[i] * r) >> 8        is 2^f in Q1.31                  */
/*                                                                            */
/* VAL[i] = round(2^(i/256) * 2^31), so VAL[0] = 2^31 is exactly 1.0          */
/* DLT[i] = VAL[i+1] - VAL[i], with VAL[256] = 2^32 = 2.0                     */
/*                                                                            */
/* Worst case relative error over all 2^16 values of f: 9.166e-07             */
/* Largest interpolated value: 4294921931 < 2^32, it fits in 32 bits          */
/*                                                                            */
/* Entry i lives at [i*W +: W] of the packed vectors below.                   */
/******************************************************************************/

localparam int P_NMP_EXP2_IDX_W = 8;
localparam int P_NMP_EXP2_REM_W = 8;
localparam int P_NMP_EXP2_LEN   = 256;
localparam int P_NMP_EXP2_VAL_W = 32;
localparam int P_NMP_EXP2_DLT_W = 24;
localparam int P_NMP_EXP2_FRAC  = 31;

localparam logic [P_NMP_EXP2_LEN*P_NMP_EXP2_VAL_W-1:0] P_NMP_EXP2_VAL = {
    32'hff4ecb59, 32'hfe9e115c, 32'hfdedd1b5, 32'hfd3e0c0d, 32'hfc8ec011, 32'hfbdfed6d,   /* 255 .. 250 */
    32'hfb3193cc, 32'hfa83b2db, 32'hf9d64a47, 32'hf92959bb, 32'hf87ce0e6, 32'hf7d0df73,   /* 249 .. 244 */
    32'hf7255511, 32'hf67a416c, 32'hf5cfa434, 32'hf5257d15, 32'hf47bcbbe, 32'hf3d28fde,   /* 243 .. 238 */
    32'hf329c923, 32'hf281773c, 32'hf1d999d9, 32'hf13230a8, 32'hf08b3b59, 32'hefe4b99c,   /* 237 .. 232 */
    32'hef3eab21, 32'hee990f98, 32'hedf3e6b2, 32'hed4f301f, 32'hecaaeb90, 32'hec0718b6,   /* 231 .. 226 */
    32'heb63b743, 32'heac0c6e8, 32'hea1e4756, 32'he97c3840, 32'he8da9958, 32'he8396a50,   /* 225 .. 220 */
    32'he798aadb, 32'he6f85aab, 32'he6587973, 32'he5b906e7, 32'he51a02bb, 32'he47b6ca0,   /* 219 .. 214 */
    32'he3dd444c, 32'he33f8973, 32'he2a23bc8, 32'he2055b00, 32'he168e6d0, 32'he0ccdeec,   /* 213 .. 208 */
    32'he031430a, 32'hdf9612df, 32'hdefb4e20, 32'hde60f482, 32'hddc705bd, 32'hdd2d8185,   /* 207 .. 202 */
    32'hdc946791, 32'hdbfbb798, 32'hdb637150, 32'hdacb946f, 32'hda3420ae, 32'hd99d15c2,   /* 201 .. 196 */
    32'hd9067365, 32'hd870394c, 32'hd7da6731, 32'hd744fccb, 32'hd6aff9d2, 32'hd61b5dff,   /* 195 .. 190 */
    32'hd587290a, 32'hd4f35aac, 32'hd45ff29e, 32'hd3ccf09a, 32'hd33a5458, 32'hd2a81d92,   /* 189 .. 184 */
    32'hd2164c02, 32'hd184df62, 32'hd0f3d76c, 32'hd06333db, 32'hcfd2f468, 32'hcf4318cf,   /* 183 .. 178 */
    32'hceb3a0ca, 32'hce248c15, 32'hcd95da6b, 32'hcd078b86, 32'hcc799f24, 32'hcbec14ff,   /* 177 .. 172 */
    32'hcb5eecd4, 32'hcad2265e, 32'hca45c15b, 32'hc9b9bd86, 32'hc92e1a9d, 32'hc8a2d85d,   /* 171 .. 166 */
    32'hc817f681, 32'hc78d74c9, 32'hc70352f0, 32'hc67990b6, 32'hc5f02dd7, 32'hc5672a11,   /* 165 .. 160 */
    32'hc4de8524, 32'hc4563ecc, 32'hc3ce56ca, 32'hc346ccda, 32'hc2bfa0bd, 32'hc238d231,   /* 159 .. 154 */
    32'hc1b260f6, 32'hc12c4cca, 32'hc0a6956f, 32'hc0213aa2, 32'hbf9c3c25, 32'hbf1799b6,   /* 153 .. 148 */
    32'hbe935318, 32'hbe0f680a, 32'hbd8bd84c, 32'hbd08a39f, 32'hbc85c9c5, 32'hbc034a7f,   /* 147 .. 142 */
    32'hbb81258d, 32'hbaff5ab2, 32'hba7de9af, 32'hb9fcd245, 32'hb97c1437, 32'hb8fbaf47,   /* 141 .. 136 */
    32'hb87ba338, 32'hb7fbefcb, 32'hb77c94c3, 32'hb6fd91e3, 32'hb67ee6ef, 32'hb60093a8,   /* 135 .. 130 */
    32'hb58297d4, 32'hb504f334, 32'hb487a58d, 32'hb40aaea2, 32'hb38e0e38, 32'hb311c413,   /* 129 .. 124 */
    32'hb295cff6, 32'hb21a31a6, 32'hb19ee8e9, 32'hb123f582, 32'hb0a95736, 32'hb02f0dcc,   /* 123 .. 118 */
    32'hafb51907, 32'haf3b78ad, 32'haec22c85, 32'hae493453, 32'hadd08fdd, 32'had583eea,   /* 117 .. 112 */
    32'hace04140, 32'hac6896a5, 32'habf13edf, 32'hab7a39b6, 32'hab0386ef, 32'haa8d2653,   /* 111 .. 106 */
    32'haa1717a8, 32'ha9a15ab5, 32'ha92bef42, 32'ha8b6d516, 32'ha8420bfa, 32'ha7cd93b5,   /* 105 .. 100 */
    32'ha7596c0f, 32'ha6e594d0, 32'ha6720dc1, 32'ha5fed6aa, 32'ha58bef53, 32'ha5195787,   /* 99 .. 94 */
    32'ha4a70f0d, 32'ha43515ae, 32'ha3c36b34, 32'ha3520f69, 32'ha2e10215, 32'ha2704303,   /* 93 .. 88 */
    32'ha1ffd1fc, 32'ha18faecb, 32'ha11fd938, 32'ha0b05110, 32'ha041161b, 32'h9fd22825,   /* 87 .. 82 */
    32'h9f6386f9, 32'h9ef53261, 32'h9e872a27, 32'h9e196e19, 32'h9dabfdff, 32'h9d3ed9a7,   /* 81 .. 76 */
    32'h9cd200dc, 32'h9c657368, 32'h9bf93119, 32'h9b8d39ba, 32'h9b218d17, 32'h9ab62afd,   /* 75 .. 70 */
    32'h9a4b1337, 32'h99e04593, 32'h9975c1dd, 32'h990b87e2, 32'h98a1976f, 32'h9837f052,   /* 69 .. 64 */
    32'h97ce9256, 32'h97657d4a, 32'h96fcb0fb, 32'h96942d37, 32'h962bf1cc, 32'h95c3fe87,   /* 63 .. 58 */
    32'h955c5337, 32'h94f4efa9, 32'h948dd3ad, 32'h9426ff10, 32'h93c071a1, 32'h935a2b2f,   /* 57 .. 52 */
    32'h92f42b89, 32'h928e727e, 32'h9228ffdc, 32'h91c3d374, 32'h915eed14, 32'h90fa4c8c,   /* 51 .. 46 */
    32'h9095f1ac, 32'h9031dc43, 32'h8fce0c22, 32'h8f6a8118, 32'h8f073af6, 32'h8ea4398b,   /* 45 .. 40 */
    32'h8e417ca9, 32'h8ddf0420, 32'h8d7ccfc1, 32'h8d1adf5b, 32'h8cb932c2, 32'h8c57c9c4,   /* 39 .. 34 */
    32'h8bf6a435, 32'h8b95c1e4, 32'h8b3522a4, 32'h8ad4c645, 32'h8a74ac9a, 32'h8a14d575,   /* 33 .. 28 */
    32'h89b540a8, 32'h8955ee03, 32'h88f6dd5b, 32'h88980e81, 32'h88398147, 32'h87db3580,   /* 27 .. 22 */
    32'h877d2aff, 32'h871f6197, 32'h86c1d91a, 32'h8664915c, 32'h86078a2f, 32'h85aac368,   /* 21 .. 16 */
    32'h854e3cd9, 32'h84f1f656, 32'h8495efb3, 32'h843a28c4, 32'h83dea15c, 32'h8383594f,   /* 15 .. 10 */
    32'h83285072, 32'h82cd8699, 32'h8272fb98, 32'h8218af43, 32'h81bea171, 32'h8164d1f4,   /* 9 .. 4 */
    32'h810b40a2, 32'h80b1ed50, 32'h8058d7d3, 32'h80000000    /* 3 .. 0 */
};

localparam logic [P_NMP_EXP2_LEN*P_NMP_EXP2_DLT_W-1:0] P_NMP_EXP2_DLT = {
    24'hb134a7, 24'hb0b9fd, 24'hb03fa7, 24'hafc5a8, 24'haf4bfc, 24'haed2a4,   /* 255 .. 250 */
    24'hae59a1, 24'hade0f1, 24'had6894, 24'hacf08c, 24'hac78d5, 24'hac0173,   /* 249 .. 244 */
    24'hab8a62, 24'hab13a5, 24'haa9d38, 24'haa271f, 24'ha9b157, 24'ha93be0,   /* 243 .. 238 */
    24'ha8c6bb, 24'ha851e7, 24'ha7dd63, 24'ha76931, 24'ha6f54f, 24'ha681bd,   /* 237 .. 232 */
    24'ha60e7b, 24'ha59b89, 24'ha528e6, 24'ha4b693, 24'ha4448f, 24'ha3d2da,   /* 231 .. 226 */
    24'ha36173, 24'ha2f05b, 24'ha27f92, 24'ha20f16, 24'ha19ee8, 24'ha12f08,   /* 225 .. 220 */
    24'ha0bf75, 24'ha05030, 24'h9fe138, 24'h9f728c, 24'h9f042c, 24'h9e961b,   /* 219 .. 214 */
    24'h9e2854, 24'h9dbad9, 24'h9d4dab, 24'h9ce0c8, 24'h9c7430, 24'h9c07e4,   /* 213 .. 208 */
    24'h9b9be2, 24'h9b302b, 24'h9ac4bf, 24'h9a599e, 24'h99eec5, 24'h998438,   /* 207 .. 202 */
    24'h9919f4, 24'h98aff9, 24'h984648, 24'h97dce1, 24'h9773c1, 24'h970aec,   /* 201 .. 196 */
    24'h96a25d, 24'h963a19, 24'h95d21b, 24'h956a66, 24'h9502f9, 24'h949bd3,   /* 195 .. 190 */
    24'h9434f5, 24'h93ce5e, 24'h93680e, 24'h930204, 24'h929c42, 24'h9236c6,   /* 189 .. 184 */
    24'h91d190, 24'h916ca0, 24'h9107f6, 24'h90a391, 24'h903f73, 24'h8fdb99,   /* 183 .. 178 */
    24'h8f7805, 24'h8f14b5, 24'h8eb1aa, 24'h8e4ee5, 24'h8dec62, 24'h8d8a25,   /* 177 .. 172 */
    24'h8d282b, 24'h8cc676, 24'h8c6503, 24'h8c03d5, 24'h8ba2e9, 24'h8b4240,   /* 171 .. 166 */
    24'h8ae1dc, 24'h8a81b8, 24'h8a21d9, 24'h89c23a, 24'h8962df, 24'h8903c6,   /* 165 .. 160 */
    24'h88a4ed, 24'h884658, 24'h87e802, 24'h8789f0, 24'h872c1d, 24'h86ce8c,   /* 159 .. 154 */
    24'h86713b, 24'h86142c, 24'h85b75b, 24'h855acd, 24'h84fe7d, 24'h84a26f,   /* 153 .. 148 */
    24'h84469e, 24'h83eb0e, 24'h838fbe, 24'h8334ad, 24'h82d9da, 24'h827f46,   /* 147 .. 142 */
    24'h8224f2, 24'h81cadb, 24'h817103, 24'h81176a, 24'h80be0e, 24'h8064f0,   /* 141 .. 136 */
    24'h800c0f, 24'h7fb36d, 24'h7f5b08, 24'h7f02e0, 24'h7eaaf4, 24'h7e5347,   /* 135 .. 130 */
    24'h7dfbd4, 24'h7da4a0, 24'h7d4da7, 24'h7cf6eb, 24'h7ca06a, 24'h7c4a25,   /* 129 .. 124 */
    24'h7bf41d, 24'h7b9e50, 24'h7b48bd, 24'h7af367, 24'h7a9e4c, 24'h7a496a,   /* 123 .. 118 */
    24'h79f4c5, 24'h79a05a, 24'h794c28, 24'h78f832, 24'h78a476, 24'h7850f3,   /* 117 .. 112 */
    24'h77fdaa, 24'h77aa9b, 24'h7757c6, 24'h770529, 24'h76b2c7, 24'h76609c,   /* 111 .. 106 */
    24'h760eab, 24'h75bcf3, 24'h756b73, 24'h751a2c, 24'h74c91c, 24'h747845,   /* 105 .. 100 */
    24'h7427a6, 24'h73d73f, 24'h73870f, 24'h733717, 24'h72e757, 24'h7297cc,   /* 99 .. 94 */
    24'h72487a, 24'h71f95f, 24'h71aa7a, 24'h715bcb, 24'h710d54, 24'h70bf12,   /* 93 .. 88 */
    24'h707107, 24'h702331, 24'h6fd593, 24'h6f8828, 24'h6f3af5, 24'h6eedf6,   /* 87 .. 82 */
    24'h6ea12c, 24'h6e5498, 24'h6e083a, 24'h6dbc0e, 24'h6d701a, 24'h6d2458,   /* 81 .. 76 */
    24'h6cd8cb, 24'h6c8d74, 24'h6c424f, 24'h6bf75f, 24'h6baca3, 24'h6b621a,   /* 75 .. 70 */
    24'h6b17c6, 24'h6acda4, 24'h6a83b6, 24'h6a39fb, 24'h69f073, 24'h69a71d,   /* 69 .. 64 */
    24'h695dfc, 24'h69150c, 24'h68cc4f, 24'h6883c4, 24'h683b6b, 24'h67f345,   /* 63 .. 58 */
    24'h67ab50, 24'h67638e, 24'h671bfc, 24'h66d49d, 24'h668d6f, 24'h664672,   /* 57 .. 52 */
    24'h65ffa6, 24'h65b90b, 24'h6572a2, 24'h652c68, 24'h64e660, 24'h64a088,   /* 51 .. 46 */
    24'h645ae0, 24'h641569, 24'h63d021, 24'h638b0a, 24'h634622, 24'h63016b,   /* 45 .. 40 */
    24'h62bce2, 24'h627889, 24'h62345f, 24'h61f066, 24'h61ac99, 24'h6168fe,   /* 39 .. 34 */
    24'h61258f, 24'h60e251, 24'h609f40, 24'h605c5f, 24'h6019ab, 24'h5fd725,   /* 33 .. 28 */
    24'h5f94cd, 24'h5f52a5, 24'h5f10a8, 24'h5eceda, 24'h5e8d3a, 24'h5e4bc7,   /* 27 .. 22 */
    24'h5e0a81, 24'h5dc968, 24'h5d887d, 24'h5d47be, 24'h5d072d, 24'h5cc6c7,   /* 21 .. 16 */
    24'h5c868f, 24'h5c4683, 24'h5c06a3, 24'h5bc6ef, 24'h5b8768, 24'h5b480d,   /* 15 .. 10 */
    24'h5b08dd, 24'h5ac9d9, 24'h5a8b01, 24'h5a4c55, 24'h5a0dd2, 24'h59cf7d,   /* 9 .. 4 */
    24'h599152, 24'h595352, 24'h59157d, 24'h58d7d3    /* 3 .. 0 */
};

`endif // NMP_EXP2_LUT_SVH__
