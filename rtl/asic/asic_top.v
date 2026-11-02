// Logical macro top for the ASIC implementation.
// These are core terminals, not physical package pads.

module asic_top (
  input  wire        clk_i,
  input  wire        rst_ni,
  input  wire [3:0]  buttons_i,
  output wire [3:0]  leds_o,
  output wire [6:0]  seg1_o,
  output wire [6:0]  seg2_o,
  input  wire        spi_sclk_i,
  input  wire        spi_mosi_i,
  input  wire        spi_cs_ni,
  output wire        spi_miso_o
);

`ifdef POCHOCO_UNIFIED_MEMORY
  localparam integer UseUnifiedMemory = 1;
`else
  localparam integer UseUnifiedMemory = 0;
`endif

  pochoco_soc_asic #(
    .UseUnifiedMemory(UseUnifiedMemory)
  ) u_soc (
    .clk_i       (clk_i),
    .rst_ni      (rst_ni),
    .leds_o      (leds_o),
    .buttons_i   (buttons_i),
    .seg1_o      (seg1_o),
    .seg2_o      (seg2_o),
    .spi_sclk_i  (spi_sclk_i),
    .spi_mosi_i  (spi_mosi_i),
    .spi_cs_ni   (spi_cs_ni),
    .spi_miso_o  (spi_miso_o)
  );

endmodule
