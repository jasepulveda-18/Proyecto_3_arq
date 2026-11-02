// Reduced data RAM for the ROM-based ASIC memory architecture.
// The current game performs no accesses to data RAM, so one word is the
// smallest implemented memory while preserving the processor interface.

module pochoco_data_ram_ff #(
  parameter integer NumWords = 1
) (
  input  wire        clk_i,
  input  wire        rst_ni,
  input  wire        req_i,
  input  wire        we_i,
  input  wire [3:0]  be_i,
  input  wire [31:0] addr_i,
  input  wire [31:0] wdata_i,
  output reg  [31:0] rdata_o
);

  localparam integer AddrW = (NumWords <= 1) ? 1 : $clog2(NumWords);
  reg [31:0] mem [0:NumWords-1];
  wire [AddrW-1:0] word_addr = (NumWords <= 1) ? {AddrW{1'b0}} :
                                                   addr_i[AddrW+1:2];
  integer i;

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rdata_o <= 32'b0;
      for (i = 0; i < NumWords; i = i + 1)
        mem[i] <= 32'b0;
    end else if (req_i) begin
      if (we_i) begin
        if (be_i[0]) mem[word_addr][7:0]   <= wdata_i[7:0];
        if (be_i[1]) mem[word_addr][15:8]  <= wdata_i[15:8];
        if (be_i[2]) mem[word_addr][23:16] <= wdata_i[23:16];
        if (be_i[3]) mem[word_addr][31:24] <= wdata_i[31:24];
      end
      rdata_o <= mem[word_addr];
    end
  end

endmodule
