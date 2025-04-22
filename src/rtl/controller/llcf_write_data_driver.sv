`timescale 1ps/1ps

`include "commands.svh"
`include "hbm_controller.svh"
`include "hbm_timing_constraints.svh"

module llcf_write_data_driver (
    // Clock and reset
    input logic                       clock_i,
    input logic                       reset_ni,

    // Input data from CAS arbiters
    input logic  [P_DATA_WIDTH-1 : 0] wrt_data_ps0_i,
    input logic  [P_DATA_WIDTH-1 : 0] wrt_data_ps1_i,
    input logic                       wrt_data_ps0_valid_i,
    input logic                       wrt_data_ps1_valid_i,

    // Output data direclty to the HBM PHY - on the two different phases
    output logic  [P_DATA_WIDTH-1 : 0] wrt_data_p0_o,
    output logic  [P_DATA_WIDTH-1 : 0] wrt_data_p1_o

);


/*******************************/
/*      WRDATA QUEUE PS0       */
/*******************************/
localparam INDEX_QUEUE_WIDTH = $clog2(P_WRT_DATA_BUFFER_LEN);

logic [P_DATA_WIDTH - 1    : 0 ]   wrt_data_buffer_ps0         [ 0 : P_WRT_DATA_BUFFER_LEN-1 ];                               
logic [INDEX_QUEUE_WIDTH-1 : 0 ]   wrt_data_buffer_head_ps0;
logic [INDEX_QUEUE_WIDTH-1 : 0 ]   wrt_data_buffer_tail_ps0; 
logic [INDEX_QUEUE_WIDTH-1 : 0 ]   wrt_data_buffer_tail_for_reset_ps0;
logic [INDEX_QUEUE_WIDTH-1 : 0 ]   wrt_data_buffer_tail_for_reset_ps1; 
logic [INDEX_QUEUE_WIDTH   : 0 ]   wrt_data_buffer_cnt_ps0; 

logic [2:0] wrt_to_data_cnt_ps0 [ 0 : P_WRT_DATA_BUFFER_LEN-1 ];


logic                              incr_wrt_data_buffer_cnt_ps0;
logic                              deincr_wrt_data_buffer_cnt_ps0;

logic                              rst_wrt_to_data_cnt_ps0;


