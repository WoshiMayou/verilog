`timescale 1ns / 1ps

module tb_bitmap ();

//==========================================================================
// Game wrapper, including core logic
//==========================================================================
parameter AREA_ROW = 32;
parameter AREA_COL = 16;
parameter ROW_ADDR_W = 5;
parameter COL_ADDR_W = 4;

reg clk = 1'b0;
reg rstn = 1'b1;

wire game_over;
reg falling_update = 1'b0; // falling update signal

reg    [ROW_ADDR_W-1:0]        mv_blk_row = 0;   // current moving block
reg    [COL_ADDR_W-1:0]        mv_blk_col = 6;   //             : top-left position

wire mv_down_enable;
reg [15:0] mv_blk_data = {
   4'b1_1_1_1,
   4'b1_1_1_1,
   4'b1_1_1_1,
   4'b1_1_1_1
};

Bitmap uut (
   .clk(clk),
   .rstn(rstn),
   .falling_update(falling_update),
   .game_over(game_over),
   .mv_blk_row(mv_blk_row),
   .mv_blk_col(mv_blk_col),
   .mv_blk_data(mv_blk_data),
   .mv_down_enable(mv_down_enable)
);

initial begin
   
   rstn = 1;
   #10;
   rstn = 0;
   #10;
   rstn = 1;
   #10;

   #1000;
   $finish;
end

always #1 clk = ~clk;

always @(posedge clk or negedge rstn) begin
    if (~rstn) begin
        falling_update <= 1'b0;
        mv_blk_row <= 0;
    end 
    else if (falling_update) begin 
        mv_blk_row <= mv_down_enable ? (mv_blk_row + 1) : 0;
        falling_update <= game_over ? 1'b0 : 1'b1;
    end 
    else begin
        falling_update <= game_over ? 1'b0 : 1'b1;
    end
end 

// 输出波形文件
initial begin
    $dumpfile("tb_bitmap.wave");
    $dumpvars;
    $display("save to tb_bitmap.wave");
end 

endmodule