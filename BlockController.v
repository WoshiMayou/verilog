module BlockController #(
   parameter AREA_ROW = 32,
   parameter AREA_COL = 16,
   parameter ROW_ADDR_W = 5,
   parameter COL_ADDR_W = 4
) (
   input                            clk,
   input                            rstn,
   input                            pressed_left,  // key event
   input                            press_left_enable,
   input                            pressed_right, //
   input                            press_right_enable,
   input                            pressed_up,    //
   input                            pressed_down,  //
   input                            press_down_enable,
   input                            pressed_switch,
   input                            pressed_fall_down,
   input                            pressed_reserverd, 
   output                           falling_update,// block falling signal 
   output   [ROW_ADDR_W-1:0]        mv_blk_row,    // current moving block
   output   [COL_ADDR_W-1:0]        mv_blk_col,    //             : top-left position
   output   [15:0]                  mv_blk_data,   //             : block 4x4 bitmap
   input                            mv_down_enable,//             : feedback: is still on active (enable to move down)
   output   [ROW_ADDR_W-1:0]        tst_blk_row,   // testing block
   output   [COL_ADDR_W-1:0]        tst_blk_col,   //             : top-left position
   output   [15:0]                  tst_blk_data,  //             : block 4x4 bitmap
   input                            tst_blk_overl  //             : feedback: is overlapping with current fixed blocks
);

//==========================================================================
// define basic block, 4 x 4
//==========================================================================

// 田字
reg [15:0] BLK_0 = {
   4'b0_0_0_0,
   4'b0_1_1_0,
   4'b0_1_1_0,
   4'b0_0_0_0
};

// 长条
reg [15:0] BLK_1 = {
   4'b0_0_0_0,
   4'b0_0_0_0,
   4'b0_0_0_0,
   4'b1_1_1_1
};

// 长条
reg [15:0] BLK_2 = {
   4'b0_0_0_0,
   4'b0_0_0_0,
   4'b1_1_1_1,
   4'b1_1_1_1
};

// 田字
reg [15:0] BLK_3 = {
   4'b1_1_1_1,
   4'b1_1_1_1,
   4'b1_1_1_1,
   4'b1_1_1_1
};

// 口字
reg [15:0] BLK_4 = {
   4'b1_1_1_1,
   4'b1_0_0_1,
   4'b1_0_0_1,
   4'b1_1_1_1
};

//==========================================================================
// generate next block, 4 x 4
//==========================================================================

reg [2:0] nxt_blk_idx = 3'd4;
reg [15:0] nxt_blk_data;


always @(posedge clk) begin
    if (~rstn) begin
        nxt_blk_idx <= 3'd4;
    end else begin
        nxt_blk_idx <= {nxt_blk_idx[1:0], nxt_blk_idx[2] ^ nxt_blk_idx[1]};
    end
end

always @(*) begin
   case(nxt_blk_idx)
      3'd0: nxt_blk_data = BLK_0;
      3'd1: nxt_blk_data = BLK_1;
      3'd2: nxt_blk_data = BLK_2;
      3'd3: nxt_blk_data = BLK_3;
      3'd4: nxt_blk_data = BLK_4;
      3'd5: nxt_blk_data = BLK_0;
      3'd6: nxt_blk_data = BLK_1;
      3'd7: nxt_blk_data = BLK_2;
      default: nxt_blk_data = BLK_0;
   endcase
end 


//==========================================================================
// test block relate codes, TODO
//==========================================================================

reg [ROW_ADDR_W-1:0] tst_blk_row_r;
reg [COL_ADDR_W-1:0] tst_blk_col_r;
reg [15:0] tst_blk_data_r;

assign tst_blk_row = tst_blk_row_r;
assign tst_blk_col = tst_blk_col_r;
assign tst_blk_data = tst_blk_data_r;

always @(posedge clk) begin
   tst_blk_row_r= mv_blk_row_r+1;
   tst_blk_col_r = mv_blk_col_r;
   tst_blk_data_r <= mv_blk_data_r;

end 

reg tst_blk_tocheck = 1'b0; 


//==========================================================================
// update current block, based on: falling update, pressed keys
//==========================================================================

reg falling_update_r = 1'b0; // falling request signal
reg [ROW_ADDR_W-1:0] mv_blk_row_r;
reg [COL_ADDR_W-1:0] mv_blk_col_r;
reg [15:0] mv_blk_data_r;

assign falling_update = falling_update_r;
assign mv_blk_row = mv_blk_row_r;
assign mv_blk_col = mv_blk_col_r;
assign mv_blk_data = mv_blk_data_r;




always @(posedge clk) begin
   if (~rstn) begin
      // reset falling request
      falling_update_r <= 1'b0;
      // reset current moving block
      mv_blk_row_r <= 0;
      mv_blk_col_r <= (AREA_COL >> 1) - 2;
      mv_blk_data_r <= nxt_blk_data;
   end 
   // 1) when current block falling down
   else if (falling_update) begin
      // case 1a) is collide (not active)
      if (~mv_down_enable) begin
         mv_blk_row_r <= 0;
         mv_blk_col_r <= (AREA_COL >> 1) - 2;
         mv_blk_data_r <= nxt_blk_data;
         falling_update_r <= 1'b0;
      end 
      else if (mv_blk_row_r == {ROW_ADDR_W{1'b1}}) begin
         falling_update_r <= 1'b0;
      end 
      // case 1b) is still active
      else begin
         mv_blk_row_r <= mv_blk_row_r + 1;
         // Note - need to consider if fall to botoom, and stop
         falling_update_r <= (mv_blk_row_r == {ROW_ADDR_W{1'b1}}) ? 1'b0: 1'b1; 
      end 
   end 
   // 2) when has pressed keys - down to bottom
   else if (pressed_fall_down) begin
      falling_update_r <= 1'b1;
   end 
   // 3) when has pressed keys - UP (rotate)
   else if (pressed_up) begin
      // TODO

         // rotate 90 degrees clockwise
         mv_blk_data_r <= {
            mv_blk_data_r[12],mv_blk_data_r[8],mv_blk_data_r[4],mv_blk_data_r[0],
            mv_blk_data_r[13],mv_blk_data_r[9],mv_blk_data_r[5],mv_blk_data_r[1],
            mv_blk_data_r[14],mv_blk_data_r[10],mv_blk_data_r[6],mv_blk_data_r[2],
            mv_blk_data_r[15],mv_blk_data_r[11],mv_blk_data_r[7],mv_blk_data_r[3]

         };




   end 
   // 4) when has pressed keys - DOWN (1 step)
   else if (pressed_down) begin
      // TODO
         if(press_down_enable)begin
            mv_blk_row_r <= mv_blk_row_r + 1;
         end
   end 
   // 5) when has pressed keys - LEFT
   else if (pressed_left) begin
      // TODO
      if(press_left_enable)begin
         if(mv_blk_col_r>0)
            mv_blk_col_r <= mv_blk_col_r - 1;
      end 
   end 
   // 6) when has pressed keys - RIGHT
   else if (pressed_right) begin
      // TODO
      if(press_right_enable)begin
         if(mv_blk_col_r<(AREA_COL - 3))
            mv_blk_col_r <= mv_blk_col_r + 1;
      end
   end 
   // 7) when has pressed keys - active black switch
   else if (pressed_switch) begin
      mv_blk_data_r <= nxt_blk_data;
   end
end

endmodule