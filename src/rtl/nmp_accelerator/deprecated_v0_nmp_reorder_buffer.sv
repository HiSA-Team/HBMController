`timescale 1ps/1ps

`include "hbm_controller.svh"
`include "nmp_accelerator.svh"

/******************************************************************************/
/* NMP REORDER BUFFER                                                         */
/*                                                                            */
/* The channel returns read data in the order in which the CAS commands were  */
/* issued, which is not the order in which the requests were accepted (a row  */
/* hit can overtake a row miss, and the two PS are independent). The address  */
/* generator gives consecutive ids to consecutive blocks, so the position of  */
/* a returned beat inside the current pass is  offset = req_id - base_id.     */
/* Beats are stored at slot offset % P_NMP_ROB_DEPTH and popped in order.     */
/*                                                                            */
/* Even offsets come from PS0 and odd offsets from PS1 (the region base is    */
/* even), so the buffer is split in two halves with one write port each.      */
/* The address generator guarantees offset - popped < P_NMP_ROB_DEPTH, hence  */
/* a slot is always free when it is written.                                  */
/******************************************************************************/

module nmp_reorder_buffer (
    input  logic                              clock_i,
    input  logic                              reset_ni,

    /* Start of a pass: id of its first request and number of blocks, head goes back to 0 */
    input  logic                              set_base_i,
    input  logic [P_REQ_ID_WIDTH-1:0]         base_req_id_i,
    input  logic [P_NMP_BLK_ADDR_WIDTH-1:0]   n_blk_i,

    /* Read data from HBM_channel_controller */
    input  logic                              rd_data_valid_ps0_i,
    input  logic [P_REQ_ID_WIDTH-1:0]         rd_data_req_id_ps0_i,
    input  logic [P_DATA_WIDTH-1:0]           rd_data_ps0_i,
    input  logic                              rd_data_valid_ps1_i,
    input  logic [P_REQ_ID_WIDTH-1:0]         rd_data_req_id_ps1_i,
    input  logic [P_DATA_WIDTH-1:0]           rd_data_ps1_i,

    /* In-order output */
    output logic                              beat_valid_o,     /* head beat available                   */
    output logic [P_DATA_WIDTH-1:0]           beat_data_o,
    output logic [P_NMP_BLK_ADDR_WIDTH-1:0]   beat_offset_o,    /* position of the head beat in the pass */
    input  logic                              pop_i,            /* consumer takes the head beat          */
    output logic                              credit_return_o,  /* = beat_valid_o & pop_i                */

    /* Statistics */
    output logic [31:0]                       head_wait_cnt_o   /* cycles with pop_i high and no head beat */
);

localparam HALF_ADDR_WIDTH = P_NMP_ROB_ADDR_WIDTH - 1;

/* Base id and pop side */
logic [P_REQ_ID_WIDTH-1:0]         r_base_req_id;
logic [P_NMP_BLK_ADDR_WIDTH-1:0]   r_n_blk;          /* beats expected in this pass          */
logic [P_NMP_ROB_ADDR_WIDTH-1:0]   r_head;           /* slot of the next beat to pop          */
logic [P_NMP_BLK_ADDR_WIDTH-1:0]   r_popped;         /* beats popped in this pass             */
logic [P_NMP_ROB_DEPTH-1:0]        r_slot_valid;

/* Write side: offset of the returned beats */
logic [P_REQ_ID_WIDTH-1:0]         offset_ps0;
logic [P_REQ_ID_WIDTH-1:0]         offset_ps1;
logic [HALF_ADDR_WIDTH-1:0]        wr_slot_ps0;
logic [HALF_ADDR_WIDTH-1:0]        wr_slot_ps1;

assign offset_ps0  = rd_data_req_id_ps0_i - r_base_req_id;
assign offset_ps1  = rd_data_req_id_ps1_i - r_base_req_id;
assign wr_slot_ps0 = offset_ps0[HALF_ADDR_WIDTH:1];
assign wr_slot_ps1 = offset_ps1[HALF_ADDR_WIDTH:1];

/* A beat is accepted only if it belongs to the pass: offset inside [0, n_blk)
   and on the PS its parity says. Anything else (a return of a previous job,
   a wrong id) is dropped and reported in DEBUG. */
logic in_window_ps0;
logic in_window_ps1;
logic wr_en_ps0;
logic wr_en_ps1;
assign in_window_ps0 = ( offset_ps0[P_NMP_BLK_ADDR_WIDTH-1:0] < r_n_blk ) && ( offset_ps0[0] == 1'b0 );
assign in_window_ps1 = ( offset_ps1[P_NMP_BLK_ADDR_WIDTH-1:0] < r_n_blk ) && ( offset_ps1[0] == 1'b1 );
assign wr_en_ps0     = rd_data_valid_ps0_i & in_window_ps0 & ~set_base_i;
assign wr_en_ps1     = rd_data_valid_ps1_i & in_window_ps1 & ~set_base_i;

/* Storage: half 0 = even offsets (PS0), half 1 = odd offsets (PS1) */
logic [P_DATA_WIDTH-1:0]           data_out_ps0;
logic [P_DATA_WIDTH-1:0]           data_out_ps1;

distributed_ram #(
    .DATA_WIDTH(P_DATA_WIDTH),
    .ADDR_WIDTH(HALF_ADDR_WIDTH)
)
rob_half_ps0 (
    .data_in(rd_data_ps0_i),
    .read_addr(r_head[P_NMP_ROB_ADDR_WIDTH-1:1]),
    .write_addr(wr_slot_ps0),
    .wr_en(wr_en_ps0),
    .clk(clock_i),
    .data_out(data_out_ps0)
);

distributed_ram #(
    .DATA_WIDTH(P_DATA_WIDTH),
    .ADDR_WIDTH(HALF_ADDR_WIDTH)
)
rob_half_ps1 (
    .data_in(rd_data_ps1_i),
    .read_addr(r_head[P_NMP_ROB_ADDR_WIDTH-1:1]),
    .write_addr(wr_slot_ps1),
    .wr_en(wr_en_ps1),
    .clk(clock_i),
    .data_out(data_out_ps1)
);

/* Head beat */
logic pop;
assign beat_valid_o    = r_slot_valid[r_head];
assign beat_data_o     = (r_head[0] == 1'b0) ? data_out_ps0 : data_out_ps1;
assign beat_offset_o   = r_popped;
assign pop             = beat_valid_o & pop_i;
assign credit_return_o = pop;

/****************************/
/* SLOT VALID BITS AND HEAD */
/****************************/
always @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        r_base_req_id <= { P_REQ_ID_WIDTH { 1'b0 } };
        r_n_blk       <= { P_NMP_BLK_ADDR_WIDTH { 1'b0 } };
        r_head        <= { P_NMP_ROB_ADDR_WIDTH { 1'b0 } };
        r_popped      <= { P_NMP_BLK_ADDR_WIDTH { 1'b0 } };
        r_slot_valid  <= { P_NMP_ROB_DEPTH { 1'b0 } };
    end
    else begin
        if ( set_base_i ) begin
            r_base_req_id <= base_req_id_i;
            r_n_blk       <= n_blk_i;
            r_head        <= { P_NMP_ROB_ADDR_WIDTH { 1'b0 } };
            r_popped      <= { P_NMP_BLK_ADDR_WIDTH { 1'b0 } };
            r_slot_valid  <= { P_NMP_ROB_DEPTH { 1'b0 } };
        end
        else begin
            /* A written slot is never the head slot (the head is valid, a
               written slot is not), so set and clear never collide */
            if ( wr_en_ps0 ) begin
                r_slot_valid[{wr_slot_ps0, 1'b0}] <= 1'b1;
            end
            if ( wr_en_ps1 ) begin
                r_slot_valid[{wr_slot_ps1, 1'b1}] <= 1'b1;
            end
            if ( pop ) begin
                r_slot_valid[r_head] <= 1'b0;
                r_head               <= r_head + 1'b1;
                r_popped             <= r_popped + 1'b1;
            end
        end
    end
end

/**************/
/* STATISTICS */
/**************/
always @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        head_wait_cnt_o <= 32'd0;
    end
    else begin
        if ( set_base_i ) begin
            head_wait_cnt_o <= 32'd0;
        end
        else if ( pop_i && ~beat_valid_o ) begin
            head_wait_cnt_o <= head_wait_cnt_o + 1'b1;
        end
    end
end

`ifdef DEBUG
/* Sanity: every returned beat must belong to the open pass (offset < n_blk),
   on the PS its parity says, and must not overwrite a valid slot */
