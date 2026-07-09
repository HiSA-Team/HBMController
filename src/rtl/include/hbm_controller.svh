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
localparam       P_WRT_DATA_BUFFER_LEN      = 4;

/* REQUESTS       */
localparam       P_WRT_REQ                  = 2'd0;
localparam       P_RD_REQ                   = 2'd1;
localparam       P_REQ_WIDTH                = 32'd2;
`ifdef DEBUG
    localparam       P_REQ_ID_WIDTH             = 32'd24;
`endif

`ifndef DEBUG
    localparam       P_REQ_ID_WIDTH             = 32'd4; // TODO
`endif

localparam       P_CMD_ID_WIDTH             = 32'd3;

localparam       LP_BG_N                    = P_BA_N_PS/P_BA_N_G;

localparam       P_RD_ID_BUFFER_LEN         = 4; 

localparam LP_MRS			     = 4'd1;

`endif // HBM_CONTROLLER_SVH__
