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

reg dfi_0_clk_buf_OUT;

reg HBM_REF_CLK_0;
wire HBM_REF_CLK_0_5;
reg ARESET_N_0;
reg APB_PCLK;
reg APB_PRESET_N;

wire                              ready_to_cmd_m_ps0;
reg   [3:0]                       cmd_m_ps0;
reg   [P_BA_ADDR_WIDTH-1:0]       bank_address_m_ps0;
reg   [P_ROW_ADDR_WIDTH-1:0]      row_address_m_ps0;
reg   [P_COL_ADDR_WIDTH-1:0]      column_address_m_ps0;
reg   [P_DATA_WIDTH-1:0]          wrt_data_m_ps0;

wire                              ready_to_cmd_m_ps1;
reg   [3:0]                       cmd_m_ps1;
reg   [P_BA_ADDR_WIDTH-1:0]       bank_address_m_ps1;
reg   [P_ROW_ADDR_WIDTH-1:0]      row_address_m_ps1;
reg   [P_COL_ADDR_WIDTH-1:0]      column_address_m_ps1;
reg   [P_DATA_WIDTH-1:0]          wrt_data_m_ps1;



assign HBM_REF_CLK_0_5 = dfi_0_clk_buf_OUT;

////////////////////////////////////////////////////////////////////////////////
// Generating 100MHz REF clock
////////////////////////////////////////////////////////////////////////////////
initial HBM_REF_CLK_0 = 1'b0;
always HBM_REF_CLK_0 = #5000.00 ~HBM_REF_CLK_0;

/* Clock 5 volte più veloce di HBM_REF_CLK_0 */
//initial HBM_REF_CLK_0_5 = 1'b0;
//always HBM_REF_CLK_0_5 = #(5000.00/4) /*1000.00*/ ~HBM_REF_CLK_0_5;


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
reg [3:0] cmd_queue_ps0 [0 : QUEUE_LEN - 1];
reg [P_BA_ADDR_WIDTH-1:0]  bank_addr_queue_ps0 [0 : QUEUE_LEN - 1];
reg [P_ROW_ADDR_WIDTH-1:0] row_addr_queue_ps0  [0 : QUEUE_LEN - 1];
reg [P_COL_ADDR_WIDTH-1:0] col_addr_queue_ps0  [0 : QUEUE_LEN - 1];
reg [P_DATA_WIDTH-1 : 0]   wrt_data_queue_ps0  [0 : QUEUE_LEN - 1];


reg [3:0] tail_ps0;
reg [3:0] head_ps0;
reg [4:0] cmd_cnt_ps0;

reg incr_cmd_cnt_ps0;
reg deincr_cmd_cnt_ps0;



reg [3:0] cmd_queue_ps1 [0 : QUEUE_LEN - 1];
reg [P_BA_ADDR_WIDTH-1:0]  bank_addr_queue_ps1 [0 : QUEUE_LEN - 1];
reg [P_ROW_ADDR_WIDTH-1:0] row_addr_queue_ps1  [0 : QUEUE_LEN - 1];
reg [P_COL_ADDR_WIDTH-1:0] col_addr_queue_ps1  [0 : QUEUE_LEN - 1];
reg [P_DATA_WIDTH-1 : 0]   wrt_data_queue_ps1  [0 : QUEUE_LEN - 1];


reg [3:0] tail_ps1;
reg [3:0] head_ps1;
reg [4:0] cmd_cnt_ps1;

reg incr_cmd_cnt_ps1;
reg deincr_cmd_cnt_ps1;


reg [31:0] dummy_cnt_ps0; 
reg [31:0] dummy_cnt_ps1; 

reg [ P_COL_ADDR_WIDTH - 1 : 0 ] col_addr_tmp_ps0;
reg [ P_DATA_WIDTH - 1 : 0 ]     wrt_data_tmp_ps0;
reg [ P_COL_ADDR_WIDTH - 1 : 0 ] col_addr_tmp_ps1;
reg [ P_DATA_WIDTH - 1 : 0 ]     wrt_data_tmp_ps1;




/*   PS0    */

