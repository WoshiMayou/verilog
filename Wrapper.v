//`include "Bitmap.v"

module Wrapper #(
   parameter AREA_ROW = 32,
   parameter AREA_COL = 16,
   parameter ROW_ADDR_W = 5,
   parameter COL_ADDR_W = 4
) (
   input                            clk,
   input                            rstn,
   input                            pressed_left,  // key event
   input                            pressed_right, //
   input                            pressed_up,    //
   input                            pressed_down,  //
   input                            pressed_switch, 
   input                            pressed_fall_down,
   input                            pressed_reserverd, 
   input    [ROW_ADDR_W-1:0]        r1_row,        // output channel #1
   output   [AREA_COL*2-1:0]        r1_data,       //         : data
   input    [ROW_ADDR_W-1:0]        r2_row,        // output channel #1
   output   [AREA_COL*2-1:0]        r2_data,       //         : data
   output                           game_over,
   output   [9:0]                   game_score,
   output press_down_enable,
   output press_right_enable,
   output press_left_enable,
   output [2:0]cancel_number 


);


//==========================================================================
// wire and reg in the module
//==========================================================================

wire                            falling_update;

wire    [ROW_ADDR_W-1:0]        mv_blk_row;    // current moving block
wire    [COL_ADDR_W-1:0]        mv_blk_col;    //             : top-left position
wire    [15:0]                  mv_blk_data;   //             : block 4x4 bitmap
wire                            mv_down_enable;    //             : is still on active
wire    [ROW_ADDR_W-1:0]        tst_blk_row;    // testing block
wire    [COL_ADDR_W-1:0]        tst_blk_col;    //             : top-left position
wire    [15:0]                  tst_blk_data;   //             : block 4x4 bitmap
wire                            tst_blk_overl;  // 
 

//==========================================================================
// game score
//==========================================================================
reg [9:0] game_score_r ; //game_score already defined in bitmap
wire [2:0] count;

assign game_score = game_score_r;

 //TODO - add your logic

always@(posedge clk or negedge rstn)
begin

   if(rstn == 1'b0) begin
      game_score_r <=10'd0;

   end 
   else if (game_score_r<100) begin
      if(count==3'b001)
          game_score_r <= game_score_r + 10'd1;
      else if(count==3'b010)
          game_score_r <= game_score_r + 10'd10;
      else if (count==3'b011)
          game_score_r <= game_score_r + 10'd66;
      else if (count==3'b100)
          game_score_r <= game_score_r + 10'd100;
//if(game_score_r >= 100)
//      game_over_r<=1;
 


    end
end

//==========================================================================
// connnected sub-modules
//==========================================================================

Bitmap #(
   .AREA_ROW(AREA_ROW),
   .AREA_COL(AREA_COL),
   .ROW_ADDR_W(ROW_ADDR_W),
   .COL_ADDR_W(COL_ADDR_W)
) u_bitmap (
   .clk(clk),
   .rstn(rstn),
   .falling_update(falling_update),
   .game_over(game_over),
   .mv_blk_row(mv_blk_row),
   .mv_blk_col(mv_blk_col),
   .mv_blk_data(mv_blk_data),
   .mv_down_enable(mv_down_enable),
   .tst_blk_row(tst_blk_row),
   .tst_blk_col(tst_blk_col),
   .tst_blk_data(tst_blk_data),
   .tst_blk_overl(tst_blk_overl),
   .r1_row(r1_row),
   .r1_data(r1_data),
   .r2_row(r2_row),
   .r2_data(r2_data),
   .press_down_enable(press_down_enable), 
   .press_right_enable(press_right_enable),
   .press_left_enable(press_left_enable),
   .game_score(game_score)
   //.count(count)

);


BlockController #(
   .AREA_ROW(AREA_ROW),
   .AREA_COL(AREA_COL),
   .ROW_ADDR_W(ROW_ADDR_W),
   .COL_ADDR_W(COL_ADDR_W)
) u_block_ctrl (
   .clk(clk),
   .rstn(rstn),
   .pressed_left(pressed_left),
   .pressed_right(pressed_right),
   .pressed_up(pressed_up),
   .pressed_down(pressed_down),
   .pressed_switch(pressed_switch),
   .pressed_fall_down(pressed_fall_down),
   .pressed_reserverd(pressed_reserverd),
   .falling_update(falling_update),
   .mv_blk_row(mv_blk_row),
   .mv_blk_col(mv_blk_col),
   .mv_blk_data(mv_blk_data),
   .mv_down_enable(mv_down_enable),
   .tst_blk_row(tst_blk_row),
   .tst_blk_col(tst_blk_col),
   .tst_blk_data(tst_blk_data),
   .tst_blk_overl(tst_blk_overl),
   .press_left_enable(press_left_enable),
   .press_right_enable(press_right_enable),
   .press_down_enable(press_down_enable)


);

endmodule
