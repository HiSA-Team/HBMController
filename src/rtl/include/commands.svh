`ifndef COMMANDS_SVH__
`define COMMANDS_SVH__


/* CAS commands */
localparam       P_COL_NOP		    = 4'b1111;
localparam       P_COL_RD		    = 4'b0101;
localparam       P_COL_RD_AP		= 4'b1101;
localparam       P_COL_WRT		    = 4'b0001;
localparam       P_COL_WRT_AP	    = 4'b1001;
localparam       P_COL_MRS		    = 4'b0000;

/* RAS commands */
localparam       P_ROW_NOP		    = 3'b111;
localparam       P_ROW_ACT		    = 3'b010;
localparam       P_ROW_PRE		    = 3'b011;    // WITH R[10] -> L
localparam       P_ROW_PREA		    = 3'b011;    // WITH R[10] -> H

localparam       P_ROW_REFPB         = 4'b1100;  // WITH R[4] on Falling -> H 
localparam       P_GENERAL_NOP       = 4'b1111;

localparam       LP_PAR              = 1'b1;     // Parity
localparam       LP_BA4_0            = 1'b0;      /* Pseudo Channel 0 */
localparam       LP_BA4_1            = 1'b1;      /* Pseudo Channel 1 */

// localparam       P_ROW_REFA         = 4'b1001;  // WITH R[4] on Falling -> H 

`endif  // COMMANDS_SVH__