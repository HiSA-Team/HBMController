`timescale 1ps/1ps


module ll_command_forwarder_sim_top_queue (
    
);

localparam P_BA_ADDR_WIDTH = 5;
localparam P_ROW_ADDR_WIDTH = 16;
localparam P_COL_ADDR_WIDTH = 12;
localparam P_DATA_WIDTH     = 256;


localparam LP_ROW_PRE		= 3'b011;
localparam LP_ROW_ACT		= 3'b010;
localparam LP_COL_WRT		= 4'b0001;
localparam LP_COL_RD        = 4'b0101;

localparam LP_GENERAL_NOP   = 4'b1111;



reg HBM_REF_CLK_0;
reg HBM_REF_CLK_0_5;
reg ARESET_N_0;
reg APB_PCLK;
reg APB_PRESET_N;

wire                              ready_to_cmd_m;
reg   [3:0]                       cmd_m;
reg   [P_BA_ADDR_WIDTH-1:0]       bank_address_m;
reg   [P_ROW_ADDR_WIDTH-1:0]      row_address_m;
reg   [P_COL_ADDR_WIDTH-1:0]      column_address_m;
reg   [(P_DATA_WIDTH*2)-1:0]      data_m;


////////////////////////////////////////////////////////////////////////////////
// Generating 100MHz REF clock
////////////////////////////////////////////////////////////////////////////////
initial HBM_REF_CLK_0 = 1'b0;
always HBM_REF_CLK_0 = #5000.00 ~HBM_REF_CLK_0;

/* Clock 5 volte più veloce di HBM_REF_CLK_0 */
initial HBM_REF_CLK_0_5 = 1'b0;
always HBM_REF_CLK_0_5 = #5000.00 ~HBM_REF_CLK_0_5;


////////////////////////////////////////////////////////////////////////////////
// Generating 100MHz APB clock and Reset
////////////////////////////////////////////////////////////////////////////////
initial APB_PCLK = 1'b0;
always APB_PCLK = #(10000/2.0) ~APB_PCLK;

initial begin
    APB_PRESET_N = 1'b0;
    #200ns;
    APB_PRESET_N = 1'b0;
    #4500ns;
    APB_PRESET_N = 1'b1;
end


initial begin
    ARESET_N_0 = 1'b0;
    #200ns;
    ARESET_N_0 = 1'b0;
    #4500ns;
    ARESET_N_0 = 1'b1;
end


localparam  M = 4;
localparam  N = 4;



/* Coda per mantenere i comandi, sono 16 comandi (ogni comando è a 4 bit) */

localparam QUEUE_LEN = 16;
reg [3:0] cmd_queue [0 : QUEUE_LEN - 1];
reg [P_BA_ADDR_WIDTH-1:0]  bank_addr_queue [0 : QUEUE_LEN - 1];
reg [P_ROW_ADDR_WIDTH-1:0] row_addr_queue  [0 : QUEUE_LEN - 1];
reg [P_COL_ADDR_WIDTH-1:0] col_addr_queue  [0 : QUEUE_LEN - 1];
reg [(P_DATA_WIDTH*2)-1 : 0]   wrt_data_queue  [0 : QUEUE_LEN - 1];


reg [3:0] tail;
reg [3:0] head;
reg [4:0] cmd_cnt;

reg incr_cmd_cnt;
reg deincr_cmd_cnt;

reg [15:0] dummy_cnt; 


always @( negedge HBM_REF_CLK_0_5 ) begin
    if (ARESET_N_0 == 1'b0 ) begin
        cmd_cnt       <= 4'b0000;
    end
    
    else begin
        if ( incr_cmd_cnt && ~deincr_cmd_cnt ) begin
            cmd_cnt <= cmd_cnt + 1'b1;
            
        end
        
        else if ( ~incr_cmd_cnt && deincr_cmd_cnt ) begin
            cmd_cnt <= cmd_cnt - 1'b1;    
        end 
        
        else if ( incr_cmd_cnt && deincr_cmd_cnt ) begin
            cmd_cnt <= cmd_cnt;
        end         
    end
end


reg [ P_COL_ADDR_WIDTH - 1 : 0 ] col_addr_tmp;
reg [ (P_DATA_WIDTH*2) - 1 : 0 ] wrt_data_tmp;
 

always @( posedge HBM_REF_CLK_0_5 ) begin
    if (ARESET_N_0 == 1'b0 ) begin
               
        incr_cmd_cnt    <= 1'b0;
        deincr_cmd_cnt  <= 1'b0;
        
        cmd_m           <= 4'b1111;
        
        tail            <= 4'b0000;
        head            <= 4'b0000;    
        
        cmd_queue [0]   <= 4'b1111;
        cmd_queue [1]   <= 4'b1111;
        cmd_queue [2]   <= 4'b1111;
        cmd_queue [3]   <= 4'b1111;
        cmd_queue [4]   <= 4'b1111;
        cmd_queue [5]   <= 4'b1111;
        cmd_queue [6]   <= 4'b1111;
        cmd_queue [7]   <= 4'b1111;
        cmd_queue [8]   <= 4'b1111;
        cmd_queue [9]   <= 4'b1111;
        cmd_queue [10]  <= 4'b1111;
        cmd_queue [11]  <= 4'b1111;
        cmd_queue [12]  <= 4'b1111;
        cmd_queue [13]  <= 4'b1111;
        cmd_queue [14]  <= 4'b1111;
        cmd_queue [15]  <= 4'b1111;
        
        
        bank_address_m        <= { P_BA_ADDR_WIDTH  { 1'b0 } };
        row_address_m         <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        column_address_m      <= { P_COL_ADDR_WIDTH { 1'b0 } };
        
        bank_addr_queue [0]   <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue [1]   <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue [2]   <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue [3]   <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue [4]   <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue [5]   <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue [6]   <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue [7]   <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue [8]   <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue [9]   <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue [10]  <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue [11]  <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue [12]  <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue [13]  <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue [14]  <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue [15]  <= { P_BA_ADDR_WIDTH { 1'b0 } };
        
        row_addr_queue [0]   <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue [1]   <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue [2]   <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue [3]   <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue [4]   <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue [5]   <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue [6]   <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue [7]   <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue [8]   <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue [9]   <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue [10]  <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue [11]  <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue [12]  <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue [13]  <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue [14]  <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue [15]  <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        
        col_addr_queue [0]   <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue [1]   <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue [2]   <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue [3]   <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue [4]   <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue [5]   <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue [6]   <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue [7]   <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue [8]   <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue [9]   <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue [10]  <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue [11]  <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue [12]  <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue [13]  <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue [14]  <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue [15]  <= { P_COL_ADDR_WIDTH { 1'b0 } };
        
        
        wrt_data_queue [0]   <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue [1]   <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue [2]   <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue [3]   <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue [4]   <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue [5]   <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue [6]   <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue [7]   <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue [8]   <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue [9]   <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue [10]  <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue [11]  <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue [12]  <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue [13]  <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue [14]  <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue [15]  <= { (P_DATA_WIDTH*2) { 1'b0 } };
        
        wrt_data_tmp         <= { (P_DATA_WIDTH*2) { 1'b0 } };
        
        col_addr_tmp         <= { P_COL_ADDR_WIDTH { 1'b0 } };
        dummy_cnt            <= 16'h0000;
        
    end
    
    
    else begin
        if ( ready_to_cmd_m == 1'b1 ) begin
            if (cmd_cnt > 0) begin
                
                cmd_m <= cmd_queue[tail];
                
                bank_address_m   <= bank_addr_queue  [tail];
                row_address_m    <= row_addr_queue   [tail];
                column_address_m <= col_addr_queue   [tail];
                
                data_m           <= wrt_data_queue   [tail];
                
                deincr_cmd_cnt <= 1'b1;
                tail <= tail + 1'b1;
                
            end 
            
            else begin
                deincr_cmd_cnt <= 1'b0;
                cmd_m <= 4'b1111;
            end            
            
        end
        
        else begin
            cmd_m <= 4'b1111;
            deincr_cmd_cnt <= 1'b0;
        end
        
        
        if ( cmd_cnt < QUEUE_LEN ) begin
            if ( dummy_cnt == 16'h0000 ) begin
                
                cmd_queue[head]        <= LP_ROW_PRE; 
                
                bank_addr_queue[head]  <= { P_BA_ADDR_WIDTH  { 1'b0 } };
                row_addr_queue [head]  <= { P_ROW_ADDR_WIDTH { 1'b0 } };
                col_addr_queue [head]  <= { P_COL_ADDR_WIDTH { 1'b0 } };
                wrt_data_queue [head]  <= { (P_DATA_WIDTH*2) { 1'b0 } };
                 
                dummy_cnt <= dummy_cnt + 1'b1;
            
            end
            else if ( dummy_cnt == 16'h0001 ) begin
                cmd_queue[head] <= LP_ROW_ACT;
                dummy_cnt <= dummy_cnt + 1'b1;
                
            end
            else if ( dummy_cnt >= 16'd2 && dummy_cnt < 16'd50 ) begin
                cmd_queue[head]       <= LP_COL_WRT;
                col_addr_queue[head]  <= col_addr_tmp;
                col_addr_tmp          <= col_addr_tmp + 2'b10;
                dummy_cnt <= dummy_cnt + 1'b1;
                
                wrt_data_queue[head]  <= wrt_data_tmp;
                wrt_data_tmp          <= wrt_data_tmp + {{16{4'b0001}},{16{4'b0001}},{16{4'b0001}},{16{4'b0001}},{16{4'b0001}},{16{4'b0001}},{16{4'b0001}},{16{4'b0001}}};
            end 
            else if ( dummy_cnt == 16'd50 ) begin
                cmd_queue[head]       <= LP_COL_RD;
                col_addr_queue[head]  <= { P_COL_ADDR_WIDTH { 1'b0 } };
                col_addr_tmp          <= { P_COL_ADDR_WIDTH { 1'b0 } };
                dummy_cnt <= dummy_cnt + 1'b1;
            
            end
            else if ( dummy_cnt > 16'd50 && dummy_cnt < 16'd100 ) begin
                cmd_queue[head]       <= LP_COL_RD;
                col_addr_queue[head]  <= col_addr_tmp;
                col_addr_tmp          <= col_addr_tmp + 2'b10;
                dummy_cnt <= dummy_cnt + 1'b1;
            end
            
            else if ( dummy_cnt >= 16'd100 ) begin
                $finish;
            end
            
            
            incr_cmd_cnt <= 1'b1;
            head <= head + 1'b1;
            
            
            
        end
        
        else begin
            incr_cmd_cnt <= 1'b0;
        end
            
    end

end



always @ ( posedge HBM_REF_CLK_0_5 ) begin
    if (ARESET_N_0 == 1'b0 ) begin
        data_m <= { { P_DATA_WIDTH { 1'b1 } } , { P_DATA_WIDTH { 1'b0 } } };
    end  
    else begin
        
    end
end 




ll_command_forwarder_top#(
    .P_ROW_ADDR_WIDTH(P_ROW_ADDR_WIDTH),
    .P_COL_ADDR_WIDTH(P_COL_ADDR_WIDTH),
    .P_BA_ADDR_WIDTH(P_BA_ADDR_WIDTH)
    
) u_ll_command_forwarder_top(
    .HBM_REF_CLK_0(HBM_REF_CLK_0),
    .ARESET_N_0(ARESET_N_0),
    .APB_PCLK(APB_PCLK),
    .APB_PRESET_N(APB_PRESET_N),
    
    .ready_to_cmd_m(ready_to_cmd_m),
    .cmd_m(cmd_m),
    .bank_address_m(bank_address_m),
    .row_address_m(row_address_m),
    .column_address_m(column_address_m),
    .data_m(data_m)
);
    
endmodule