`define __DEBUG__

module Bitmap #(
   parameter AREA_ROW = 32,
   parameter AREA_COL = 16,
   parameter ROW_ADDR_W = 5,
   parameter COL_ADDR_W = 4,
   parameter SPEED_FREQ = 50_000_000
)
(
   input                            clk,
   input                            rstn,
   input                            falling_update,// block falling signal
   output                           game_over,     // game over
   input    [ROW_ADDR_W-1:0]        mv_blk_row,    // current moving block
   input    [COL_ADDR_W-1:0]        mv_blk_col,    //             : top-left position
   input    [15:0]                  mv_blk_data,   //             : block 4x4 bitmap
   output                           mv_down_enable,//             : is still on active (enable to move down)
   input    [ROW_ADDR_W-1:0]        tst_blk_row,   // testing block
   input    [COL_ADDR_W-1:0]        tst_blk_col,   //             : top-left position
   input    [15:0]                  tst_blk_data,  //             : block 4x4 bitmap
   output                           tst_blk_overl, //             : is overlapping with current fixed blocks
   input    [ROW_ADDR_W-1:0]        r1_row,        // output channel #1
   output   [AREA_COL*2-1:0]        r1_data,       //         : data
   input    [ROW_ADDR_W-1:0]        r2_row,        // output channel #1
   output   [AREA_COL*2-1:0]        r2_data,        //         : data
   output reg [9:0]                 game_score,     // adding a game_score output
   output                           press_right_enable,
   output                           press_down_enable,
   output                           press_left_enable,
   output reg [2:0]   count
);



//==========================================================================
// bitmap content
//==========================================================================

reg [AREA_COL - 1 : 0] bitmap_h [AREA_ROW - 1 : 0];
reg [AREA_COL - 1 : 0] bitmap_l [AREA_ROW - 1 : 0];
reg [AREA_COL - 1 : 0] temp_bitmap_h [AREA_ROW - 1 : 0];

wire [AREA_COL - 1 : 0] tst_bitmap_0;
wire [AREA_COL - 1 : 0] tst_bitmap_1;
wire [AREA_COL - 1 : 0] tst_bitmap_2;
wire [AREA_COL - 1 : 0] tst_bitmap_3;
reg mv_down_enable_r;

wire [3:0] top4_row_overlap;
assign top4_row_overlap[0] = |(bitmap_l[0] & bitmap_h[0]);
assign top4_row_overlap[1] = |(bitmap_l[1] & bitmap_h[1]);
assign top4_row_overlap[2] = |(bitmap_l[2] & bitmap_h[2]);
assign top4_row_overlap[3] = |(bitmap_l[3] & bitmap_h[3]);
assign game_over = |top4_row_overlap;


`ifdef __DEBUG__
wire [AREA_COL - 1 : 0] bitmap_h0 = bitmap_h[0];
wire [AREA_COL - 1 : 0] bitmap_h1 = bitmap_h[1];
wire [AREA_COL - 1 : 0] bitmap_h2 = bitmap_h[2];
wire [AREA_COL - 1 : 0] bitmap_h3 = bitmap_h[3];
wire [AREA_COL - 1 : 0] bitmap_h24 = bitmap_h[24];
wire [AREA_COL - 1 : 0] bitmap_h25 = bitmap_h[25];
wire [AREA_COL - 1 : 0] bitmap_h26 = bitmap_h[26];
wire [AREA_COL - 1 : 0] bitmap_h27 = bitmap_h[27];
wire [AREA_COL - 1 : 0] bitmap_h28 = bitmap_h[28];
wire [AREA_COL - 1 : 0] bitmap_h29 = bitmap_h[29];
wire [AREA_COL - 1 : 0] bitmap_h30 = bitmap_h[30];
wire [AREA_COL - 1 : 0] bitmap_h31 = bitmap_h[31];

