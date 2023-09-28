`timescale 1ps / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/27/2023 09:42:34 AM
// Design Name: 
// Module Name: HBM_controller_top
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


module HBM_controller_top#
(

)

(
    input HBM_REF_CLK_0,
    input ARESET_N_0,
    input APB_PCLK,
    input APB_PRESET_N
);

localparam MMCM_CLKFBOUT_MULT_F  = 9;
localparam MMCM_CLKOUT0_DIVIDE_F = 2;
localparam MMCM_DIVCLK_DIVIDE    = 1;
localparam MMCM_CLKIN1_PERIOD    = 10.000;


wire HBM_REF_CLK_0_buf;
wire dfi_0_clk_buf;
wire dfi_0_clk_in;
wire MMCM_LOCK_0;

wire      APB_0_PCLK_IBUF;
wire      APB_0_PCLK_BUF;
wire      APB_0_PRESET_N_sync;

wire	[3:0]		w_rst_sys_rst_0;
reg  [7:0] cnt_rst_0_0;
reg  rst_0_mmcm_n_0;

reg	[7:0]	cnt_apb_rst_p2l_st0;
wire		w_apb_0_reset_n_inv_st0;
reg			r_apb_preset_n_p2l_st0; 

reg          dfi_0_rst_n;
reg          rst_0_r1_n;
reg          rst0_st0_r1_n;
reg          rst0_st0_r2_n;
reg          rst_st0_n;

reg           w_rst_sys_rst_0_r1;
reg           w_rst_sys_rst_0_r2;
reg           w_rst_sys_rst_1_r1;
reg           w_rst_sys_rst_1_r2;

reg           rst_0_mmcm_n;
reg  [3:0]    cnt_rst_0;

always @ (posedge HBM_REF_CLK_0_buf or negedge ARESET_N_0) begin
    if (~ARESET_N_0) begin
        cnt_rst_0_0        <= 8'h00;
        rst_0_mmcm_n_0     <= 1'b0;
    end else begin
        if (~rst_0_r1_n) begin
            if( cnt_rst_0_0 >= 8'd100 ) begin
                cnt_rst_0_0 <= cnt_rst_0_0;
                rst_0_mmcm_n_0 <= 1'b0;
            end
            else begin
                cnt_rst_0_0 <= cnt_rst_0_0 + 1;
                rst_0_mmcm_n_0 <= rst_0_mmcm_n_0;
            end
        end else begin
            cnt_rst_0_0 <= 'd0;
            rst_0_mmcm_n_0 <= 1'b1;
        end
    end
end


always @ (posedge HBM_REF_CLK_0_buf or negedge ARESET_N_0) begin
    if (~ARESET_N_0) begin
        rst_0_mmcm_n  <= 1'b0;
    end else begin
        if (cnt_rst_0 != 4'h0) begin
            rst_0_mmcm_n <= 1'b0;
        end else begin
            rst_0_mmcm_n <= 1'b1;
        end
    end
end


always @ (posedge HBM_REF_CLK_0_buf or negedge ARESET_N_0) begin
    if (~ARESET_N_0) begin
        w_rst_sys_rst_0_r1 <= 1'b0;
        w_rst_sys_rst_0_r2 <= 1'b0;
    end else begin
        w_rst_sys_rst_0_r1 <= w_rst_sys_rst_0[1];
        w_rst_sys_rst_0_r2 <= w_rst_sys_rst_0_r1;
    end
end

always @ (posedge HBM_REF_CLK_0_buf or negedge ARESET_N_0) begin
    if (~ARESET_N_0) begin
        rst_st0_n <= 1'b0;
    end else begin
        rst_st0_n <= rst_0_mmcm_n & MMCM_LOCK_0 & (~w_rst_sys_rst_0_r2);
    end
end



always @ (posedge dfi_0_clk_buf or negedge ARESET_N_0) begin
  if (~ARESET_N_0) begin
    rst0_st0_r1_n <= 1'b0;
    rst0_st0_r2_n <= 1'b0;
  end else begin
    rst0_st0_r1_n <= rst_st0_n;
    rst0_st0_r2_n <= rst0_st0_r1_n;
  end
end

always @ (posedge dfi_0_clk_buf or negedge ARESET_N_0) begin
  if (~ARESET_N_0) begin
    dfi_0_rst_n <= 1'b0;
  end else begin
    dfi_0_rst_n <= rst0_st0_r2_n;
  end
end


always @ (posedge HBM_REF_CLK_0_buf or negedge ARESET_N_0) begin
    if (~ARESET_N_0) begin
        cnt_rst_0 <= 4'hA;
    end else begin
        if (~rst_0_r1_n) begin
            cnt_rst_0 <= 4'hA;
        end else if (cnt_rst_0 != 4'h0) begin
            cnt_rst_0 <= cnt_rst_0 - 1'b1;
        end else begin
            cnt_rst_0 <= cnt_rst_0;
        end
    end
end

always @ (posedge HBM_REF_CLK_0_buf or negedge ARESET_N_0) begin
    if (~ARESET_N_0) begin
        rst_0_r1_n <= 1'b0;
    end else begin
        rst_0_r1_n <= 1'b1;
    end
end

assign w_rst_sys_rst_0 = 4'h0;
assign	w_apb_0_reset_n_inv_st0 = APB_PRESET_N && ~w_rst_sys_rst_0[0];
always @ ( posedge APB_0_PCLK_BUF or negedge  w_apb_0_reset_n_inv_st0 )
begin
	if( w_apb_0_reset_n_inv_st0 == 1'b0 )
		begin
			cnt_apb_rst_p2l_st0 <= 8'd0;
			r_apb_preset_n_p2l_st0 <= 1'd0;
		end
	else
		begin
			if( cnt_apb_rst_p2l_st0 >= 8'd200 )
			begin
				r_apb_preset_n_p2l_st0	<= 1'd1;
				cnt_apb_rst_p2l_st0		<= cnt_apb_rst_p2l_st0;
			end
			else
			begin
				cnt_apb_rst_p2l_st0		<= cnt_apb_rst_p2l_st0 + 8'd1;
				r_apb_preset_n_p2l_st0 <= 1'b0;
			end
		end
end

assign APB_0_PRESET_N_sync = r_apb_preset_n_p2l_st0 ;



IBUF u_APB_0_PCLK_IBUF  (
  .I (APB_PCLK),
  .O (APB_0_PCLK_IBUF)
);

BUFG u_APB_0_PCLK_BUFG  (
  .I (APB_0_PCLK_IBUF),
  .O (APB_0_PCLK_BUF)
);

BUFG u_HBM_REF_CLK_0  (
  .I (HBM_REF_CLK_0),
  .O (HBM_REF_CLK_0_buf)
);

BUFG u_dfi_0_clk_buf  (
  .I (dfi_0_clk_in),
  .O (dfi_0_clk_buf)
);

MMCME4_ADV
  #(.BANDWIDTH            ("OPTIMIZED"),
    .CLKOUT4_CASCADE      ("FALSE"),
    .COMPENSATION         ("INTERNAL"),
    .STARTUP_WAIT         ("FALSE"),
    .DIVCLK_DIVIDE        (MMCM_DIVCLK_DIVIDE),
    .CLKFBOUT_MULT_F      (MMCM_CLKFBOUT_MULT_F),
    .CLKFBOUT_PHASE       (0.000),
    .CLKFBOUT_USE_FINE_PS ("FALSE"),
    .CLKOUT0_DIVIDE_F     (MMCM_CLKOUT0_DIVIDE_F),
    .CLKOUT0_PHASE        (0.000),
    .CLKOUT0_DUTY_CYCLE   (0.500),
    .CLKOUT0_USE_FINE_PS  ("FALSE"),
    .CLKOUT1_DIVIDE       (MMCM_CLKOUT0_DIVIDE_F),
    .CLKOUT2_DIVIDE       (MMCM_CLKOUT0_DIVIDE_F),
    .CLKOUT3_DIVIDE       (MMCM_CLKOUT0_DIVIDE_F),
    .CLKOUT4_DIVIDE       (MMCM_CLKOUT0_DIVIDE_F),
    .CLKOUT5_DIVIDE       (MMCM_CLKOUT0_DIVIDE_F),
    .CLKOUT6_DIVIDE       (MMCM_CLKOUT0_DIVIDE_F),
    .CLKIN1_PERIOD        (MMCM_CLKIN1_PERIOD),
    .REF_JITTER1          (0.010))
  u_mmcm_0
    // Output clocks
   (
    .CLKFBOUT            (),
    .CLKFBOUTB           (),
    .CLKOUT0             (dfi_0_clk_in),

    .CLKOUT0B            (),
    .CLKOUT1             (),
    .CLKOUT1B            (),
    .CLKOUT2             (),
    .CLKOUT2B            (),
    .CLKOUT3             (),
    .CLKOUT3B            (),
    .CLKOUT4             (),
    .CLKOUT5             (),
    .CLKOUT6             (),
     // Input clock control
    .CLKFBIN             (), //mmcm_fb
    .CLKIN1              (HBM_REF_CLK_0_buf),
    .CLKIN2              (1'b0),
    // Other control and status signals
    .LOCKED              (MMCM_LOCK_0),
    .PWRDWN              (1'b0),
    .RST                 (~rst_0_mmcm_n_0),
  
    .CDDCDONE            (),
    .CLKFBSTOPPED        (),
    .CLKINSTOPPED        (),
    .DO                  (),
    .DRDY                (),
    .PSDONE              (),
    .CDDCREQ             (1'b0),
    .CLKINSEL            (1'b1),
    .DADDR               (7'b0),
    .DCLK                (1'b0),
    .DEN                 (1'b0),
    .DI                  (16'b0),
    .DWE                 (1'b0),
    .PSCLK               (1'b0),
    .PSEN                (1'b0),
    .PSINCDEC            (1'b0)
  );
  
  HBM_controller#() 
  HBM_controller_i (
    .HBM_REF_CLK_0_buf(HBM_REF_CLK_0_buf),
 
    .dfi_0_clk_buf(dfi_0_clk_buf),
    .dfi_0_rst_n(dfi_0_rst_n),
    
    .APB_0_PCLK_BUF(APB_0_PCLK_BUF),
    .APB_0_PRESET_N_sync(APB_0_PRESET_N_sync)
  );
  
  
  endmodule