`timescale 1ps/1ps


module ll_command_forwarder_sim_top (
    
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
reg ARESET_N_0;
reg APB_PCLK;
reg APB_PRESET_N;

wire                              ready_to_cmd_m;
reg                               cmd_arrive_m;
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

reg col_incr;
reg col_reset;


reg row_incr;
reg row_reset;

reg [15:0] col_counter;
reg [15:0] row_counter;

localparam  M = 4;
localparam  N = 4;

reg [9:0] present_state;
reg [9:0] next_state;

localparam IDLE          = 10'd0;   /* Lo uso tipo primo PRECHARGE */
localparam ACT           = 10'd1;
localparam ACT_TO_WRT    = 10'd2;
localparam WRT           = 10'd3;
localparam WRT1          = 10'd4;
localparam WRT2          = 10'd5;
localparam WRT2_TO_PRE   = 10'd6;
localparam PRE1          = 10'd7;
localparam PRE1_TO_ACT1  = 10'd8;
localparam ACT1          = 10'd9;
localparam ACT2          = 10'd10;
localparam ACT_TO_RD     = 10'd11;
localparam RD            = 10'd12;
localparam RD1           = 10'd13;
localparam PRE2          = 10'd14;
localparam PRE2_TO_ACT2  = 10'd15;
localparam STOP          = 10'd16;



always @(posedge HBM_REF_CLK_0 ) begin
    if (ARESET_N_0 == 1'b0 ) begin
       
        cmd_arrive_m <= 1'b0;
        
        cmd_m <= LP_GENERAL_NOP;
        
        data_m <= { P_DATA_WIDTH * 2 {1'b0} };
        
        col_counter <= {16 {1'b0}};
        row_counter <= {16 {1'b0}};
        
    end
    
    else begin
        case( present_state )
            IDLE: begin
                if ( ready_to_cmd_m == 1'b1 ) begin 
                    cmd_arrive_m <= 1'b1;
                    cmd_m <= LP_ROW_PRE;
                end
                else begin
                    cmd_arrive_m <= 1'b0;
                    cmd_m <= LP_GENERAL_NOP;
                end 
            end
            
            ACT: begin
                if ( ready_to_cmd_m == 1'b1 ) begin
                    cmd_arrive_m <= 1'b1;
                    cmd_m <= LP_ROW_ACT;
                end 
                else begin
                    cmd_arrive_m <= 1'b0;
                    cmd_m <= LP_GENERAL_NOP;
                end
            
            end
            
            WRT: begin
                if ( ready_to_cmd_m == 1'b1 && col_counter < M ) begin
                    cmd_arrive_m <= 1'b1;
                    cmd_m <= LP_COL_WRT;
                end
                else begin
                    cmd_arrive_m <= 1'b0;
                    cmd_m <= LP_GENERAL_NOP;
                end
              
            end
            
            PRE1: begin
                    
                if (ready_to_cmd_m == 1'b1 ) begin
                    cmd_arrive_m <= 1'b1;
                    cmd_m <= LP_ROW_PRE;
                end
                else begin
                    cmd_arrive_m <= 1'b0;
                    cmd_m <= LP_GENERAL_NOP;
                end
            
            end
            
            ACT1: begin 
                if (ready_to_cmd_m == 1'b1 && row_counter < N ) begin
                    cmd_arrive_m <= 1'b1;
                    cmd_m <= LP_ROW_ACT;
                end
                else begin
                    cmd_arrive_m <= 1'b0;
                    cmd_m <= LP_GENERAL_NOP;
                end
            
            end
            
            ACT: begin
                if ( ready_to_cmd_m == 1'b1 ) begin
                    cmd_arrive_m <= 1'b1;
                    cmd_m <= LP_ROW_ACT;
                end 
                else begin
                    cmd_arrive_m <= 1'b0;
                    cmd_m <= LP_GENERAL_NOP;
                end
            
            end
            
            RD: begin
                if ( ready_to_cmd_m == 1'b1 && col_counter < M ) begin
                    cmd_arrive_m <= 1'b1;
                    cmd_m <= LP_COL_RD;
                end
                else begin
                    cmd_arrive_m <= 1'b0;
                    cmd_m <= LP_GENERAL_NOP;
                end
              
            end
            
            PRE2: begin
                    
                if (ready_to_cmd_m == 1'b1 ) begin
                    cmd_arrive_m <= 1'b1;
                    cmd_m <= LP_ROW_PRE;
                end
                else begin
                    cmd_arrive_m <= 1'b0;
                    cmd_m <= LP_GENERAL_NOP;
                end
            
            end
            
            ACT2: begin 
                if (ready_to_cmd_m == 1'b1 && row_counter < N ) begin
                    cmd_arrive_m <= 1'b1;
                    cmd_m <= LP_ROW_ACT;
                end
                else begin
                    cmd_arrive_m <= 1'b0;
                    cmd_m <= LP_GENERAL_NOP;
                end
            
            end
            
            
            
            default begin
                cmd_arrive_m <= 1'b0;
                cmd_m <= LP_GENERAL_NOP;
            
            end
            
            
            
        endcase
    
    end

end


reg [15:0] total_write_counter;
reg total_write_counter_incr;
always @ ( posedge HBM_REF_CLK_0  ) begin
    if (ARESET_N_0 == 1'b0 ) begin
        total_write_counter <= { 16 { 1'b0 } };
    end  
    else begin
        if ( total_write_counter_incr ) begin
            total_write_counter <= total_write_counter + 1'b1;
        end
    end

end




always @ ( posedge HBM_REF_CLK_0  ) begin
    if (ARESET_N_0 == 1'b0 ) begin
        present_state <= IDLE;
        next_state    <= IDLE;
    end  
    else begin
        present_state <= next_state;
    end
end 


always @ ( * ) begin
    col_incr = 1'b0;
    col_reset = 1'b0;
    row_incr = 1'b0;
    row_reset = 1'b0;
    total_write_counter_incr = 1'b0;
    next_state = present_state;
    
    case(present_state)
        IDLE:
        begin
            if ( ready_to_cmd_m  == 1'b1 ) begin
                next_state = ACT;
            end
            else begin
                next_state = IDLE;
            end
        end
        
        ACT:
        begin
            if ( ready_to_cmd_m == 1'b1 ) begin
                next_state = ACT_TO_WRT;
            
            end
            else begin
                next_state = ACT;
            end 
        end 
        ACT_TO_WRT:
        begin
            if ( ready_to_cmd_m == 1'b0 ) begin
                next_state = WRT;
            
            end
            else begin
                next_state = ACT_TO_WRT;
            end
        
        end
        
        WRT:
        begin
            if ( ready_to_cmd_m == 1'b1 && col_counter < M ) begin
                next_state = WRT1;
            end
            
            else if (ready_to_cmd_m == 1'b1 && col_counter >= M ) begin
                col_reset = 1'b1;
                next_state = PRE1;
            end
            
            else begin
                next_state = WRT;
            end
        end
            
        
        WRT1:
        begin
        if ( ready_to_cmd_m == 1'b0 && col_counter < M ) begin
                col_incr = 1'b1;
                total_write_counter_incr = 1'b1;
                next_state = WRT;
            end
                      
            else begin
                next_state = WRT1;
            end
        end 
       
        PRE1: 
        begin
            if ( ready_to_cmd_m == 1'b1 /*&& row_counter < 16'd4*/ ) begin
                row_incr = 1'b1; 
                next_state = PRE1_TO_ACT1;
                
            end
            
            else begin
                next_state = PRE1;
            end
        end
        
        PRE1_TO_ACT1:
        begin
            if ( ready_to_cmd_m  == 1'b0 && row_counter < N  ) begin
                next_state = ACT1;
            end
            
            else if (ready_to_cmd_m  == 1'b0 && row_counter >= N ) begin
                next_state = ACT2;
                row_reset = 1'b1;
            end
            
            else begin
                next_state = PRE1_TO_ACT1;
            end
    
        end
        
        ACT1: 
        begin
            if ( ready_to_cmd_m == 1'b1 && row_counter < N ) begin
                next_state = ACT_TO_WRT;
            end
                        
            else begin
                next_state = ACT1;
            end
        end 
        
        
        ACT2: 
        begin
            if ( ready_to_cmd_m == 1'b1 && row_counter < N ) begin
                next_state = ACT_TO_RD;
            end
                        
            else begin
                next_state = ACT2;
            end
        end 
        
        ACT_TO_RD:
        begin
            if ( ready_to_cmd_m == 1'b0 ) begin
                next_state = RD;
            
            end
            else begin
                next_state = ACT_TO_RD;
            end
        
        end
        
        RD:
        begin
            if ( ready_to_cmd_m == 1'b1 && col_counter < M ) begin
                next_state = RD1;
            end
            
            else if (ready_to_cmd_m == 1'b1 && col_counter >= M ) begin
                col_reset = 1'b1;
                next_state = PRE2;
            end
            
            else begin
                next_state = RD;
            end
        end
            
        
        RD1:
        begin
        if ( ready_to_cmd_m == 1'b0 && col_counter < M ) begin
                col_incr = 1'b1;
//                total_write_counter_incr = 1'b1;
                next_state = RD;
            end
                      
            else begin
                next_state = RD1;
            end
        end 
       
        PRE2: 
        begin
            if ( ready_to_cmd_m == 1'b1 /*&& row_counter < 16'd4*/ ) begin
                row_incr = 1'b1; 
                next_state = PRE2_TO_ACT2;
                
            end
            else begin
                next_state = PRE2;
            end
        end
       
       
        PRE2_TO_ACT2:
        begin
            if ( ready_to_cmd_m  == 1'b0 && row_counter < N  ) begin
                next_state = ACT2;
            end
            
            else if (ready_to_cmd_m  == 1'b0 && row_counter >= N ) begin
                next_state = STOP;
                row_reset = 1'b1;
            end
            
            else begin
                next_state = PRE2_TO_ACT2;
            end
    
        end
        
        
        STOP:
        begin
            $finish;
        end
        
    endcase
end


always @ ( posedge HBM_REF_CLK_0/*, posedge col_incr, posedge col_reset, posedge row_incr, negedge ARESET_N_0*/ ) begin
    if (ARESET_N_0 == 1'b0 ) begin
        col_counter <= 16'd0;
        row_counter <= 16'd0;
        bank_address_m <= { P_BA_ADDR_WIDTH { 1'b0 } };
        row_address_m <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        column_address_m <= { P_COL_ADDR_WIDTH { 1'b0 } };
        data_m[P_DATA_WIDTH-1:0] <= { P_DATA_WIDTH { 1'b0 } };
        data_m[(P_DATA_WIDTH*2)-1:P_DATA_WIDTH] <= { P_DATA_WIDTH { 1'b0 } };
        
    end  
    else begin
        if ( col_incr == 1'b1 ) begin 
            col_counter <= col_counter + 16'd1;
            column_address_m <= column_address_m + 2'b10;
            data_m[P_DATA_WIDTH-1:0] <= data_m[P_DATA_WIDTH-1:0] + { {16 {4'b0001}}, { 16 {4'b0001} }, { 16 { 4'b0001 } }, { 16 { 4'b0001 } }};
            data_m[(P_DATA_WIDTH*2)-1:P_DATA_WIDTH] <= data_m[(P_DATA_WIDTH*2)-1:P_DATA_WIDTH] + { {16 {4'b0001}}, { 16 {4'b0001} }, { 16 { 4'b0001 } }, { 16 { 4'b0001 } }}; 
            
        end
        else if ( col_reset == 1'b1 ) begin
            col_counter <= 16'd0;
            column_address_m <= { P_COL_ADDR_WIDTH {1'b0} };
            

        end
        else if ( row_incr == 1'b1 ) begin
            row_counter <= row_counter + 1'b1;
            row_address_m <= row_address_m + 2'b10; 
            
        end
        
        else if ( row_reset == 1'b1 ) begin
            row_counter <= 16'd0; 
            row_address_m <= { P_ROW_ADDR_WIDTH {1'b0} };
        
        end
        
//        else begin
//            col_incr_done <= 1'b0;
        
//        end
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
    .cmd_arrive_m(cmd_arrive_m),
    .cmd_m(cmd_m),
    .bank_address_m(bank_address_m),
    .row_address_m(row_address_m),
    .column_address_m(column_address_m),
    .data_m(data_m)
);
    
endmodule

