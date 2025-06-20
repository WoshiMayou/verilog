module Top #(
    parameter CLK_FREQ = 32'd50_000_000
) (
    input             clk,
    input             rstn,
    input      [6:0]  keys, 
    output            uart_tx,
    output reg [7:0]  led,
    output     [3:0]  seg_sel,
    output     [7:0]  seg_data,
    // HDMI RELATE SIGNALS
    input             clk_27M          ,  
    output            tmds_clk_p       ,  
    output            tmds_clk_n       ,  
    output [2:0]      tmds_data_p      , 
    output [2:0]      tmds_data_n      ,
    output            iic_scl          ,
    inout             iic_sda          , 
    output            rstn_out 
);

//==========================================================================
// internal signals
//==========================================================================

parameter AREA_ROW = 32;
parameter AREA_COL = 16;
parameter ROW_ADDR_W = 5;
parameter COL_ADDR_W = 4;

wire [ROW_ADDR_W-1:0] hdmi_bitmap_row;
wire [AREA_COL*2-1:0] hdmi_bitmap_data;

wire [ROW_ADDR_W-1:0] uart_bitmap_row;
wire [AREA_COL*2-1:0] uart_bitmap_data;


//==========================================================================
// PLL, generate 148.5M & 10M clk
//==========================================================================
wire pll_lock0;
wire pll_lock1;
wire pll_lock = pll_lock0 & pll_lock1;
wire clk_10m;
wire pixclk;
wire pixclk_5x;

pll_0 u_pll_0(
  .clkin1     (clk        ),//50MHz
  .clkout0    (clk_10m    ),//10MHz
  .pll_lock   (pll_lock0  )
);

pll_1 u_pll_1 (
  .clkin1     (clk_27M    ),// input 27M
  .pll_lock   (pll_lock1  ),// output
  .clkout0    (pixclk     ),// output 74.25M
  .clkout1    (pixclk_5x  ) // output 371.25M
);

//==========================================================================
// HDMI Wrapper, display output
//==========================================================================
wire hdmi_init_over;

HdmiWrapper u_hdmi (
   .rstn(pll_lock)            , // pll lock
   .cfg_clk(clk_10m)          , // 10Mhz
   .iic_scl(iic_scl)          ,
   .iic_sda(iic_sda)          ,
   .init_over(hdmi_init_over) ,
   .rstn_out(rstn_out)        ,
                                // HDMI output 
   .pix_clk(pixclk)           , // input
   .pix_clk_5x(pixclk_5x)     , // input                     
   .tmds_clk_p(tmds_clk_p)    , // output
   .tmds_clk_n(tmds_clk_n)    , // output
   .tmds_data_p(tmds_data_p)  , // output [2:0]
   .tmds_data_n(tmds_data_n)  , // output [2:0]
   .bitmap_row(hdmi_bitmap_row),
   .bitmap_data(hdmi_bitmap_data)
);


//==========================================================================
// Key debounce & filter
//==========================================================================

wire [6:0] keys_stable;

reg  [6:0] keys_d1 = 7'h7f; // keys_stable with 1 clock delay 

wire pressed_left           = keys_d1[1] & (~keys_stable[1]);
wire pressed_right          = keys_d1[0] & (~keys_stable[0]);
wire pressed_down           = keys_d1[2] & (~keys_stable[2]);
wire pressed_up             = keys_d1[3] & (~keys_stable[3]);
wire pressed_switch         = keys_d1[4] & (~keys_stable[4]);
wire pressed_fall_down      = keys_d1[5] & (~keys_stable[5]);
wire pressed_reserverd      = keys_d1[6] & (~keys_stable[6]);

//wire [2:0] count;
KeyDebounce #(
   .CLK_FREQ(CLK_FREQ),
   .KEY_CNT(7)
) u_key (
   .clk(clk), 
   .keys(keys[6:0]),
   .keys_stable(keys_stable)
);

always @(posedge clk) begin
   keys_d1 <= keys_stable;
end 


//==========================================================================
// Game wrapper, including core logic
//==========================================================================
wire game_over;
wire [9:0] game_score;

Wrapper #(
   .AREA_ROW(AREA_ROW),
   .AREA_COL(AREA_COL),
   .ROW_ADDR_W(ROW_ADDR_W),
   .COL_ADDR_W(COL_ADDR_W)
) u_wrapper (
   .clk(clk),
   .rstn(rstn),
   .pressed_left(pressed_left),     // key event
   .pressed_right(pressed_right),   //
   .pressed_down(pressed_down),     //
   .pressed_up(pressed_up),         //
   .pressed_switch(pressed_switch),
   .pressed_fall_down(pressed_fall_down),
   .pressed_reserverd(pressed_reserverd), 
   .r1_row(hdmi_bitmap_row),  // output channel #1
   .r1_data(hdmi_bitmap_data),//
   .r2_row(uart_bitmap_row),  // output channel #2
   .r2_data(uart_bitmap_data),//
   .game_score(game_score),
   .game_over(game_over)
);


//==========================================================================
// uart wrapper, bitmap data send to PC
//==========================================================================

UartWrapper #(
   .AREA_ROW(AREA_ROW),
   .AREA_COL(AREA_COL),
   .ROW_ADDR_W(ROW_ADDR_W),
   .COL_ADDR_W(COL_ADDR_W),
   .CLK_FREQ(CLK_FREQ)
) u_uart (
   .clk(clk),
   .rstn(rstn),
   .uart_tx(uart_tx),
   .bitmap_row(uart_bitmap_row), 
   .bitmap_data(uart_bitmap_data)
);


//==========================================================================
// seg display for game score
//==========================================================================

SegWrapper #(
   .CLK_FREQ(CLK_FREQ)
) u_seg (
   .clk(clk),
   .rstn(rstn),
   .game_score(game_score),
   .seg_sel(seg_sel), 
   .seg_data(seg_data)
);


//==========================================================================
// LED as status
//==========================================================================

reg [25:0] clk_cnt = 26'd0; 
wire game_running = (clk_cnt == (CLK_FREQ-1)) ? 1'b1 : 1'b0;

always @(posedge clk) begin
   if (~rstn) begin
      clk_cnt <= 26'd0;
   end 
   else if (clk_cnt == (CLK_FREQ-1)) begin
      clk_cnt <= 26'd0;
   end 
   else begin
      clk_cnt <= clk_cnt + 1'b1;
   end 
end

always @(posedge clk) begin 
   if (~rstn) begin
      led[7:0] <= 8'h01;
   end 
   else if (~(&keys_stable)) begin
      led[7:0] <= {1'b0, ~keys_stable};
   end 
   else if (game_running) begin
      if (game_over) begin
         led <= (led == 8'hff) ? 8'h00 : 8'hff;
      end 
      else begin
         led[7:0] <= {led[6:0], led[7]};
      end 
   end 
end 

endmodule