always @( negedge HBM_REF_CLK_0_5 ) begin
    if (ARESET_N_0 == 1'b0 ) begin
        cmd_cnt_ps0       <= 4'b0000;
    end
    
    else begin
        if ( incr_cmd_cnt_ps0 && ~deincr_cmd_cnt_ps0 ) begin
            cmd_cnt_ps0 <= cmd_cnt_ps0 + 1'b1;
            
        end
        
        else if ( ~incr_cmd_cnt_ps0 && deincr_cmd_cnt_ps0 ) begin
            cmd_cnt_ps0 <= cmd_cnt_ps0 - 1'b1;    
        end 
        
        else if ( incr_cmd_cnt_ps0 && deincr_cmd_cnt_ps0 ) begin
            cmd_cnt_ps0 <= cmd_cnt_ps0;
        end         
    end
end

always @( posedge HBM_REF_CLK_0_5 ) begin
    if (ARESET_N_0 == 1'b0 ) begin
               
        incr_cmd_cnt_ps0    <= 1'b0;
        deincr_cmd_cnt_ps0  <= 1'b0;
        
        cmd_m_ps0           <= LP_GENERAL_NOP;
        
        tail_ps0            <= 4'b0000;
        head_ps0            <= 4'b0000;   
        
        wrt_data_m_ps0 <= { { P_DATA_WIDTH { 1'b1 } } , { P_DATA_WIDTH { 1'b0 } } }; 
        
        cmd_queue_ps0 [0]   <= 4'b1111;
        cmd_queue_ps0 [1]   <= 4'b1111;
        cmd_queue_ps0 [2]   <= 4'b1111;
        cmd_queue_ps0 [3]   <= 4'b1111;
        cmd_queue_ps0 [4]   <= 4'b1111;
        cmd_queue_ps0 [5]   <= 4'b1111;
        cmd_queue_ps0 [6]   <= 4'b1111;
        cmd_queue_ps0 [7]   <= 4'b1111;
        cmd_queue_ps0 [8]   <= 4'b1111;
        cmd_queue_ps0 [9]   <= 4'b1111;
        cmd_queue_ps0 [10]  <= 4'b1111;
        cmd_queue_ps0 [11]  <= 4'b1111;
        cmd_queue_ps0 [12]  <= 4'b1111;
        cmd_queue_ps0 [13]  <= 4'b1111;
        cmd_queue_ps0 [14]  <= 4'b1111;
        cmd_queue_ps0 [15]  <= 4'b1111;
        
        
        bank_address_m_ps0        <= { P_BA_ADDR_WIDTH  { 1'b0 } };
        row_address_m_ps0         <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        column_address_m_ps0      <= { P_COL_ADDR_WIDTH { 1'b0 } };
        
        bank_addr_queue_ps0 [0]   <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ps0 [1]   <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ps0 [2]   <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ps0 [3]   <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ps0 [4]   <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ps0 [5]   <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ps0 [6]   <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ps0 [7]   <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ps0 [8]   <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ps0 [9]   <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ps0 [10]  <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ps0 [11]  <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ps0 [12]  <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ps0 [13]  <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ps0 [14]  <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ps0 [15]  <= { P_BA_ADDR_WIDTH { 1'b0 } };
        
        row_addr_queue_ps0 [0]   <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ps0 [1]   <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ps0 [2]   <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ps0 [3]   <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ps0 [4]   <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ps0 [5]   <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ps0 [6]   <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ps0 [7]   <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ps0 [8]   <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ps0 [9]   <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ps0 [10]  <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ps0 [11]  <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ps0 [12]  <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ps0 [13]  <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ps0 [14]  <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ps0 [15]  <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        
        col_addr_queue_ps0 [0]   <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue_ps0 [1]   <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue_ps0 [2]   <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue_ps0 [3]   <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue_ps0 [4]   <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue_ps0 [5]   <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue_ps0 [6]   <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue_ps0 [7]   <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue_ps0 [8]   <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue_ps0 [9]   <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue_ps0 [10]  <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue_ps0 [11]  <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue_ps0 [12]  <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue_ps0 [13]  <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue_ps0 [14]  <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue_ps0 [15]  <= { P_COL_ADDR_WIDTH { 1'b0 } };
        
        
        wrt_data_queue_ps0 [0]   <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue_ps0 [1]   <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue_ps0 [2]   <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue_ps0 [3]   <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue_ps0 [4]   <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue_ps0 [5]   <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue_ps0 [6]   <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue_ps0 [7]   <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue_ps0 [8]   <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue_ps0 [9]   <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue_ps0 [10]  <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue_ps0 [11]  <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue_ps0 [12]  <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue_ps0 [13]  <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue_ps0 [14]  <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue_ps0 [15]  <= { (P_DATA_WIDTH*2) { 1'b0 } };
        
        wrt_data_tmp_ps0         <= { (P_DATA_WIDTH*2) { 1'b0 } };
        
        col_addr_tmp_ps0         <= { P_COL_ADDR_WIDTH { 1'b0 } };
        dummy_cnt_ps0            <= 16'h0000;
        
    end
    
    
    else begin
        if ( ready_to_cmd_m_ps0 == 1'b1 ) begin
            if (cmd_cnt_ps0 > 0) begin
                
                cmd_m_ps0 <= cmd_queue_ps0[tail_ps0];
                
                bank_address_m_ps0   <= bank_addr_queue_ps0  [tail_ps0];
                row_address_m_ps0    <= row_addr_queue_ps0   [tail_ps0];
                column_address_m_ps0 <= col_addr_queue_ps0   [tail_ps0];
                
                wrt_data_m_ps0           <= wrt_data_queue_ps0   [tail_ps0];
                
                deincr_cmd_cnt_ps0 <= 1'b1;
                tail_ps0 <= tail_ps0 + 1'b1;
                
            end 
            
            else begin
                deincr_cmd_cnt_ps0 <= 1'b0;
//                cmd_m <= 4'b1111;
            end            
            
        end
        
        else begin
//            cmd_m <= 4'b1111;
            deincr_cmd_cnt_ps0 <= 1'b0;
        end
        
        
        if ( cmd_cnt_ps0 < QUEUE_LEN ) begin
            if ( dummy_cnt_ps0 == 16'h0000 ) begin
                
                cmd_queue_ps0[head_ps0]        <= LP_ROW_PRE; 
                
                bank_addr_queue_ps0[head_ps0]  <= { P_BA_ADDR_WIDTH  { 1'b0 } };
                row_addr_queue_ps0 [head_ps0]  <= { P_ROW_ADDR_WIDTH { 1'b0 } };
                col_addr_queue_ps0 [head_ps0]  <= { P_COL_ADDR_WIDTH { 1'b0 } };
                wrt_data_queue_ps0 [head_ps0]  <= { (P_DATA_WIDTH*2) { 1'b0 } };
                 
                dummy_cnt_ps0 <= dummy_cnt_ps0 + 1'b1;
            
            end
            else if ( dummy_cnt_ps0 == 16'h0001 ) begin
                cmd_queue_ps0[head_ps0] <= LP_ROW_ACT;
                dummy_cnt_ps0 <= dummy_cnt_ps0 + 1'b1;
                
                
            end
            else if ( dummy_cnt_ps0 == 16'h0002 ) begin
                bank_addr_queue_ps0[head_ps0] <= bank_addr_queue_ps0[head_ps0] /*+ 4'b1000*/;
                cmd_queue_ps0[head_ps0] <= LP_ROW_ACT;
                dummy_cnt_ps0 <= dummy_cnt_ps0 + 1'b1;
                
            end
            
            else if ( dummy_cnt_ps0 > 16'd2 && dummy_cnt_ps0 < 16'd50 ) begin
                bank_addr_queue_ps0[head_ps0]  <= { P_BA_ADDR_WIDTH  { 1'b0 } };
                cmd_queue_ps0[head_ps0]       <= LP_COL_WRT;
                col_addr_queue_ps0[head_ps0]  <= col_addr_tmp_ps0;
                col_addr_tmp_ps0          <= col_addr_tmp_ps0 + 2'b10;
                dummy_cnt_ps0 <= dummy_cnt_ps0 + 1'b1;
                
                wrt_data_queue_ps0[head_ps0]  <= wrt_data_tmp_ps0;
                wrt_data_tmp_ps0          <= wrt_data_tmp_ps0 + {{16{4'h1}},{16{4'h2}},{16{4'h3}},{16{4'h4}}};
            end 
            else if ( dummy_cnt_ps0 == 16'd50 ) begin
                cmd_queue_ps0[head_ps0]       <= LP_COL_RD;
                col_addr_queue_ps0[head_ps0]  <= { P_COL_ADDR_WIDTH { 1'b0 } };
                col_addr_tmp_ps0          <= { P_COL_ADDR_WIDTH { 1'b0 } };
                dummy_cnt_ps0 <= dummy_cnt_ps0 + 1'b1;
            
            end
            else if ( dummy_cnt_ps0 > 16'd50 && dummy_cnt_ps0 < 32'd100 ) begin
                cmd_queue_ps0[head_ps0]       <= LP_COL_RD;
                col_addr_queue_ps0[head_ps0]  <= col_addr_tmp_ps0;
                col_addr_tmp_ps0          <= col_addr_tmp_ps0 + 2'b10;
                dummy_cnt_ps0 <= dummy_cnt_ps0 + 1'b1;
            end
            
            else if ( dummy_cnt_ps0 >= 32'd100 ) begin
                $finish;
            end
            
            
            incr_cmd_cnt_ps0 <= 1'b1;
            head_ps0 <= head_ps0 + 1'b1;
            
            
            
        end
        
        else begin
            incr_cmd_cnt_ps0 <= 1'b0;
        end
            
    end

end






/*   PS1    */

always @( negedge HBM_REF_CLK_0_5 ) begin
    if (ARESET_N_0 == 1'b0 ) begin
        cmd_cnt_ps1       <= 4'b0000;
    end
    
    else begin
        if ( incr_cmd_cnt_ps1 && ~deincr_cmd_cnt_ps1 ) begin
            cmd_cnt_ps1 <= cmd_cnt_ps1 + 1'b1;
            
        end
        
        else if ( ~incr_cmd_cnt_ps1 && deincr_cmd_cnt_ps1 ) begin
            cmd_cnt_ps1 <= cmd_cnt_ps1 - 1'b1;    
        end 
        
        else if ( incr_cmd_cnt_ps1 && deincr_cmd_cnt_ps1 ) begin
            cmd_cnt_ps1 <= cmd_cnt_ps1;
        end         
    end
end

always @( posedge HBM_REF_CLK_0_5 ) begin
    if (ARESET_N_0 == 1'b0 ) begin
               
        incr_cmd_cnt_ps1    <= 1'b0;
        deincr_cmd_cnt_ps1  <= 1'b0;
        
        cmd_m_ps1           <= LP_GENERAL_NOP;
        
        tail_ps1            <= 4'b0000;
        head_ps1            <= 4'b0000;   
        
        wrt_data_m_ps1 <= { { P_DATA_WIDTH { 1'b1 } } , { P_DATA_WIDTH { 1'b0 } } }; 
        
        cmd_queue_ps1 [0]   <= 4'b1111;
        cmd_queue_ps1 [1]   <= 4'b1111;
        cmd_queue_ps1 [2]   <= 4'b1111;
        cmd_queue_ps1 [3]   <= 4'b1111;
        cmd_queue_ps1 [4]   <= 4'b1111;
        cmd_queue_ps1 [5]   <= 4'b1111;
        cmd_queue_ps1 [6]   <= 4'b1111;
        cmd_queue_ps1 [7]   <= 4'b1111;
        cmd_queue_ps1 [8]   <= 4'b1111;
        cmd_queue_ps1 [9]   <= 4'b1111;
        cmd_queue_ps1 [10]  <= 4'b1111;
        cmd_queue_ps1 [11]  <= 4'b1111;
        cmd_queue_ps1 [12]  <= 4'b1111;
        cmd_queue_ps1 [13]  <= 4'b1111;
        cmd_queue_ps1 [14]  <= 4'b1111;
        cmd_queue_ps1 [15]  <= 4'b1111;
        
        
        bank_address_m_ps1        <= { P_BA_ADDR_WIDTH  { 1'b0 } };
        row_address_m_ps1         <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        column_address_m_ps1      <= { P_COL_ADDR_WIDTH { 1'b0 } };
        
        bank_addr_queue_ps1 [0]   <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ps1 [1]   <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ps1 [2]   <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ps1 [3]   <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ps1 [4]   <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ps1 [5]   <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ps1 [6]   <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ps1 [7]   <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ps1 [8]   <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ps1 [9]   <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ps1 [10]  <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ps1 [11]  <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ps1 [12]  <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ps1 [13]  <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ps1 [14]  <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ps1 [15]  <= { P_BA_ADDR_WIDTH { 1'b0 } };
        
        row_addr_queue_ps1 [0]   <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ps1 [1]   <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ps1 [2]   <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ps1 [3]   <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ps1 [4]   <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ps1 [5]   <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ps1 [6]   <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ps1 [7]   <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ps1 [8]   <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ps1 [9]   <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ps1 [10]  <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ps1 [11]  <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ps1 [12]  <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ps1 [13]  <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ps1 [14]  <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ps1 [15]  <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        
        col_addr_queue_ps1 [0]   <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue_ps1 [1]   <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue_ps1 [2]   <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue_ps1 [3]   <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue_ps1 [4]   <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue_ps1 [5]   <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue_ps1 [6]   <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue_ps1 [7]   <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue_ps1 [8]   <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue_ps1 [9]   <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue_ps1 [10]  <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue_ps1 [11]  <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue_ps1 [12]  <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue_ps1 [13]  <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue_ps1 [14]  <= { P_COL_ADDR_WIDTH { 1'b0 } };
        col_addr_queue_ps1 [15]  <= { P_COL_ADDR_WIDTH { 1'b0 } };
        
        
        wrt_data_queue_ps1 [0]   <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue_ps1 [1]   <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue_ps1 [2]   <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue_ps1 [3]   <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue_ps1 [4]   <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue_ps1 [5]   <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue_ps1 [6]   <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue_ps1 [7]   <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue_ps1 [8]   <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue_ps1 [9]   <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue_ps1 [10]  <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue_ps1 [11]  <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue_ps1 [12]  <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue_ps1 [13]  <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue_ps1 [14]  <= { (P_DATA_WIDTH*2) { 1'b0 } };
        wrt_data_queue_ps1 [15]  <= { (P_DATA_WIDTH*2) { 1'b0 } };
        
        wrt_data_tmp_ps1         <= { (P_DATA_WIDTH*2) { 1'b0 } };
        
        col_addr_tmp_ps1         <= { P_COL_ADDR_WIDTH { 1'b0 } };
        dummy_cnt_ps1            <= 16'h0000;
        
    end
    
    
    else begin
        if ( ready_to_cmd_m_ps1 == 1'b1 ) begin
            if (cmd_cnt_ps1 > 0) begin
                
                cmd_m_ps1 <= cmd_queue_ps1[tail_ps1];
                
                bank_address_m_ps1   <= bank_addr_queue_ps1  [tail_ps1];
                row_address_m_ps1    <= row_addr_queue_ps1   [tail_ps1];
                column_address_m_ps1 <= col_addr_queue_ps1   [tail_ps1];
                
                wrt_data_m_ps1           <= wrt_data_queue_ps1   [tail_ps1];
                
                deincr_cmd_cnt_ps1 <= 1'b1;
                tail_ps1 <= tail_ps1 + 1'b1;
                
            end 
            
            else begin
                deincr_cmd_cnt_ps1 <= 1'b0;
//                cmd_m <= 4'b1111;
            end            
            
        end
        
        else begin
//            cmd_m <= 4'b1111;
            deincr_cmd_cnt_ps1 <= 1'b0;
        end
        
        
        if ( cmd_cnt_ps1 < QUEUE_LEN ) begin
            if ( dummy_cnt_ps1 == 16'h0000 ) begin
                
                cmd_queue_ps1[head_ps1]        <= LP_ROW_PRE; 
                
                bank_addr_queue_ps1[head_ps1]  <= { P_BA_ADDR_WIDTH  { 1'b0 } };
                row_addr_queue_ps1 [head_ps1]  <= { P_ROW_ADDR_WIDTH { 1'b0 } };
                col_addr_queue_ps1 [head_ps1]  <= { P_COL_ADDR_WIDTH { 1'b0 } };
                wrt_data_queue_ps1 [head_ps1]  <= { (P_DATA_WIDTH*2) { 1'b0 } };
                 
                dummy_cnt_ps1 <= dummy_cnt_ps1 + 1'b1;
            
            end
            else if ( dummy_cnt_ps1 == 16'h0001 ) begin
                cmd_queue_ps1[head_ps1] <= LP_ROW_ACT;
                dummy_cnt_ps1 <= dummy_cnt_ps1 + 1'b1;
                
                
            end
            else if ( dummy_cnt_ps1 == 16'h0002 ) begin
                bank_addr_queue_ps1[head_ps1] <= bank_addr_queue_ps1[head_ps1] /*+ 4'b1000*/;
                cmd_queue_ps1[head_ps1] <= LP_ROW_ACT;
                dummy_cnt_ps1 <= dummy_cnt_ps1 + 1'b1;
                
            end
            
            else if ( dummy_cnt_ps1 > 16'd2 && dummy_cnt_ps1 < 16'd50 ) begin
                bank_addr_queue_ps1[head_ps1]  <= { P_BA_ADDR_WIDTH  { 1'b0 } };
                cmd_queue_ps1[head_ps1]       <= LP_COL_WRT;
                col_addr_queue_ps1[head_ps1]  <= col_addr_tmp_ps1;
                col_addr_tmp_ps1          <= col_addr_tmp_ps1 + 2'b10;
                dummy_cnt_ps1 <= dummy_cnt_ps1 + 1'b1;
                
                wrt_data_queue_ps1[head_ps1]  <= wrt_data_tmp_ps1;
                wrt_data_tmp_ps1          <= wrt_data_tmp_ps1 + {{16{4'ha}},{16{4'hb}},{16{4'hc}},{16{4'hd}}};
            end 
            else if ( dummy_cnt_ps1 == 16'd50 ) begin
                cmd_queue_ps1[head_ps1]       <= LP_COL_RD;
                col_addr_queue_ps1[head_ps1]  <= { P_COL_ADDR_WIDTH { 1'b0 } };
                col_addr_tmp_ps1          <= { P_COL_ADDR_WIDTH { 1'b0 } };
                dummy_cnt_ps1 <= dummy_cnt_ps1 + 1'b1;
            
            end
            else if ( dummy_cnt_ps1 > 16'd50 && dummy_cnt_ps1 < 32'd100 ) begin
                cmd_queue_ps1[head_ps1]       <= LP_COL_RD;
                col_addr_queue_ps1[head_ps1]  <= col_addr_tmp_ps1;
                col_addr_tmp_ps1          <= col_addr_tmp_ps1 + 2'b10;
                dummy_cnt_ps1 <= dummy_cnt_ps1 + 1'b1;
            end
            
//            else if ( dummy_cnt_ps1 >= 32'd100 ) begin
//                $finish;
//            end
            
            
            incr_cmd_cnt_ps1 <= 1'b1;
            head_ps1 <= head_ps1 + 1'b1;
            
            
            
        end
        
        else begin
            incr_cmd_cnt_ps1 <= 1'b0;
        end
            
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
    
    .ready_to_cmd_m_ps0(ready_to_cmd_m_ps0),
    .cmd_m_ps0(cmd_m_ps0),
    .bank_address_m_ps0(bank_address_m_ps0),
    .row_address_m_ps0(row_address_m_ps0),
    .column_address_m_ps0(column_address_m_ps0),
    .wrt_data_m_ps0(wrt_data_m_ps0),
    
    .ready_to_cmd_m_ps1(ready_to_cmd_m_ps1),
    .cmd_m_ps1(cmd_m_ps1),
    .bank_address_m_ps1(bank_address_m_ps1),
    .row_address_m_ps1(row_address_m_ps1),
    .column_address_m_ps1(column_address_m_ps1),
    .wrt_data_m_ps1(wrt_data_m_ps1),
    
    .dfi_0_clk_buf_OUT(dfi_0_clk_buf_OUT)
);
    
endmodule

