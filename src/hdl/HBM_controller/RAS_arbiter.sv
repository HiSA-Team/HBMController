`timescale 1ps / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/27/2023 11:18:01 AM
// Design Name: 
// Module Name: RAS_arbiter
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module RAS_arbiter#
(
    parameter       P_BA_N_PS        = 16,        /* Nunmero di Bank per PS */
    parameter       P_BA_N_G         = 8,         /* Numero di Bank per gruppo */ 
    parameter		P_ROW_ADDR_WIDTH = 16,
    parameter		P_BA_ADDR_WIDTH	 = 5,
    parameter       P_QUEUE_LEN      = 16
     
)
(
    
    /* Clock e Reset */
    input            clk,
    input            rst_n,

    /* Interfaccia verso i command bank register */
    output [0 : P_BA_N_PS - 1]  cmd_ras_bank_picked,
    input  [3:0] cmd_ras_bank  [0 : P_BA_N_PS - 1],
    input  [P_BA_ADDR_WIDTH-1 : 0] bank_address_bank [0 : P_BA_N_PS - 1],
    input  [P_ROW_ADDR_WIDTH-1 : 0] row_address_bank [0 : P_BA_N_PS - 1],
    

    /* Interfaccia verso il ll_command_forwarder */
    input  ready_to_cmd_ras,
    output [3:0]cmd_ras,
    output [P_BA_ADDR_WIDTH-1 : 0] bank_address_ras,
    output [P_ROW_ADDR_WIDTH-1 : 0] row_address_ras 
    
);

localparam LP_GENERAL_NOP = 4'b1111;

/* Coda per comandi RAS */
reg [3:0] cmd_queue_ras [0 : P_QUEUE_LEN - 1];
reg [P_BA_ADDR_WIDTH-1:0]  bank_addr_queue_ras [0 : P_QUEUE_LEN - 1];
reg [P_ROW_ADDR_WIDTH-1:0] row_addr_queue_ras  [0 : P_QUEUE_LEN - 1];
reg [3:0] tail_ras;
reg [3:0] head_ras;
reg [4:0] cmd_cnt_ras;
wire incr_cmd_cnt_ras;
wire deincr_cmd_cnt_ras;

reg [0 : P_BA_N_PS - 1] r_cmd_ras_bank_picked ;
assign cmd_ras_bank_picked = r_cmd_ras_bank_picked;

reg [3:0] r_cmd_ras;
reg [P_BA_ADDR_WIDTH-1 : 0] r_bank_address_ras;
reg [P_ROW_ADDR_WIDTH-1 : 0] r_row_address_ras; 

localparam LP_BG_N = P_BA_N_PS/P_BA_N_G;      /* Numero di Bank Groups per PS */
localparam ACTUAL_BG_CMD_RAS_SERVING_WIDTH = $clog2(P_BA_N_G);
localparam ACTUAL_BG_SERVING_WIDTH = $clog2(LP_BG_N);

reg [ACTUAL_BG_CMD_RAS_SERVING_WIDTH-1 : 0] actual_bg_cmd_ras_serving [0 : LP_BG_N - 1]; 
reg [ACTUAL_BG_SERVING_WIDTH - 1 : 0] actual_bg_serving;

reg [ACTUAL_BG_CMD_RAS_SERVING_WIDTH:0] selected_cmd_index;

assign cmd_ras = r_cmd_ras;
assign bank_address_ras = r_bank_address_ras;
assign row_address_ras = r_row_address_ras;

assign deincr_cmd_cnt_ras  =  ready_to_cmd_ras && (cmd_cnt_ras > 0);
assign incr_cmd_cnt_ras    =  (cmd_cnt_ras < P_QUEUE_LEN) && (selected_cmd_index != { ACTUAL_BG_CMD_RAS_SERVING_WIDTH+1 { 1'b1 }  } );

always @( posedge clk or negedge rst_n ) begin
    if (rst_n == 1'b0 ) begin
        cmd_cnt_ras       <= 4'b0000;
    end
    
    else begin
        if ( incr_cmd_cnt_ras && ~deincr_cmd_cnt_ras ) begin
            cmd_cnt_ras <= cmd_cnt_ras + 1'b1;
            
        end
        
        else if ( ~incr_cmd_cnt_ras && deincr_cmd_cnt_ras ) begin
            cmd_cnt_ras <= cmd_cnt_ras - 1'b1;    
        end 
        
        else if ( incr_cmd_cnt_ras && deincr_cmd_cnt_ras ) begin
            cmd_cnt_ras <= cmd_cnt_ras;
        end         
    end
end


/* Prendo l'elemento in coda e lo sparo fuori al forwarder (svuoto la coda) */
always @( posedge clk or negedge rst_n ) begin
    if (rst_n == 1'b0 ) begin
        r_cmd_ras           <= LP_GENERAL_NOP;
        tail_ras            <= 4'b0000;
        r_bank_address_ras        <= { P_BA_ADDR_WIDTH  { 1'b0 } };
        r_row_address_ras         <= { P_ROW_ADDR_WIDTH { 1'b0 } };       
    end
    
    else begin
        if ( ready_to_cmd_ras &&  (cmd_cnt_ras > 0) ) begin
            r_cmd_ras <= cmd_queue_ras[tail_ras];
            
            r_bank_address_ras  <= bank_addr_queue_ras  [tail_ras];
            r_row_address_ras    <= row_addr_queue_ras   [tail_ras];
            
            tail_ras <= tail_ras + 1'b1;
        end         
    end
end



/* Cerco il cmd da prendere all'interno del gruppo che sto servendo al momento */
always_comb begin
    if (rst_n == 1'b0 ) begin
        selected_cmd_index <= {ACTUAL_BG_CMD_RAS_SERVING_WIDTH+1 { 1'b1 } };
    end
    else begin
        for ( integer j = actual_bg_cmd_ras_serving[actual_bg_serving]; j< P_BA_N_G; j = j + 1 ) begin
            selected_cmd_index <= actual_bg_cmd_ras_serving[actual_bg_serving];
            if ( cmd_ras_bank[j+(actual_bg_serving*P_BA_N_G)] != LP_GENERAL_NOP ) begin    /* Ho trovato il primo CMD Bank buono */
                selected_cmd_index <= j;
                break;
            end
        end
    end
end

always_comb begin
    if (rst_n == 1'b0 ) begin
        for (integer k = 0; k < P_BA_N_PS; k = k + 1) begin
            r_cmd_ras_bank_picked[k] <= 1'b0;
        end
    end
    else begin
        if (cmd_cnt_ras < P_QUEUE_LEN ) begin
            for ( integer u = 0; u < P_BA_N_PS; u = u + 1 ) begin
                if ( u == selected_cmd_index+(actual_bg_serving*P_BA_N_G)) begin
                    r_cmd_ras_bank_picked[u] <= 1'b1;
                end
                else begin
                    r_cmd_ras_bank_picked[u] <= 1'b0;
                end 
            end
        end
        else begin
            r_cmd_ras_bank_picked <= { P_BA_N_PS { 1'b0 } };
        end 
    end
end


/* Riempio la coda */
always @( posedge clk or negedge rst_n ) begin
    if (rst_n == 1'b0 ) begin
        head_ras            <= 4'b0000;   
        
        /* Solitamente ci sono 2 Bank Group a PS (è quasi sempre così, credo che nelle Alveo sia sempre così) */
        actual_bg_cmd_ras_serving[0] <= { ACTUAL_BG_CMD_RAS_SERVING_WIDTH { 1'b0 } };
        actual_bg_cmd_ras_serving[1] <= { ACTUAL_BG_CMD_RAS_SERVING_WIDTH { 1'b0 } };
        
        actual_bg_serving <= { ACTUAL_BG_SERVING_WIDTH { 1'b0 } };
        
        
        cmd_queue_ras [0]   <= 4'b1111;
        cmd_queue_ras [1]   <= 4'b1111;
        cmd_queue_ras [2]   <= 4'b1111;
        cmd_queue_ras [3]   <= 4'b1111;
        cmd_queue_ras [4]   <= 4'b1111;
        cmd_queue_ras [5]   <= 4'b1111;
        cmd_queue_ras [6]   <= 4'b1111;
        cmd_queue_ras [7]   <= 4'b1111;
        cmd_queue_ras [8]   <= 4'b1111;
        cmd_queue_ras [9]   <= 4'b1111;
        cmd_queue_ras [10]  <= 4'b1111;
        cmd_queue_ras [11]  <= 4'b1111;
        cmd_queue_ras [12]  <= 4'b1111;
        cmd_queue_ras [13]  <= 4'b1111;
        cmd_queue_ras [14]  <= 4'b1111;
        cmd_queue_ras [15]  <= 4'b1111;
        
        bank_addr_queue_ras [0]   <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ras [1]   <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ras [2]   <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ras [3]   <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ras [4]   <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ras [5]   <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ras [6]   <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ras [7]   <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ras [8]   <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ras [9]   <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ras [10]  <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ras [11]  <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ras [12]  <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ras [13]  <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ras [14]  <= { P_BA_ADDR_WIDTH { 1'b0 } };
        bank_addr_queue_ras [15]  <= { P_BA_ADDR_WIDTH { 1'b0 } };
        
        row_addr_queue_ras [0]    <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ras [1]    <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ras [2]    <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ras [3]    <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ras [4]    <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ras [5]    <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ras [6]    <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ras [7]    <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ras [8]    <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ras [9]    <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ras [10]   <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ras [11]   <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ras [12]   <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ras [13]   <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ras [14]   <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        row_addr_queue_ras [15]   <= { P_ROW_ADDR_WIDTH { 1'b0 } };
    end
    else begin
        if ( (cmd_cnt_ras < P_QUEUE_LEN) && (selected_cmd_index != { ACTUAL_BG_CMD_RAS_SERVING_WIDTH+1 { 1'b1 }  } )) begin     /* Se c'è posto in coda */
        
            cmd_queue_ras[head_ras]        <= cmd_ras_bank[selected_cmd_index+(actual_bg_serving*P_BA_N_G)];
            bank_addr_queue_ras[head_ras]  <= bank_address_bank[selected_cmd_index+(actual_bg_serving*P_BA_N_G)] ;
            row_addr_queue_ras [head_ras]  <= row_address_bank[selected_cmd_index+(actual_bg_serving*P_BA_N_G)];
                         
            head_ras <= head_ras + 1'b1;
            
            
            if ( actual_bg_cmd_ras_serving[actual_bg_serving] <  P_BA_N_G -1 ) begin
                actual_bg_cmd_ras_serving[actual_bg_serving] = actual_bg_cmd_ras_serving[actual_bg_serving] + 1'b1;
            end
            else begin
                actual_bg_cmd_ras_serving[actual_bg_serving] <= { ACTUAL_BG_CMD_RAS_SERVING_WIDTH {1'b0} };
            end
            
            if ( actual_bg_serving < LP_BG_N - 1 ) begin
                actual_bg_serving <= actual_bg_serving + 1'b1;
            end
            else begin
                actual_bg_serving <= {ACTUAL_BG_SERVING_WIDTH { 1'b0 } };
            end
        end    
    end         
end


endmodule
