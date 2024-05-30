`timescale 1ps / 1ps

module block_ram #(
    parameter DATA_WIDTH=256,
    parameter ADDR_WIDTH=32
)(
    input multiple_write,
    input [(DATA_WIDTH-1):0] data_in [0:2],
    input [(ADDR_WIDTH-1):0] read_addr, write_addr,
    input wr_en, clk,
    output [(DATA_WIDTH-1):0] data_out
);

/*(* rw_addr_collision = "yes" *)*/(* ram_style = "distributed" *) reg [DATA_WIDTH-1:0] ram[0:2**ADDR_WIDTH-1];
reg [ADDR_WIDTH-1:0] read_addr_reg;

always @ (posedge clk) begin
    read_addr_reg <= read_addr;
    if (wr_en) begin
        ram[write_addr] <= data_in[0];
        if (multiple_write) begin
            ram[write_addr+1'b1] <= data_in[1];
            ram[write_addr+2'b10] <= data_in[2];
        end
    end
end

assign data_out = ram[read_addr_reg];

endmodule