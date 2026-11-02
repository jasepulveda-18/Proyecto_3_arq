// Free-running cycle counter shared by the FPGA and ASIC implementations.
// Keeping it as a separate module makes its area traceable after synthesis.

module pochoco_cycle_counter (
  input  wire        clk_i,
  input  wire        rst_ni,
  output reg  [31:0] count_o
);

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) count_o <= 32'b0;
    else         count_o <= count_o + 32'd1;
  end

endmodule
