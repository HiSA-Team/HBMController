`timescale 1ps / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/27/2023 10:34:04 AM
// Design Name: 
// Module Name: HBM_controller_sim_top
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


module HBM_controller_sim_top(

    );
    
    
    
reg HBM_REF_CLK_0;
reg ARESET_N_0;
reg APB_PCLK;
reg APB_PRESET_N;

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



HBM_controller_top #()
HBM_controller_top_i (
    .HBM_REF_CLK_0(HBM_REF_CLK_0),
    .ARESET_N_0(ARESET_N_0),
    .APB_PCLK(APB_PCLK),
    .APB_PRESET_N(APB_PRESET_N)

);
endmodule