wire [AREA_COL - 1 : 0] bitmap_l0 = bitmap_l[0];
wire [AREA_COL - 1 : 0] bitmap_l1 = bitmap_l[1];
wire [AREA_COL - 1 : 0] bitmap_l2 = bitmap_l[2];
wire [AREA_COL - 1 : 0] bitmap_l3 = bitmap_l[3];
wire [AREA_COL - 1 : 0] bitmap_l10 = bitmap_l[10];
wire [AREA_COL - 1 : 0] bitmap_l11 = bitmap_l[11];
wire [AREA_COL - 1 : 0] bitmap_l12 = bitmap_l[12];
wire [AREA_COL - 1 : 0] bitmap_l13 = bitmap_l[13];
wire [AREA_COL - 1 : 0] bitmap_l20 = bitmap_l[20];
wire [AREA_COL - 1 : 0] bitmap_l21 = bitmap_l[21];
wire [AREA_COL - 1 : 0] bitmap_l22 = bitmap_l[22];
wire [AREA_COL - 1 : 0] bitmap_l23 = bitmap_l[23];
wire [AREA_COL - 1 : 0] bitmap_l28 = bitmap_l[28];
wire [AREA_COL - 1 : 0] bitmap_l29 = bitmap_l[29];
wire [AREA_COL - 1 : 0] bitmap_l30 = bitmap_l[30];
wire [AREA_COL - 1 : 0] bitmap_l31 = bitmap_l[31];
`endif



//wire [AREA_ROW-1:0] row_full_flag;
//genvar m;
//generate
//    for (m = 0; m < AREA_ROW; m = m + 1) begin: row_full
//        assign row_full_flag[m] = (temp_bitmap_h[m] == {AREA_COL{1'b1}});
//    end
//endgenerate
//
//// ͳ�Ʊ�������������
//function [2:0] calc_clear;
//    input [AREA_ROW-1:0] flag;
//    integer k;
//    begin
//        calc_clear = 0;
//        for (k = 0; k < AREA_ROW; k = k+1)
//            if (flag[k]) calc_clear = calc_clear + 1;
//    end
//endfunction

//wire [2:0] lines_cleared = calc_clear(row_full_flag);
//
//// �����ۼ�
//always @(posedge clk or negedge rstn) begin
//    if (!rstn)
//        game_score <= 0;
//    else if (falling_update) begin
//        case (lines_cleared)
//            1: game_score <= game_score + 1;
//            2: game_score <= game_score + 10;
//            3: game_score <= game_score + 66;
//            4: game_score <= game_score + 100;
//            default: game_score <= game_score;
//        endcase
//    end
//end





//==========================================================================
// fixed blocks
//==========================================================================

generate
genvar i;
for (i = 0; i < AREA_ROW; i = i+1) begin
   if (i > 0) begin 
      always @(posedge clk) begin
         if (~rstn) begin
            // for debug
            if (i < AREA_ROW - 4) 
               bitmap_h[i] <= 16'd0;
            else 
               bitmap_h[i] <= 16'hfc_3f;
         end 
         else begin
            bitmap_h[i] <= temp_bitmap_h[i];
            // TODO
         end 
      end
   end 
   else begin // when i = 0
      always @(posedge clk) begin
         if (~rstn) begin
            bitmap_h[i] <= 0;
         end 
         else begin
            bitmap_h[i] <= temp_bitmap_h[i];
            // TODO 
         end 
      end
   end 
end
endgenerate


//==========================================================================
// moving block, DONT EDIT THIS PART
//==========================================================================

generate
genvar j;
for (j = 0; j < AREA_ROW; j = j+1) begin
   always @(*) begin
      if (~rstn) begin
         bitmap_l[j] = 0;
      end 
      else begin
         if (j == mv_blk_row) begin
            bitmap_l[j] = {12'b0, mv_blk_data[3:0]} << mv_blk_col;
         end 
         else if (j == mv_blk_row + 1) begin
            bitmap_l[j] = {12'b0, mv_blk_data[7:4]} << mv_blk_col;
         end 
         else if (j == mv_blk_row + 2) begin
            bitmap_l[j] = {12'b0, mv_blk_data[11:8]} << mv_blk_col;
         end
         else if (j == mv_blk_row + 3) begin
            bitmap_l[j] = {12'b0, mv_blk_data[15:12]} << mv_blk_col;
         end
         else begin
            bitmap_l[j] = 0;
         end  
      end 
   end
end 
endgenerate


//==========================================================================
// output channel #1, DONT EDIT THIS PART
//==========================================================================

wire [AREA_COL-1:0] r1_data_h = bitmap_h[r1_row];
wire [AREA_COL-1:0] r1_data_l = bitmap_l[r1_row];

assign r1_data = {r1_data_h, r1_data_l};


//==========================================================================
// output channel #2, DONT EDIT THIS PART
//==========================================================================

reg [2*AREA_COL-1:0] r2_data_r;
assign r2_data = r2_data_r;

always @(*) begin
   r2_data_r <= {bitmap_h[r2_row], bitmap_l[r2_row]};
end 


//==========================================================================
// TODO - add your codes below           ?   
//==========================================================================

assign mv_down_enable = mv_down_enable_r;
reg [31:0] score_plus;
integer k;
integer t;
integer row;
integer row_in;

assign tst_bitmap_0={12'b0,tst_blk_data[3:0]} << tst_blk_col;
assign tst_bitmap_1={12'b0,tst_blk_data[7:4]} << tst_blk_col;
assign tst_bitmap_2={12'b0,tst_blk_data[11:8]} << tst_blk_col;
assign tst_bitmap_3={12'b0,tst_blk_data[15:12]} << tst_blk_col;

reg tst_blk_overl_h;
assign tst_blk_overl = tst_blk_overl_h;


//move block detect
always@(posedge clk or negedge rstn)begin
if (~rstn) begin
    for (k = 0; k < AREA_ROW; k = k + 1) begin
        if (k >= AREA_ROW - 4) begin
            temp_bitmap_h[k] <= 16'hfc_3f; // �ײ�4��������ǽ
        end else begin
            temp_bitmap_h[k] <= 16'd0;     // ������ȫ0����ǽ��
        end
    end
//for (t = 4; t < AREA_ROW; t = t + 1) begin
//temp_bitmap_h[k] <= 16'b0;
//end
   mv_down_enable_r <= 1'b1;
//score_plus <= 32'd0;
end 
else begin
// Update temp_bitmap_h based on the conditions
   if(mv_blk_row<6'd28)begin    
      if((bitmap_l[mv_blk_row][mv_blk_col+:4]&temp_bitmap_h[mv_blk_row+1][mv_blk_col+:4])
      ||(bitmap_l[mv_blk_row+1][mv_blk_col+:4]&temp_bitmap_h[mv_blk_row+2][mv_blk_col+:4])
      ||(bitmap_l[mv_blk_row+2][mv_blk_col+:4]&temp_bitmap_h[mv_blk_row+3][mv_blk_col+:4])
      ||(bitmap_l[mv_blk_row+3][mv_blk_col+:4]&temp_bitmap_h[mv_blk_row+4][mv_blk_col+:4])
      )begin
         mv_down_enable_r<=1'b0;  
         temp_bitmap_h[mv_blk_row][mv_blk_col+:4]<=temp_bitmap_h[mv_blk_row][mv_blk_col+:4]|bitmap_l[mv_blk_row][mv_blk_col+:4];
         temp_bitmap_h[mv_blk_row+1][mv_blk_col+:4]<=temp_bitmap_h[mv_blk_row+1][mv_blk_col+:4]|bitmap_l[mv_blk_row+1][mv_blk_col+:4];
         temp_bitmap_h[mv_blk_row+2][mv_blk_col+:4]<=temp_bitmap_h[mv_blk_row+2][mv_blk_col+:4]|bitmap_l[mv_blk_row+2][mv_blk_col+:4];
         temp_bitmap_h[mv_blk_row+3][mv_blk_col+:4]<=temp_bitmap_h[mv_blk_row+3][mv_blk_col+:4]|bitmap_l[mv_blk_row+3][mv_blk_col+:4];
      end
      else begin
   mv_down_enable_r<=1'b1;end
end

   else if(mv_blk_row>=6'd28)begin   
  
      if(bitmap_l[mv_blk_row+3]!=16'd0)begin
         mv_down_enable_r<=1'b0;
         temp_bitmap_h[mv_blk_row][mv_blk_col+:4]<=temp_bitmap_h[mv_blk_row ][mv_blk_col+:4]|bitmap_l[mv_blk_row][mv_blk_col+:4];
         temp_bitmap_h[mv_blk_row+1][mv_blk_col+:4]<=temp_bitmap_h[mv_blk_row+1][mv_blk_col+:4]|bitmap_l[mv_blk_row+1][mv_blk_col+:4];
         temp_bitmap_h[mv_blk_row+2][mv_blk_col+:4]<=temp_bitmap_h[mv_blk_row+2][mv_blk_col+:4]|bitmap_l[mv_blk_row+2][mv_blk_col+:4];
         temp_bitmap_h[mv_blk_row+3][mv_blk_col+:4]<=temp_bitmap_h[mv_blk_row+3][mv_blk_col+:4]|bitmap_l[mv_blk_row+3][mv_blk_col+:4];
      end
      else begin
         if(mv_blk_row==6'd31)begin
         mv_down_enable_r<=1'b0;end
      else if((|(bitmap_l[mv_blk_row ]&temp_bitmap_h[mv_blk_row+1]))
      ||(bitmap_l[mv_blk_row+1]&temp_bitmap_h[mv_blk_row+2])
      ||(bitmap_l[mv_blk_row+2]&temp_bitmap_h[mv_blk_row+3])
      )begin
         mv_down_enable_r<=1'b0;   
         temp_bitmap_h[mv_blk_row][mv_blk_col+:4]<=temp_bitmap_h[mv_blk_row][mv_blk_col+:4]|bitmap_l[mv_blk_row][mv_blk_col+:4];
         temp_bitmap_h[mv_blk_row+1][mv_blk_col+:4]<=temp_bitmap_h[mv_blk_row+1][mv_blk_col+:4]|bitmap_l[mv_blk_row+1][mv_blk_col+:4];
         temp_bitmap_h[mv_blk_row+2][mv_blk_col+:4]<=temp_bitmap_h[mv_blk_row+2][mv_blk_col+:4]|bitmap_l[mv_blk_row+2][mv_blk_col+:4];
         temp_bitmap_h[mv_blk_row+3][mv_blk_col+:4]<=temp_bitmap_h[mv_blk_row+3][mv_blk_col+:4]|bitmap_l[mv_blk_row+3][mv_blk_col+:4];
      end
      else begin
         mv_down_enable_r<=1'b1;
      end
   end
end
end


//always@(posedge clk or negedge rstn)begin
//    if (~rstn)begin
//    count<=3'b000;
//    end
//    if (falling_update) begin 
//        count<=3'b000;
//        for (row = 31; row >= 1; row = row - 1) begin
//            if (temp_bitmap_h[row] == 16'hFFFF) begin
//            //score_plus <= score_plus | (1 << row);
//                count<=count+3'b001;
//                    for (row_in = row; row_in >= 1; row_in = row_in - 1) begin
//                        temp_bitmap_h[row_in] <= temp_bitmap_h[row_in - 1];
//                    end
//            temp_bitmap_h[0] <= 16'h0000;
//                end
//            end
//        end
//    end
//end


reg [15:0] buffer   [31:0]; // 中间变量
reg [5:0]  cnt;

// 主同步时序逻辑
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        for (row = 0; row < 32; row = row + 1) begin
            temp_bitmap_h[row] <= 16'b0;
        end
        count <= 6'd0;
    end else if (falling_update) begin
        // 1. 初始化
        for (row = 0; row < 32; row = row + 1)
            buffer[row] = temp_bitmap_h_in[row];
        cnt = 0;

        // 2. 从下往上检测消行并搬移
        for (row = 31; row >= 0; row = row - 1) begin
            if (buffer[row] == 16'hFFFF) begin
                cnt = cnt + 1;
                // 下移：i 行以上的全部下移一行
                for (row_in = row; row_in > 0; row_in = row_in - 1) begin
                    buffer[row_in] = buffer[row_in-1];
                end
                buffer[0] = 16'b0; // 最上面补零
            end
        end

        // 3. 更新输出
        for (row= 0; row < 32; row = row + 1)
            temp_bitmap_h[row] <= buffer[row];
        count <= cnt;
    end
end





always@(posedge clk) begin
   if(tst_blk_row<AREA_ROW-3)begin
      tst_blk_overl_h<=|((|(tst_bitmap_0&bitmap_h[tst_blk_row]))    |
                       (|(tst_bitmap_1&bitmap_h[tst_blk_row+1]))  |
                       (|(tst_bitmap_2&bitmap_h[tst_blk_row+2]))  |
                       (|(tst_bitmap_3&bitmap_h[tst_blk_row+3])))  ;
   end
   else if(tst_blk_row==AREA_ROW-3)begin
      tst_blk_overl_h<=|((|(tst_bitmap_0 & bitmap_h[tst_blk_row]))    | 
                       (|(tst_bitmap_1 & bitmap_h[tst_blk_row+1]))  | 
                       (|(tst_bitmap_2 & bitmap_h[tst_blk_row+2]))  |
                       (|tst_bitmap_3                            ))  ;
   end
   else if(tst_blk_row==AREA_ROW-2)begin
      tst_blk_overl_h<=|((|(tst_bitmap_0 & bitmap_h[tst_blk_row]))    | 
                       (|(tst_bitmap_1 & bitmap_h[tst_blk_row+1]))  |
                       (|tst_bitmap_2                            )  |
                       (|tst_bitmap_3                            ))  ;
   end
   else if(tst_blk_row==AREA_ROW-1)begin
      tst_blk_overl_h<=|((|(tst_bitmap_0 & bitmap_h[tst_blk_row]))   |
                       (|tst_bitmap_1                          )   |
                       (|tst_bitmap_2                          )   |
                       (|tst_bitmap_3                          ) )  ;
   end
   else begin
      tst_blk_overl_h <= 1'b1;
   end
end





reg press_down_enable_r;
assign press_down_enable= press_down_enable_r;
reg press_left_enable_r;
assign press_left_enable= press_left_enable_r;
reg press_right_enable_r;
assign press_right_enable= press_right_enable_r;

always @(posedge clk or negedge rstn) begin
if (~rstn) begin
         press_down_enable_r<=1'b1;
         press_left_enable_r<=1'b1;
         press_right_enable_r<=1'b1;
   end
   else begin
         press_down_enable_r<=~(|((({12'b0, tst_blk_data[3:0]} << tst_blk_col) & temp_bitmap_h[tst_blk_row]) |
                      (({12'b0, tst_blk_data[7:4]} << tst_blk_col) & temp_bitmap_h[tst_blk_row+1]) |
                      (({12'b0, tst_blk_data[11:8]} << tst_blk_col) & temp_bitmap_h[tst_blk_row+2]) |
                      (({12'b0, tst_blk_data[15:12]} << tst_blk_col) & temp_bitmap_h[tst_blk_row+3])));
         press_left_enable_r<=~(|((({12'b0, mv_blk_data[3:0]} << (mv_blk_col+1))&temp_bitmap_h[mv_blk_row])|
                     (({12'b0, mv_blk_data[7:4]} << (mv_blk_col+1))&temp_bitmap_h[mv_blk_row+1])|
                     (({12'b0, mv_blk_data[11:8]} << (mv_blk_col+1))&temp_bitmap_h[mv_blk_row+2])|
                     (({12'b0, mv_blk_data[15:12]} << (mv_blk_col+1))&temp_bitmap_h[mv_blk_row+3])));      
         press_right_enable_r<=~(|((({12'b0, mv_blk_data[3:0]} << (mv_blk_col-1))&temp_bitmap_h[mv_blk_row])|
                     (({12'b0, mv_blk_data[7:4]} << (mv_blk_col-1))&temp_bitmap_h[mv_blk_row+1])|
                     (({12'b0, mv_blk_data[11:8]} << (mv_blk_col-1))&temp_bitmap_h[mv_blk_row+2])|
                     (({12'b0, mv_blk_data[15:12]} << (mv_blk_col-1))&temp_bitmap_h[mv_blk_row+3]))); 
         //tst_blk_overl_r<= ~((({12'b0, tst_blk_data[3:0]} << (tst_blk_col))&bitmap_h[tst_blk_row])|
         //            (({12'b0, tst_blk_data[7:4]} << (tst_blk_col))&bitmap_h[tst_blk_row+1])|
          //           (({12'b0, tst_blk_data[11:8]} << (tst_blk_col))&bitmap_h[tst_blk_row+2])|
         //            (({12'b0, tst_blk_data[15:12]} << (tst_blk_col))&bitmap_h[tst_blk_row+3]));   
   end
end

endmodule