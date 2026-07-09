`timescale 1ps / 1ps

module dual_port_ram #(
    parameter DATA_WIDTH=256,
    parameter ADDR_WIDTH=32
)(
    input [(DATA_WIDTH-1):0] data_in,
    input [(ADDR_WIDTH-1):0] read_addr_0, read_addr_1, write_addr,
    input wr_en, clk,
    output [(DATA_WIDTH-1):0] data_out_0, data_out_1
);

(* rw_addr_collision = "no" *)(* ram_style = "block" *) reg [DATA_WIDTH-1:0] ram[0:2**ADDR_WIDTH-1];
reg [ADDR_WIDTH-1:0] read_addr_reg_0,  read_addr_reg_1;

always @ (posedge clk) begin
    read_addr_reg_0 <= read_addr_0;
    read_addr_reg_1 <= read_addr_1;
    if (wr_en) begin
        ram[write_addr] <= data_in;
    end
end

assign data_out_0 = ram[read_addr_reg_0];
assign data_out_1 = ram[read_addr_reg_1];

endmodule