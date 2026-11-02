// ASIC implementation of Espino's RV32E register file.
// The FPGA version uses SB_RAM40_4K primitives; this version uses generic
// flip-flops and preserves the original one-cycle synchronous read latency.

module espino_register_file (
  input  wire        clk_i,
  input  wire        rst_ni,
  input  wire [3:0]  raddr_a_i,
  output reg  [31:0] rdata_a_o,
  input  wire [3:0]  raddr_b_i,
  output reg  [31:0] rdata_b_o,
  input  wire [3:0]  waddr_i,
  input  wire [31:0] wdata_i,
  input  wire        we_i
);

  reg [31:0] registers [1:15];
  integer i;

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rdata_a_o <= 32'b0;
      rdata_b_o <= 32'b0;
      for (i = 1; i < 16; i = i + 1)
        registers[i] <= 32'b0;
    end else begin
      if (we_i && (waddr_i != 4'd0))
        registers[waddr_i] <= wdata_i;

      rdata_a_o <= (raddr_a_i == 4'd0) ? 32'b0 : registers[raddr_a_i];
      rdata_b_o <= (raddr_b_i == 4'd0) ? 32'b0 : registers[raddr_b_i];
    end
  end

endmodule
