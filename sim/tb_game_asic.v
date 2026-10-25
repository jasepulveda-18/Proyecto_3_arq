`timescale 1ns/1ps

module tb_game_asic;
  reg clk_i = 1'b0;
  reg rst_ni = 1'b0;
  reg [3:0] buttons_i = 4'b0;
  wire [3:0] leds_o;
  wire [6:0] seg1_o;
  wire [6:0] seg2_o;
  wire spi_miso_o;

  integer cycle = 0;
  integer target_led;
  integer wrong_led;

  asic_top dut (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .buttons_i(buttons_i),
    .leds_o(leds_o),
    .seg1_o(seg1_o),
    .seg2_o(seg2_o),
    .spi_sclk_i(1'b0),
    .spi_mosi_i(1'b0),
    .spi_cs_ni(1'b1),
    .spi_miso_o(spi_miso_o)
  );

  always #50 clk_i = ~clk_i;
  always @(posedge clk_i) cycle <= cycle + 1;

  task wait_leds;
    input [3:0] expected;
    input integer limit;
    integer waited;
    begin
      waited = 0;
      while ((leds_o !== expected) && (waited < limit)) begin
        @(posedge clk_i);
        waited = waited + 1;
      end
      if (leds_o !== expected) begin
        $display("FAIL wait_leds expected=%h got=%h cycle=%0d", expected, leds_o, cycle);
        $finish_and_return(1);
      end
    end
  endtask

  task wait_target;
    input integer limit;
    integer waited;
    begin
      waited = 0;
      while (!((leds_o == 4'b0001) || (leds_o == 4'b0010) ||
               (leds_o == 4'b0100) || (leds_o == 4'b1000)) &&
             (waited < limit)) begin
        @(posedge clk_i);
        waited = waited + 1;
      end
      if (waited == limit) begin
        $display("FAIL target timeout cycle=%0d", cycle);
        $finish_and_return(1);
      end
    end
  endtask

  task press_button;
    input [3:0] value;
    input integer held_cycles;
    integer i;
    begin
      buttons_i = value;
      for (i = 0; i < held_cycles; i = i + 1)
        @(posedge clk_i);
      buttons_i = 4'b0;
    end
  endtask

  initial begin
    repeat (5) @(posedge clk_i);
    rst_ni = 1'b1;

    repeat (30) @(posedge clk_i);
    if ((seg1_o !== 7'b1111111) || (seg2_o !== 7'b1111111)) begin
      $display("FAIL startup display cycle=%0d seg=%b_%b", cycle, seg1_o, seg2_o);
      $finish_and_return(1);
    end
    $display("EVENT startup_88 cycle=%0d", cycle);
    press_button(4'b0001, 16);

    wait_leds(4'b1111, 300);
    $display("EVENT first_round cycle=%0d", cycle);
    wait_target(400);
    target_led = leds_o;
    wrong_led = (leds_o == 4'b0001) ? 4'b0010 : 4'b0001;
    $display("EVENT first_target cycle=%0d led=%h", cycle, target_led);
    press_button(wrong_led[3:0], 16);
    wait_leds(4'b0000, 200);
    if ((seg1_o !== 7'b1111001) || (seg2_o !== 7'b1111001)) begin
      $display("FAIL error display cycle=%0d seg=%b_%b", cycle, seg1_o, seg2_o);
      $finish_and_return(1);
    end
    $display("EVENT wrong_detected cycle=%0d", cycle);

    wait_leds(4'b1111, 400);
    $display("EVENT round_restarted cycle=%0d", cycle);
    wait_target(400);
    target_led = leds_o;
    $display("EVENT second_target cycle=%0d led=%h", cycle, target_led);
    repeat (24) @(posedge clk_i);
    press_button(target_led[3:0], 16);

    wait_leds(4'b0000, 300);
    if ((seg1_o === 7'b1111001) && (seg2_o === 7'b1111001)) begin
      $display("FAIL correct press treated as wrong cycle=%0d", cycle);
      $finish_and_return(1);
    end
    $display("EVENT correct_detected cycle=%0d seg=%b_%b", cycle, seg1_o, seg2_o);
    $display("PASS functional_game");
    $finish;
  end

  initial begin
    #2000000;
    $display("FAIL global timeout");
    $finish_and_return(1);
  end
endmodule
