`timescale 1ps / 1ps

module async_dual_port_fifo #(
    parameter DATA_WIDTH=256,
    parameter ADDR_WIDTH=32,
    parameter N_STAGE=3
)(
    input wr_en, 
    input rd_en,
    
    input wr_clk,
    input wr_rst,

    input rd_clk,
    input rd_rst,
    
    output full,    /* To stop writing */
    output empty,   /* To stop reading */ 

    input [(DATA_WIDTH-1):0] data_in,
    output [(DATA_WIDTH-1):0] data_out

);

localparam integer QUEUE_LEN = 2**ADDR_WIDTH;

(* rw_addr_collision = "no" *)(* ram_style = "block" *) reg [DATA_WIDTH-1:0] ram[0:QUEUE_LEN-1];


reg [ADDR_WIDTH-1 : 0]  head;         /* The address where write */
reg [ADDR_WIDTH-1 : 0]  tail;         /* The address where read  */

reg [ADDR_WIDTH   : 0]  wr_cnt;       /* Count the number of element in the queue (wr clk domain) */
reg [ADDR_WIDTH   : 0]  rd_cnt;       /* Count the number of element in the queue (rd clk domain) */

reg [N_STAGE-1    : 0]  wr_en_for_rd;
reg [N_STAGE-1    : 0]  rd_en_for_wr; 

reg [DATA_WIDTH-1 : 0]  r_data_out;   /* To drive the data_out signal */


assign data_out = r_data_out;
assign full     = wr_cnt == QUEUE_LEN;
assign empty    = rd_cnt == 0;

/* Clock domain crossing rd_en for wr_cnt */
always @( posedge wr_clk or negedge wr_rst ) begin
    if ( wr_rst == 1'b0 ) begin
        rd_en_for_wr <= { N_STAGE { 1'b0 } };
    end
    else begin
        rd_en_for_wr[0] <= rd_en;
        rd_en_for_wr[N_STAGE-1:1] <= rd_en_for_wr[N_STAGE-2:0]; 
    end
end

/* wr_cnt driver */
always @( posedge wr_clk or negedge wr_rst ) begin
    if ( wr_rst == 1'b0 ) begin
        wr_cnt <= { ADDR_WIDTH+1 { 1'b0 } };
    end
    else begin
        if ( wr_en && ~rd_en_for_wr[N_STAGE-1] ) begin
            wr_cnt <= wr_cnt + 1'b1;
        end
        else if ( ~wr_en && rd_en_for_wr[N_STAGE-1] ) begin
            wr_cnt <= wr_cnt - 1'b1;
        end 
        else if ( wr_en && rd_en_for_wr[N_STAGE-1] ) begin
            wr_cnt <= wr_cnt;
        end
        else begin
            wr_cnt <= wr_cnt;
        end
    end
end

/* Clock domain crossing wr_en for rd_cnt */
always @( posedge rd_clk or negedge rd_rst ) begin
    if ( rd_rst == 1'b0 ) begin
        wr_en_for_rd <= { N_STAGE { 1'b0 } };
    end
    else begin
        wr_en_for_rd[0] <= wr_en;
        wr_en_for_rd[N_STAGE-1:1] <= wr_en_for_rd[N_STAGE-2:0]; 
    end
end

/* rd_cnt driver */
always @( posedge rd_clk or negedge rd_rst ) begin
    if ( rd_rst == 1'b0 ) begin
        rd_cnt <= { ADDR_WIDTH+1 { 1'b0 } };
    end
    else begin
        if ( rd_en && ~wr_en_for_rd[N_STAGE-1] ) begin
            rd_cnt <= rd_cnt - 1'b1; 
        end
        else if ( ~rd_en &&  wr_en_for_rd[N_STAGE-1] ) begin
            rd_cnt <= rd_cnt + 1'b1;
        end
        else if ( rd_en && wr_en_for_rd[N_STAGE-1] ) begin
            rd_cnt <= rd_cnt;
        end
        else begin
            rd_cnt <= rd_cnt;
        end
    end
end

/* head driver */
always @( posedge wr_clk or negedge wr_rst ) begin : head_driver
    if ( wr_rst == 1'b0 ) begin
        head <= { ADDR_WIDTH { 1'b0 } };
    end
    else begin
        if ( wr_en ) begin
            if ( head == { ADDR_WIDTH { 1'b1 } } ) begin     /* For power of 2 addres width this is useless */
                head <= { ADDR_WIDTH { 1'b0 } };
            end
            else begin
                head <= head + 1'b1;
            end
        end
        else begin
            head <= head;
        end
    end
end

/* tail driver */
always @( posedge rd_clk or negedge rd_rst ) begin : tail_driver
    if ( rd_rst == 1'b0 ) begin
        tail <= { ADDR_WIDTH { 1'b0 } };
    end
    else begin
        if ( rd_en ) begin
            if ( tail == { ADDR_WIDTH { 1'b1 } } ) begin     /* For power of 2 addres width this is useless */
                tail <= { ADDR_WIDTH { 1'b0 } };
            end
            else begin
                tail <= tail + 1'b1;
            end
        end
        else begin
            tail <= tail;
        end
    end
end

always @ ( posedge wr_clk ) begin
    if ( wr_en ) begin
        ram[head] <= data_in;
    end
end

always @ ( posedge rd_clk or negedge rd_rst ) begin
    if ( rd_rst == 1'b0 ) begin
        r_data_out <= { DATA_WIDTH { 1'b0 } };
    end
    else begin
        if ( rd_en ) begin
            r_data_out <= ram[tail];
        end
    end
end

endmodule