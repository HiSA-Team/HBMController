`timescale 1ps/1ps

`include "commands.svh"
`include "hbm_controller.svh"

module llcf_ras_cmd_driver (
    input logic clock_i,
    input logic reset_ni,

    input logic can_serve_actual_ras_ps0,
    input logic can_serve_actual_ras_ps1, 
    input logic can_serve_actual_act_ps0,
    input logic can_serve_actual_act_ps1,
    input logic can_serve_actual_pre_ps0,
    input logic can_serve_actual_pre_ps1,
    input logic can_serve_actual_ref_ps0,
    input logic can_serve_actual_ref_ps1,

    input logic [3:0]                  cmd_ras_ps0, 
    input logic [P_BA_ADDR_WIDTH-1:0]  bank_address_ras_ps0, 
    input logic [P_ROW_ADDR_WIDTH-1:0] row_address_ras_ps0, 

    input logic [3:0]                  cmd_ras_ps1, 
    input logic [P_BA_ADDR_WIDTH-1:0]  bank_address_ras_ps1, 
    input logic [P_ROW_ADDR_WIDTH-1:0] row_address_ras_ps1, 
    
    input logic [3:0] r_phy_tg_ps, 


    `ifdef DEBUG
        input logic [P_REQ_ID_WIDTH-1:0] req_ras_id_ps0, 
        input logic [P_CMD_ID_WIDTH-1:0] cmd_ras_id_ps0,
        input logic [P_REQ_ID_WIDTH-1:0] req_ras_id_ps1, 
        input logic [P_CMD_ID_WIDTH-1:0] cmd_ras_id_ps1, 
    `endif
  

    output logic                        double_act_ras_sync,

    output logic [(P_BA_N_PS*2)-1:0]     served_ras,
    output logic [11:0]                  dfi_aw_row_p0,
    output logic [11:0]                  dfi_aw_row_p1    
);



logic [3:0]                       sync_cmd_ras_ps1;
logic [P_BA_ADDR_WIDTH  -1 : 0]   sync_bank_addr_ras_ps1;
logic [P_ROW_ADDR_WIDTH -1 : 0]   sync_row_addr_ras_ps1;
logic [P_REQ_ID_WIDTH-1:0]        sync_req_ras_id_ps1;
logic [P_CMD_ID_WIDTH-1:0]        sync_cmd_ras_id_ps1;


always @( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        double_act_ras_sync    <=  1'b0;
        sync_cmd_ras_ps1       <=  P_GENERAL_NOP;
        sync_bank_addr_ras_ps1 <=  { P_BA_ADDR_WIDTH  { 1'b0 } };
        sync_row_addr_ras_ps1  <=  { P_ROW_ADDR_WIDTH { 1'b0 } };
        sync_req_ras_id_ps1    <=  { P_REQ_ID_WIDTH {1'b0} };
        sync_cmd_ras_id_ps1    <=  { P_CMD_ID_WIDTH {1'b0} };
    end 
    else begin 
        if ( (can_serve_actual_act_ps0 && can_serve_actual_ras_ps1) || (can_serve_actual_act_ps1 && can_serve_actual_ras_ps0) && ~double_act_ras_sync) begin
            double_act_ras_sync    <=  1'b1;
            sync_cmd_ras_ps1       <=  cmd_ras_ps1;
            sync_bank_addr_ras_ps1 <=  bank_address_ras_ps1;
            sync_row_addr_ras_ps1  <=  row_address_ras_ps1;
            sync_req_ras_id_ps1    <=  req_ras_id_ps1;
            sync_cmd_ras_id_ps1    <=  cmd_ras_id_ps1;
        end
        else if ( double_act_ras_sync ) begin
            double_act_ras_sync    <=  1'b0;
            sync_cmd_ras_ps1       <=  P_GENERAL_NOP;
            sync_bank_addr_ras_ps1 <=  { P_BA_ADDR_WIDTH  { 1'b0 } };
            sync_row_addr_ras_ps1  <=  { P_ROW_ADDR_WIDTH { 1'b0 } };
            sync_req_ras_id_ps1    <=  { P_REQ_ID_WIDTH {1'b0} };
            sync_cmd_ras_id_ps1    <=  { P_CMD_ID_WIDTH {1'b0} };
        end 
    end
end


/***********************/
/* SEND COMMAND TO HBM */
/***********************/

always @ ( posedge clock_i or negedge reset_ni ) begin
    if( reset_ni == 1'b0 ) begin
        dfi_aw_row_p0    <= 12'hfff;
        dfi_aw_row_p1    <= 12'hfff;      
        served_ras       <= { (P_BA_N_PS*2) {1'b0} };
          
    end
    
    else if( r_phy_tg_ps == LP_MRS ) begin
        dfi_aw_row_p0    <= 12'hfff;
        dfi_aw_row_p1    <= 12'hfff;
    end

    else begin
        
        if ( double_act_ras_sync ) begin
            if ( sync_cmd_ras_ps1 == P_ROW_ACT )  begin

                dfi_aw_row_p0	 <= {sync_bank_addr_ras_ps1[3], sync_row_addr_ras_ps1[13], LP_BA4_1, LP_PAR, sync_row_addr_ras_ps1[12:11], sync_bank_addr_ras_ps1[2:0],1'b0/*r_RA[14]*/,P_ROW_ACT[1:0]};
                dfi_aw_row_p1	 <= {sync_row_addr_ras_ps1[4:2], LP_PAR, sync_row_addr_ras_ps1[1:0], sync_row_addr_ras_ps1[10:5]};
                served_ras       <= 1'b1 << {LP_BA4_1, sync_bank_addr_ras_ps1[3:0]};

                `ifdef DEBUG
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  sync_req_ras_id_ps1, sync_cmd_ras_id_ps1, sync_cmd_ras_ps1, $time);
                `endif
            end 
            else if ( sync_cmd_ras_ps1 == P_ROW_PRE ) begin

                dfi_aw_row_p0		<= { sync_bank_addr_ras_ps1[3] , 1'b0, LP_BA4_1, LP_PAR, 2'b00, sync_bank_addr_ras_ps1[2:0], P_ROW_PRE};
                dfi_aw_row_p1		<= 12'hfff;
                served_ras          <= 1'b1 << {LP_BA4_1, sync_bank_addr_ras_ps1[3:0]};

                `ifdef DEBUG
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  sync_req_ras_id_ps1, sync_cmd_ras_id_ps1, sync_cmd_ras_ps1, $time);
                `endif
            end
            else if ( sync_cmd_ras_ps1 == P_ROW_REFPB ) begin

                dfi_aw_row_p0	 <= {sync_bank_addr_ras_ps1[3], 1'b0, LP_BA4_1, LP_PAR, 2'b11, sync_bank_addr_ras_ps1[2:0], P_ROW_REFPB[2:0]};
                dfi_aw_row_p1	 <= 12'hfff;
                served_ras       <= 1'b1 << {LP_BA4_1, sync_bank_addr_ras_ps1[3:0]};
                
                `ifdef DEBUG
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  sync_req_ras_id_ps1, sync_cmd_ras_id_ps1, sync_cmd_ras_ps1, $time);
                `endif
            end
            else begin
                served_ras      <= { (P_BA_N_PS*2) {1'b0} };
                dfi_aw_row_p0   <= 12'hfff;
                dfi_aw_row_p1   <= 12'hfff;
                
            end
        end
        else begin 
            if ((can_serve_actual_act_ps0 && can_serve_actual_ras_ps1) || (can_serve_actual_act_ps1 && can_serve_actual_ras_ps0)) begin
                if ( cmd_ras_ps0 == P_ROW_ACT )  begin

                    dfi_aw_row_p0	 <= {bank_address_ras_ps0[3], row_address_ras_ps0[13], LP_BA4_0, LP_PAR, row_address_ras_ps0[12:11], bank_address_ras_ps0[2:0],1'b0/*r_RA[14]*/,P_ROW_ACT[1:0]};
                    dfi_aw_row_p1	 <= {row_address_ras_ps0[4:2], LP_PAR, row_address_ras_ps0[1:0], row_address_ras_ps0[10:5]};
                    served_ras       <= 1'b1 << {LP_BA4_0, bank_address_ras_ps0[3:0]};

                    `ifdef DEBUG
                        $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_ras_id_ps0, cmd_ras_id_ps0, cmd_ras_ps0, $time);
                    `endif 
                end 
                else if ( cmd_ras_ps0 == P_ROW_PRE ) begin

                    dfi_aw_row_p0		<= { bank_address_ras_ps0[3] , 1'b0, LP_BA4_0, LP_PAR, 2'b00, bank_address_ras_ps0[2:0], P_ROW_PRE};
                    dfi_aw_row_p1		<= 12'hfff;
                    served_ras          <= 1'b1 << {LP_BA4_0, bank_address_ras_ps0[3:0]};

                    `ifdef DEBUG
                        $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_ras_id_ps0, cmd_ras_id_ps0, cmd_ras_ps0, $time);
                    `endif
                end
                else if ( cmd_ras_ps0 == P_ROW_REFPB ) begin

                    dfi_aw_row_p0	 <= { bank_address_ras_ps0[3], 1'b0, LP_BA4_0, LP_PAR, 2'b11, bank_address_ras_ps0[2:0], P_ROW_REFPB[2:0]};
                    dfi_aw_row_p1	 <= 12'hfff;
                    served_ras       <= 1'b1 << {LP_BA4_0, bank_address_ras_ps0[3:0]};
                    
                    `ifdef DEBUG
                        $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_ras_id_ps0, cmd_ras_id_ps0, cmd_ras_ps0, $time);
                    `endif

                end
                else begin
                    served_ras    <= { (P_BA_N_PS*2) {1'b0} };
                end
            end
            
            else if ( can_serve_actual_act_ps0 && (cmd_ras_ps1 == P_GENERAL_NOP || ~can_serve_actual_ras_ps1 )) begin
                
                dfi_aw_row_p0	 <= {bank_address_ras_ps0[3], row_address_ras_ps0[13], LP_BA4_0, LP_PAR, row_address_ras_ps0[12:11], bank_address_ras_ps0[2:0],1'b0/*r_RA[14]*/,P_ROW_ACT[1:0]};
                dfi_aw_row_p1	 <= {row_address_ras_ps0[4:2], LP_PAR, row_address_ras_ps0[1:0], row_address_ras_ps0[10:5]};
                served_ras       <= 1'b1 << {LP_BA4_0, bank_address_ras_ps0[3:0]};

                `ifdef DEBUG
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_ras_id_ps0, cmd_ras_id_ps0, cmd_ras_ps0, $time);
                `endif
            end 
                        
            else if ( can_serve_actual_pre_ps0 && (cmd_ras_ps1 == P_GENERAL_NOP || ~can_serve_actual_ras_ps1 )  ) begin
                
                dfi_aw_row_p0		<= { bank_address_ras_ps0[3] , 1'b0, LP_BA4_0, LP_PAR, 2'b00, bank_address_ras_ps0[2:0], P_ROW_PRE};
                dfi_aw_row_p1		<= 12'hfff;
                served_ras          <= 1'b1 << {LP_BA4_0, bank_address_ras_ps0[3:0]};

                `ifdef DEBUG
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_ras_id_ps0, cmd_ras_id_ps0, cmd_ras_ps0, $time);
                `endif
            end
            
            else if ( can_serve_actual_pre_ps0 && (can_serve_actual_pre_ps1 )  ) begin
                
                dfi_aw_row_p0		<= { bank_address_ras_ps0[3] , 1'b0, LP_BA4_0, LP_PAR, 2'b00, bank_address_ras_ps0[2:0], P_ROW_PRE};
                dfi_aw_row_p1		<= { bank_address_ras_ps1[3] , 1'b0, LP_BA4_1, LP_PAR, 2'b00, bank_address_ras_ps1[2:0], P_ROW_PRE};
                served_ras          <= (1'b1 << {LP_BA4_0, bank_address_ras_ps0[3:0]}) + (1'b1 << {LP_BA4_1, bank_address_ras_ps1[3:0]} );

                `ifdef DEBUG
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_ras_id_ps0, cmd_ras_id_ps0, cmd_ras_ps0, $time);
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_ras_id_ps1, cmd_ras_id_ps1, cmd_ras_ps1, $time);
                `endif
            end
            
            else if ( (can_serve_actual_act_ps1) && (cmd_ras_ps0 == P_GENERAL_NOP || ~can_serve_actual_ras_ps0 )) begin
                
                dfi_aw_row_p0	 <= {bank_address_ras_ps1[3], row_address_ras_ps1[13], LP_BA4_1, LP_PAR, row_address_ras_ps1[12:11], bank_address_ras_ps1[2:0],1'b0/*r_RA[14]*/,P_ROW_ACT[1:0]};
                dfi_aw_row_p1	 <= {row_address_ras_ps1[4:2], LP_PAR, row_address_ras_ps1[1:0], row_address_ras_ps1[10:5]};
                served_ras       <= (1'b1 << {LP_BA4_1, bank_address_ras_ps1[3:0]} );

                `ifdef DEBUG
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_ras_id_ps1, cmd_ras_id_ps1, cmd_ras_ps1, $time);
                `endif 
            end 
                        
            else if ( (can_serve_actual_pre_ps1) && (cmd_ras_ps0 == P_GENERAL_NOP || ~can_serve_actual_ras_ps0 )  ) begin
                
                dfi_aw_row_p0		<= { bank_address_ras_ps1[3] , 1'b0, LP_BA4_1, LP_PAR, 2'b00, bank_address_ras_ps1[2:0], P_ROW_PRE};
                dfi_aw_row_p1		<= 12'hfff;
                served_ras          <= (1'b1 << {LP_BA4_1, bank_address_ras_ps1[3:0]} );
                
                `ifdef DEBUG
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_ras_id_ps1, cmd_ras_id_ps1, cmd_ras_ps1, $time);
                `endif             
            end
            
            else if ( (can_serve_actual_ref_ps0) && (cmd_ras_ps1 == P_GENERAL_NOP || ~can_serve_actual_ras_ps1 ) ) begin
                
                dfi_aw_row_p0	 <= { bank_address_ras_ps0[3], 1'b0, LP_BA4_0, LP_PAR, 2'b11, bank_address_ras_ps0[2:0], P_ROW_REFPB[2:0]};
                dfi_aw_row_p1	 <= 12'hfff;
                served_ras       <= (1'b1 << {LP_BA4_0, bank_address_ras_ps0[3:0]});

                `ifdef DEBUG
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_ras_id_ps0, cmd_ras_id_ps0, cmd_ras_ps0, $time);
                `endif
            end
            
            else if ( (can_serve_actual_ref_ps1) && (cmd_ras_ps0 == P_GENERAL_NOP || ~can_serve_actual_ras_ps0 ) ) begin
                
                dfi_aw_row_p0	 <= { bank_address_ras_ps1[3], 1'b0, LP_BA4_1, LP_PAR, 2'b11, bank_address_ras_ps1[2:0], P_ROW_REFPB[2:0]};
                dfi_aw_row_p1	 <= 12'hfff;
                served_ras       <= (1'b1 << {LP_BA4_1, bank_address_ras_ps1[3:0]} );
                
                `ifdef DEBUG
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_ras_id_ps1, cmd_ras_id_ps1, cmd_ras_ps1, $time);
                `endif
            end
            
            else if ( (can_serve_actual_ref_ps0) && (can_serve_actual_pre_ps1 ) ) begin
                
                dfi_aw_row_p0	 <= { bank_address_ras_ps0[3], 1'b0, LP_BA4_0, LP_PAR, 2'b11, bank_address_ras_ps0[2:0], P_ROW_REFPB[2:0]};
                dfi_aw_row_p1	 <= { bank_address_ras_ps1[3] , 1'b0, LP_BA4_1, LP_PAR, 2'b00, bank_address_ras_ps1[2:0], P_ROW_PRE};
                served_ras       <= (1'b1 << {LP_BA4_0, bank_address_ras_ps0[3:0]}) + (1'b1 << {LP_BA4_1, bank_address_ras_ps1[3:0]} );

                `ifdef DEBUG
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_ras_id_ps0, cmd_ras_id_ps0, cmd_ras_ps0, $time);
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_ras_id_ps1, cmd_ras_id_ps1, cmd_ras_ps1, $time);
                `endif
            end
            
            else if ( (can_serve_actual_ref_ps1) && (cmd_ras_ps0 == P_ROW_PRE && can_serve_actual_ras_ps0 ) ) begin
                
                dfi_aw_row_p0	 <= { bank_address_ras_ps0[3] , 1'b0, LP_BA4_0, LP_PAR, 2'b00, bank_address_ras_ps0[2:0], P_ROW_PRE};
                dfi_aw_row_p1	 <= { bank_address_ras_ps1[3], 1'b0, LP_BA4_1, LP_PAR, 2'b11, bank_address_ras_ps1[2:0], P_ROW_REFPB[2:0]};
                served_ras       <= (1'b1 << {LP_BA4_0, bank_address_ras_ps0[3:0]}) + (1'b1 << {LP_BA4_1, bank_address_ras_ps1[3:0]} );
                
                `ifdef DEBUG
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_ras_id_ps0, cmd_ras_id_ps0, cmd_ras_ps0, $time);
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_ras_id_ps1, cmd_ras_id_ps1, cmd_ras_ps1, $time);
                `endif
            end
            
            else if ( (can_serve_actual_ref_ps0) && (can_serve_actual_ref_ps1 ) ) begin
               
                dfi_aw_row_p0	 <= { bank_address_ras_ps0[3], 1'b0, LP_BA4_0, LP_PAR, 2'b11, bank_address_ras_ps0[2:0], P_ROW_REFPB[2:0]};
                dfi_aw_row_p1	 <= { bank_address_ras_ps1[3], 1'b0, LP_BA4_1, LP_PAR, 2'b11, bank_address_ras_ps1[2:0], P_ROW_REFPB[2:0]};
                served_ras       <= (1'b1 << {LP_BA4_0, bank_address_ras_ps0[3:0]}) + (1'b1 << {LP_BA4_1, bank_address_ras_ps1[3:0]} );
                
                `ifdef DEBUG
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_ras_id_ps0, cmd_ras_id_ps0, cmd_ras_ps0, $time);
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_ras_id_ps1, cmd_ras_id_ps1, cmd_ras_ps1, $time);
                `endif
            end
            
            else begin
                dfi_aw_row_p0    <= 12'hfff;
                dfi_aw_row_p1    <= 12'hfff;
                served_ras       <= { (P_BA_N_PS*2) {1'b0} }; 
            end 
        end
    end
end

endmodule