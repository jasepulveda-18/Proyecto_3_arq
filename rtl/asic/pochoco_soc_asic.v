// ASIC-oriented Pochoco SoC.
// It has an explicit external reset and selects either a generated
// combinational ROM plus reduced RAM, or a generated unified FF memory.

module pochoco_soc_asic #(
  parameter integer UseUnifiedMemory = 0
) (
  input  wire        clk_i,
  input  wire        rst_ni,
  output wire [3:0]  leds_o,
  input  wire [3:0]  buttons_i,
  output wire [6:0]  seg1_o,
  output wire [6:0]  seg2_o,
  input  wire        spi_sclk_i,
  input  wire        spi_mosi_i,
  input  wire        spi_cs_ni,
  output wire        spi_miso_o
);

  wire        instr_req;
  wire [31:0] instr_addr;
  wire [31:0] instr_rdata;

  wire        data_req;
  wire        data_we;
  wire [3:0]  data_be;
  wire [31:0] data_addr;
  wire [31:0] data_wdata;
  wire [31:0] data_rdata;

  espino_core #(.BootAddr(32'h0000_0000)) u_core (
    .clk_i         (clk_i),
    .rst_ni        (rst_ni),
    .instr_req_o   (instr_req),
    .instr_addr_o  (instr_addr),
    .instr_rdata_i (instr_rdata),
    .data_req_o    (data_req),
    .data_we_o     (data_we),
    .data_be_o     (data_be),
    .data_addr_o   (data_addr),
    .data_wdata_o  (data_wdata),
    .data_rdata_i  (data_rdata)
  );

  wire is_mmio = data_addr[31];
  wire per_sel = is_mmio & ~data_addr[16];
  wire spi_sel = is_mmio &  data_addr[16];
  wire memory_data_req = data_req & ~is_mmio;
  wire per_req = data_req & per_sel;
  wire spi_req = data_req & spi_sel;

  wire [31:0] memory_data_rdata;
  wire [31:0] per_rdata;
  wire [31:0] spi_rdata;

  reg rd_is_per;
  reg rd_is_spi;
  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rd_is_per <= 1'b0;
      rd_is_spi <= 1'b0;
    end else if (data_req & ~data_we) begin
      rd_is_per <= per_sel;
      rd_is_spi <= spi_sel;
    end
  end

  assign data_rdata = rd_is_per ? per_rdata :
                      rd_is_spi ? spi_rdata : memory_data_rdata;

  generate
    if (UseUnifiedMemory != 0) begin : gen_unified_memory
      pochoco_unified_ff_memory u_memory (
        .clk_i     (clk_i),
        .rst_ni    (rst_ni),
        .a_req_i   (instr_req),
        .a_addr_i  (instr_addr),
        .a_rdata_o (instr_rdata),
        .b_req_i   (memory_data_req),
        .b_we_i    (data_we),
        .b_be_i    (data_be),
        .b_addr_i  (data_addr),
        .b_wdata_i (data_wdata),
        .b_rdata_o (memory_data_rdata)
      );
    end else begin : gen_rom_and_ram
      wire [31:0] rom_word;
      reg  [31:0] rom_rdata_q;

      pochoco_game_rom u_instruction_rom (
        .word_addr_i (instr_addr[9:2]),
        .rdata_o     (rom_word)
      );

      always @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)       rom_rdata_q <= 32'h00000013;
        else if (instr_req) rom_rdata_q <= rom_word;
      end
      assign instr_rdata = rom_rdata_q;

      pochoco_data_ram_ff #(.NumWords(1)) u_data_ram (
        .clk_i   (clk_i),
        .rst_ni  (rst_ni),
        .req_i   (memory_data_req),
        .we_i    (data_we),
        .be_i    (data_be),
        .addr_i  (data_addr),
        .wdata_i (data_wdata),
        .rdata_o (memory_data_rdata)
      );
    end
  endgenerate

  pochoco_periph u_periph (
    .clk_i   (clk_i),
    .rst_ni  (rst_ni),
    .sel_i   (per_sel),
    .req_i   (per_req),
    .we_i    (data_we),
    .addr_i  (data_addr[7:0]),
    .wdata_i (data_wdata),
    .rdata_o (per_rdata),
    .leds_o  (leds_o),
    .btn_i   (buttons_i),
    .seg1_o  (seg1_o),
    .seg2_o  (seg2_o)
  );

  pochoco_spi_slave u_spi (
    .clk_i      (clk_i),
    .rst_ni     (rst_ni),
    .sel_i      (spi_sel),
    .req_i      (spi_req),
    .we_i       (data_we),
    .addr_i     (data_addr[7:0]),
    .wdata_i    (data_wdata),
    .rdata_o    (spi_rdata),
    .spi_sclk_i (spi_sclk_i),
    .spi_mosi_i (spi_mosi_i),
    .spi_cs_n_i (spi_cs_ni),
    .spi_miso_o (spi_miso_o)
  );

endmodule
