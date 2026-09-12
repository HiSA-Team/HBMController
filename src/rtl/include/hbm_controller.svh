`ifndef HBM_CONTROLLER_SVH__
`define HBM_CONTROLLER_SVH__

localparam		 P_ROW_ADDR_WIDTH           = 14;
localparam		 P_COL_ADDR_WIDTH           = 6;
localparam		 P_BA_ADDR_WIDTH	        = 5;
localparam       P_BA_N_PS                  = 16;        /* Number of Banks per PS; here we consider half bank for PS */
localparam       P_BA_N_G                   = 4;         /* Number of Banks per group */
localparam       P_DATA_WIDTH               = 256;
localparam       P_TOTAL_PER_CHANNEL_BANK_N = 32;        /* Number of Banks per channel; again we consider half bank */

/* FIFO QUEUE LEN */
localparam       P_QUEUE_LEN                = 4;

/* MAPPING ADDRESS POLICY */
localparam       P_MAPPING_POLICY           = 1;

/* WRT BUFFER LEN */
localparam       P_WRT_DATA_BUFFER_LEN      = 8;    // was 4: llcf_write_data_driver holds a PS1 entry for tWL-1 = 3 cycles after its CAS, so 4 entries
                                                       // are in flight with back-to-back write CAS and the 5th is dropped (head does not advance) while the
                                                       // timer-reset pointer does -> permanent data/CAS desync on PS1. Depth must exceed tWL (2026-09-07)

/* REQUESTS       */
localparam       P_WRT_REQ                  = 2'd0;
localparam       P_RD_REQ                   = 2'd1;
localparam       P_REQ_WIDTH                = 32'd2;

/* Request id: a tag the controller carries from the request to the matching
   read return, untouched. It used to be 4 bits (one per AXI channel) without
   DEBUG and 24 with it, which made the two builds two different designs. It is
   one width now, for every build, and the near-memory accelerator sets it.

   The accelerator places a returning beat by the distance between its id and
   the id that opened the pass, and accepts the beat only while that distance
   is below the length of the pass. Two different bounds come out of that:

     14 bits  every block of ONE pass gets a distinct id:
              8 * 2048 = 16384 = 2^14. Below this, ids repeat inside a single
              pass and beats are placed on the wrong token. Hard floor.

     15 bits  the ids of one pass and of the pass before it are distinct too.
              With 14, the V pass reuses exactly the residues the K pass used,
              so a late K return arriving during V would be accepted as a V
              beat. Today that cannot happen, because the engine drains its
              pipeline and drops r_pass_open before switching pass - but that
              is an invariant of the FSM, not a property of the numbering, and
              a front end that overlaps the passes would break it silently.

   15 is what we use: one bit to stop depending on that invariant. Verified
   both ways in Verilator at S=2048 (14 passes today, 13 fails). See
   doc/nmp/CHANGELOG.md.                                                      */
localparam       P_REQ_ID_WIDTH             = 32'd15;

localparam       P_REQ_ID_CAS_RAM_WIDTH     = 32'd7;

localparam       P_CMD_ID_WIDTH             = 32'd3;

localparam       LP_BG_N                    = P_BA_N_PS/P_BA_N_G;

localparam       P_RD_ID_BUFFER_LEN         = 64;   // was 4: RD id FIFO has no backpressure, must cover reads in flight per PS (2026-09-06)

localparam LP_MRS			     = 4'd1;

`endif // HBM_CONTROLLER_SVH__
