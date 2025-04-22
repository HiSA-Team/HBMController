`timescale 1ps/1ps

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

logic clk_450 [0:15];

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


logic f_open = 0;

always @(posedge clk_450[0]) begin

    if ( f_open == 0 ) begin
        request_valid[0] <= 1'b0;
        fd = $fopen("./example_0.txt", "r");
        f_open <= 1;
    end

    if (reset_hbm_controller[0] == 1'b1) begin
        if ( !$feof(fd) ) begin

            if ( ~request_valid[0] || (request_valid[0] && request_picked[0])) begin
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

            end

//            else if (~request_picked[0] && request_valid[0]) begin
//                request_valid[0] <= 1'b0;
//            end

        end
        else begin
            $fclose(fd);
            $finish;
        end
    end
end

wire          rd_data_valid_ps0    [0:16-1];
wire          rd_data_valid_ps1    [0:16-1];
wire [23:0]   rd_data_req_id_ps0   [0:16-1];
wire [255:0]  rd_data_ps0          [0:16-1];
wire [23:0]   rd_data_req_id_ps1   [0:16-1];
wire [255:0]  rd_data_ps1          [0:16-1];


logic [23:0] request_id [0:15];

always_comb begin
    foreach (request_id[i]) request_id[i] <= '0;
end


HBM_controller_top #()
HBM_controller_top_i (
    .HBM_REF_CLK_0(HBM_REF_CLK_0),
     .ARESET_N_0(ARESET_N_0),
     .APB_PCLK_0(APB_PCLK),
     .APB_PRESET_N_0(APB_PRESET_N),
     .ARESET_N_1(ARESET_N_0),
     .APB_PCLK_1(APB_PCLK),
     .APB_PRESET_N_1(APB_PRESET_N),

    .address(input_address),
    .request(input_request),
    .write_data(input_data),
    .request_valid(request_valid),
    .request_picked(request_picked),
    .request_id(request_id),
    .reset_hbm_controller(reset_hbm_controller),
    .rd_data_req_id_ps0(rd_data_req_id_ps0),
    .rd_data_ps0(rd_data_ps0),
    .rd_data_req_id_ps1(rd_data_req_id_ps1),
    .rd_data_ps1(rd_data_ps1),

    .dfi_clk_buf(clk_450)
);
endmodule
