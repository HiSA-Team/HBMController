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


module HBM_controller_top_tb(

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

integer fd;
string  line;
string  request;
reg [31:0] address;
reg [31:0] input_address [0:15];
reg [255:0] data;
reg [255:0] input_data [0:15];
reg [31:0]tmp_data;
reg [1:0] input_request [0:15];
reg request_valid[0:15];
wire request_picked[0:15]; 
wire reset_hbm_controller[0:15];

initial begin

    wait(reset_hbm_controller[0] == 1'b1);
        
    fd = $fopen("./example_0.txt", "r");
    while(!$feof(fd))begin
        $fgets(line, fd);
        request = line.substr(0,1);
        address = line.substr(3, 10).atohex();
        if (line.len() >= 64 + 2 + 8 ) begin
            data = line.substr(12, 19).atohex();
            data = data << 32;
            tmp_data = line.substr(20, 27).atohex();
            data = (data + tmp_data) << 32;
            tmp_data = line.substr(28, 35).atohex();
            data = (data + tmp_data) << 32;
            tmp_data = line.substr(36, 43).atohex();
            data = (data + tmp_data) << 32;
            tmp_data = line.substr(44, 51).atohex();
            data = (data + tmp_data) << 32;
            tmp_data = line.substr(52, 59).atohex();
            data = (data + tmp_data) << 32;
            tmp_data = line.substr(60, 67).atohex();
            data = (data + tmp_data) << 32;
            tmp_data = line.substr(68, 75).atohex();
            data = (data + tmp_data);
        end
        if (request == "RD") begin
            input_request[0] <= 2'b01;
        end
        else begin
            input_request[0] <= 2'b00;
        end
            
        input_address[0] <= address;
            
        if (line.len() >= 64 + 2 + 8 ) begin
            input_data[0] <= data;  
        end

        request_valid[0] <= 1'b1;
        wait(request_picked[0] == 1'b1);
        request_valid[0] <= 1'b0;   

        wait(request_picked[0] == 1'b0);
    end
    
    $fclose(fd);
    $finish;
end

wire [8:0]     rd_data_req_id_ps0   [0:16-1];
wire [255:0]   rd_data_ps0          [0:16-1];
wire [8:0]     rd_data_req_id_ps1   [0:16-1];
wire [255:0]   rd_data_ps1          [0:16-1];


HBM_controller_top #()
HBM_controller_top_i (
    .HBM_REF_CLK_0(HBM_REF_CLK_0),
    .ARESET_N_0(ARESET_N_0),
    .APB_PCLK_0(APB_PCLK),
    .APB_PRESET_N_0(APB_PRESET_N),
    .address(input_address[0:0]),
    .request(input_request[0:0]),
    .write_data(input_data[0:0]),
    .request_valid(request_valid[0:0]),
    .request_picked(request_picked[0:0]),
    .reset_hbm_controller(reset_hbm_controller/*[0:0]*/),
    .rd_data_req_id_ps0(rd_data_req_id_ps0[0:0]),
    .rd_data_ps0(rd_data_ps0[0:0]),
    .rd_data_req_id_ps1(rd_data_req_id_ps1[0:0]),
    .rd_data_ps1(rd_data_ps1[0:0])
);
endmodule
