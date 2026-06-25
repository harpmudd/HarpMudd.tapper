// mf_pllbase.v - PLL wrapper for Tapper (MCR3) Pocket core
// 74.25 MHz in -> 40 MHz (clk_sys) + 10 MHz (clk_vid) + 10 MHz 90 deg (clk_vid_90)
`timescale 1 ps / 1 ps
module mf_pllbase (
    input  wire  refclk,
    input  wire  rst,
    output wire  outclk_0,  // 40.000 MHz - mcr3.clock_40
    output wire  outclk_1,  // 10.000 MHz - pixel clock
    output wire  outclk_2,  // 10.000 MHz 90 deg - APF DDR pixel clock
    output wire  locked
);

mf_pllbase_0002 mf_pllbase_inst (
    .refclk   (refclk),
    .rst      (rst),
    .outclk_0 (outclk_0),
    .outclk_1 (outclk_1),
    .outclk_2 (outclk_2),
    .locked   (locked)
);

endmodule