assign     incr_wrt_data_buffer_cnt_ps0 = wrt_data_ps0_valid_i;
assign     deincr_wrt_data_buffer_cnt_ps0 = (wrt_data_buffer_cnt_ps0 > 0) && (wrt_to_data_cnt_ps0[wrt_data_buffer_tail_ps0] == tWL-2'h2);


/****************************************/
/* WRITE DATA BUFFER COUNTER MANAGEMENT */
/****************************************/
always @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        wrt_data_buffer_cnt_ps0  <= {INDEX_QUEUE_WIDTH+1{1'b0}};
    end 
    else begin
        if ( incr_wrt_data_buffer_cnt_ps0 && ~deincr_wrt_data_buffer_cnt_ps0 ) begin
            wrt_data_buffer_cnt_ps0 <= wrt_data_buffer_cnt_ps0 + 1'b1;
            
        end 
        else if ( ~incr_wrt_data_buffer_cnt_ps0 && deincr_wrt_data_buffer_cnt_ps0 ) begin
            wrt_data_buffer_cnt_ps0 <= wrt_data_buffer_cnt_ps0 - 1'b1;
        end
        else if ( incr_wrt_data_buffer_cnt_ps0 && deincr_wrt_data_buffer_cnt_ps0 ) begin
            wrt_data_buffer_cnt_ps0 <= wrt_data_buffer_cnt_ps0;
        end
    end 
end

assign rst_wrt_to_data_cnt_ps0 = wrt_data_ps0_valid_i /*&& wrt_data_buffer_cnt_ps0 < P_WRT_DATA_BUFFER_LEN*/;

genvar i;
generate
    for ( i=0; i<P_WRT_DATA_BUFFER_LEN; i=i+1 ) begin
        always @ ( posedge clock_i or negedge reset_ni ) begin
            if( reset_ni == 1'b0 ) begin
                wrt_to_data_cnt_ps0[i] <= {8{1'b0}};
            end
            else begin
                if (rst_wrt_to_data_cnt_ps0)  begin
                    if ( i == wrt_data_buffer_tail_for_reset_ps0 ) begin
                        wrt_to_data_cnt_ps0[i] <= {8{1'b0}};
                    end
                    else begin
                        wrt_to_data_cnt_ps0[i]  <= wrt_to_data_cnt_ps0[i] + 1'b1;
                    end
                end
                else begin
                    wrt_to_data_cnt_ps0[i]  <= wrt_to_data_cnt_ps0[i]  + 1'b1;
                end
            end
        end
    end
endgenerate


always @ ( posedge clock_i or negedge reset_ni ) begin
    if( reset_ni == 1'b0 ) begin
        wrt_data_buffer_tail_for_reset_ps0 <= { INDEX_QUEUE_WIDTH { 1'b0 } }; 
    end
    else begin
        if (rst_wrt_to_data_cnt_ps0)  begin
            wrt_data_buffer_tail_for_reset_ps0 <= wrt_data_buffer_tail_for_reset_ps0 + 1'b1;
        end
    end
end

/**************************/
/* FILL WRITE DATA BUFFER */
/**************************/
always @ ( posedge clock_i or negedge reset_ni ) begin
    if( reset_ni == 1'b0 ) begin
        for ( integer i = 0; i < P_WRT_DATA_BUFFER_LEN; i = i + 1 ) wrt_data_buffer_ps0[i] <= {P_DATA_WIDTH { 1'b1 } };
        wrt_data_buffer_head_ps0 <= {INDEX_QUEUE_WIDTH{1'b0}};
    end
    else begin
        if ( wrt_data_ps0_valid_i ) begin      
            if ( wrt_data_buffer_cnt_ps0 < P_WRT_DATA_BUFFER_LEN ) begin
                wrt_data_buffer_ps0[wrt_data_buffer_head_ps0] <= wrt_data_ps0_i;   
                wrt_data_buffer_head_ps0 <= wrt_data_buffer_head_ps0 + 1'b1;
            end
        end
    end
end


/*******************************/
/*      WRDATA QUEUE PS1       */
/*******************************/
logic [P_DATA_WIDTH - 1    : 0 ]   wrt_data_buffer_ps1         [ 0 : P_WRT_DATA_BUFFER_LEN-1 ];                               
logic [INDEX_QUEUE_WIDTH-1 : 0 ]   wrt_data_buffer_head_ps1;
logic [INDEX_QUEUE_WIDTH-1 : 0 ]   wrt_data_buffer_tail_ps1; 
logic [INDEX_QUEUE_WIDTH   : 0 ]   wrt_data_buffer_cnt_ps1; 

logic [2:0] wrt_to_data_cnt_ps1 [ 0 : P_WRT_DATA_BUFFER_LEN-1 ];


logic                              incr_wrt_data_buffer_cnt_ps1;
logic                              deincr_wrt_data_buffer_cnt_ps1;

logic                              rst_wrt_to_data_cnt_ps1;


assign     incr_wrt_data_buffer_cnt_ps1 = wrt_data_ps1_valid_i;
assign     deincr_wrt_data_buffer_cnt_ps1 = (wrt_data_buffer_cnt_ps1 > 0) && (wrt_to_data_cnt_ps1[wrt_data_buffer_tail_ps1] == tWL-2'h1);


/****************************************/
/* WRITE DATA BUFFER COUNTER MANAGEMENT */
/****************************************/
always @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        wrt_data_buffer_cnt_ps1  <= {INDEX_QUEUE_WIDTH+1{1'b0}};
    end 
    else begin
        if ( incr_wrt_data_buffer_cnt_ps1 && ~deincr_wrt_data_buffer_cnt_ps1 ) begin
            wrt_data_buffer_cnt_ps1 <= wrt_data_buffer_cnt_ps1 + 1'b1;
            
        end 
        else if ( ~incr_wrt_data_buffer_cnt_ps1 && deincr_wrt_data_buffer_cnt_ps1 ) begin
            wrt_data_buffer_cnt_ps1 <= wrt_data_buffer_cnt_ps1 - 1'b1;
        end
        else if ( incr_wrt_data_buffer_cnt_ps1 && deincr_wrt_data_buffer_cnt_ps1 ) begin
            wrt_data_buffer_cnt_ps1 <= wrt_data_buffer_cnt_ps1;
        end
    end 
end

assign rst_wrt_to_data_cnt_ps1 = wrt_data_ps1_valid_i /*&&  (wrt_data_buffer_cnt_ps1 < P_WRT_DATA_BUFFER_LEN)*/;

generate
    for ( i=0; i<P_WRT_DATA_BUFFER_LEN; i=i+1 ) begin
        always @ ( posedge clock_i or negedge reset_ni ) begin
            if( reset_ni == 1'b0 ) begin
                wrt_to_data_cnt_ps1[i] <= {8{1'b0}};
            end
            else begin
                if (rst_wrt_to_data_cnt_ps1)  begin
                    if ( i == wrt_data_buffer_tail_for_reset_ps1 ) begin
                        wrt_to_data_cnt_ps1[i] <= {8{1'b0}};
                    end
                    else begin
                        wrt_to_data_cnt_ps1[i]  <= wrt_to_data_cnt_ps1[i] + 1'b1;
                    end
                end
                else begin
                    wrt_to_data_cnt_ps1[i]  <= wrt_to_data_cnt_ps1[i]  + 1'b1;
                end
            end
        end
    end
endgenerate


always @ ( posedge clock_i or negedge reset_ni ) begin
    if( reset_ni == 1'b0 ) begin
        wrt_data_buffer_tail_for_reset_ps1 <= { INDEX_QUEUE_WIDTH { 1'b0 } }; 
    end
    else begin
        if (rst_wrt_to_data_cnt_ps1)  begin
            wrt_data_buffer_tail_for_reset_ps1 <= wrt_data_buffer_tail_for_reset_ps1 + 1'b1;
        end
    end
end


/**************************/
/* FILL WRITE DATA BUFFER */
/**************************/
always @ ( posedge clock_i or negedge reset_ni ) begin
    if( reset_ni == 1'b0 ) begin   
        for ( integer i = 0; i < P_WRT_DATA_BUFFER_LEN; i = i + 1 ) wrt_data_buffer_ps1[i] <= {P_DATA_WIDTH { 1'b1 } };     
        wrt_data_buffer_head_ps1 <= {INDEX_QUEUE_WIDTH{1'b0}};
    end
    
    else begin
        if ( wrt_data_ps1_valid_i ) begin      
            if ( wrt_data_buffer_cnt_ps1 < P_WRT_DATA_BUFFER_LEN ) begin
                wrt_data_buffer_ps1[wrt_data_buffer_head_ps1] <= wrt_data_ps1_i;   
                wrt_data_buffer_head_ps1 <= wrt_data_buffer_head_ps1 + 1'b1;    
            end 
        end
    end
end


/********************/
/* SEND DATA TO HBM */
/********************/
/* Here we send data for PS0 and for PS1 together on different phase P0 and P1 */
/* To understand better this component you have to consider the phases, and of course you can read the documentation ;) */
logic wrt_sync_ps0;
always @ ( posedge clock_i or negedge reset_ni ) begin
    if( reset_ni == 1'b0 ) begin
        wrt_data_p1_o            <= {P_DATA_WIDTH{1'b0}};
        wrt_data_p0_o            <= {P_DATA_WIDTH{1'b0}};
        wrt_data_buffer_tail_ps1 <= {INDEX_QUEUE_WIDTH{1'b0}};   
        wrt_data_buffer_tail_ps0 <= {INDEX_QUEUE_WIDTH{1'b0}}; 
        wrt_sync_ps0             <= 1'b0;
    end
    else begin
        /* Only PS0 has to be served (data) */
        if ( wrt_data_buffer_cnt_ps0 > 0 && wrt_to_data_cnt_ps0[wrt_data_buffer_tail_ps0] == tWL-2'h2 && wrt_to_data_cnt_ps1[wrt_data_buffer_tail_ps1] != tWL-2'h1  ) begin

            wrt_data_p0_o[63:0]     <= wrt_data_buffer_ps0[wrt_data_buffer_tail_ps0-1'b1][63:0];
            wrt_data_p0_o[191:128]  <= wrt_data_buffer_ps0[wrt_data_buffer_tail_ps0-1'b1][127:64];

            wrt_data_p1_o[63:0]     <= wrt_data_buffer_ps0[wrt_data_buffer_tail_ps0][191:128];
            wrt_data_p1_o[191:128]  <= wrt_data_buffer_ps0[wrt_data_buffer_tail_ps0][255:192];

            wrt_data_buffer_tail_ps0 <= wrt_data_buffer_tail_ps0 + 1'b1;
            wrt_sync_ps0 <= 1'b1;
        end
        /* PS0 and PS1 have to be served (data) */
        else if ( wrt_data_buffer_cnt_ps0 > 0 && wrt_data_buffer_cnt_ps1 > 0 && wrt_to_data_cnt_ps0[wrt_data_buffer_tail_ps0] == tWL-2'h2 && wrt_to_data_cnt_ps1[wrt_data_buffer_tail_ps1] == tWL-2'h1 ) begin
            wrt_data_p0_o[63:0]     <= wrt_data_buffer_ps0[wrt_data_buffer_tail_ps0-1'b1][63:0];
            wrt_data_p0_o[191:128]  <= wrt_data_buffer_ps0[wrt_data_buffer_tail_ps0-1'b1][127:64];

            wrt_data_p1_o[63:0]     <= wrt_data_buffer_ps0[wrt_data_buffer_tail_ps0][191:128];
            wrt_data_p1_o[191:128]  <= wrt_data_buffer_ps0[wrt_data_buffer_tail_ps0][255:192];

            wrt_data_buffer_tail_ps0 <= wrt_data_buffer_tail_ps0 + 1'b1;
            wrt_sync_ps0 <= 1'b1;

            wrt_data_p0_o[127:64]   <= wrt_data_buffer_ps1[wrt_data_buffer_tail_ps1][63:0];
            wrt_data_p0_o[255:192]  <= wrt_data_buffer_ps1[wrt_data_buffer_tail_ps1][127:64];

            wrt_data_p1_o[127:64]   <= wrt_data_buffer_ps1[wrt_data_buffer_tail_ps1][191:128];
            wrt_data_p1_o[255:192]  <= wrt_data_buffer_ps1[wrt_data_buffer_tail_ps1][255:192];

            wrt_data_buffer_tail_ps1 <= wrt_data_buffer_tail_ps1 + 1'b1;
        
        end
        /* Only PS1 has to be served, but we have residual data that have to be served for PS0 */
        else if ( wrt_data_buffer_cnt_ps1 > 0 && wrt_to_data_cnt_ps0[wrt_data_buffer_tail_ps0] != tWL-2'h2 && wrt_to_data_cnt_ps1[wrt_data_buffer_tail_ps1] == tWL-2'h1 && wrt_sync_ps0 ) begin
            wrt_data_p0_o[63:0]     <= wrt_data_buffer_ps0[wrt_data_buffer_tail_ps0-1'b1][63:0];
            wrt_data_p0_o[191:128]  <= wrt_data_buffer_ps0[wrt_data_buffer_tail_ps0-1'b1][127:64];
            wrt_sync_ps0 <= 1'b0;
            
            wrt_data_p0_o[127:64]   <= wrt_data_buffer_ps1[wrt_data_buffer_tail_ps1][63:0];
            wrt_data_p0_o[255:192]  <= wrt_data_buffer_ps1[wrt_data_buffer_tail_ps1][127:64];

            wrt_data_p1_o[127:64]   <= wrt_data_buffer_ps1[wrt_data_buffer_tail_ps1][191:128];
            wrt_data_p1_o[255:192]  <= wrt_data_buffer_ps1[wrt_data_buffer_tail_ps1][255:192];

            wrt_data_buffer_tail_ps1 <= wrt_data_buffer_tail_ps1 + 1'b1;
        end
        /* Only PS1 has to be served */
        else if ( wrt_data_buffer_cnt_ps1 > 0 && wrt_to_data_cnt_ps0[wrt_data_buffer_tail_ps0] != tWL-2'h2 && wrt_to_data_cnt_ps1[wrt_data_buffer_tail_ps1] == tWL-2'h1 && ~wrt_sync_ps0 ) begin                
            wrt_data_p0_o[127:64]   <= wrt_data_buffer_ps1[wrt_data_buffer_tail_ps1][63:0];
            wrt_data_p0_o[255:192]  <= wrt_data_buffer_ps1[wrt_data_buffer_tail_ps1][127:64];

            wrt_data_p1_o[127:64]   <= wrt_data_buffer_ps1[wrt_data_buffer_tail_ps1][191:128];
            wrt_data_p1_o[255:192]  <= wrt_data_buffer_ps1[wrt_data_buffer_tail_ps1][255:192];

            wrt_data_buffer_tail_ps1 <= wrt_data_buffer_tail_ps1 + 1'b1;
        end
        
        /* There are only data residuals for PS0 */
        else if ( wrt_sync_ps0 ) begin
            wrt_data_p0_o[63:0]     <= wrt_data_buffer_ps0[wrt_data_buffer_tail_ps0-1'b1][63:0];
            wrt_data_p0_o[191:128]  <= wrt_data_buffer_ps0[wrt_data_buffer_tail_ps0-1'b1][127:64];
            wrt_sync_ps0 <= 1'b0;
        end

        else begin
            wrt_data_p0_o   <= { P_DATA_WIDTH { 1'b1 } };
            wrt_data_p1_o   <= { P_DATA_WIDTH { 1'b1 } };
        end
    end
end


endmodule