always @ ( posedge clock_i ) begin
    if ( reset_ni == 1'b1 ) begin
        if ( rd_data_valid_ps0_i && ~in_window_ps0 ) begin
            $display("[ NMP ROB ]: DROPPED PS0 id %0d (offset %0d, window %0d, base %0d) at %0t", rd_data_req_id_ps0_i, offset_ps0, r_n_blk, r_base_req_id, $time);
        end
        if ( rd_data_valid_ps1_i && ~in_window_ps1 ) begin
            $display("[ NMP ROB ]: DROPPED PS1 id %0d (offset %0d, window %0d, base %0d) at %0t", rd_data_req_id_ps1_i, offset_ps1, r_n_blk, r_base_req_id, $time);
        end
        if ( wr_en_ps0 && r_slot_valid[{wr_slot_ps0, 1'b0}] ) begin
            $display("[ NMP ROB ]: ERROR PS0 overwrote a valid slot (offset %0d) at %0t", offset_ps0, $time);
        end
        if ( wr_en_ps1 && r_slot_valid[{wr_slot_ps1, 1'b1}] ) begin
            $display("[ NMP ROB ]: ERROR PS1 overwrote a valid slot (offset %0d) at %0t", offset_ps1, $time);
        end
    end
end
`endif

endmodule
