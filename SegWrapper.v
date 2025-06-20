
`define SEG_SEL_NULL  4'b0000
`define SEG_SEL_0     4'b0001
`define SEG_SEL_1     4'b0010
`define SEG_SEL_2     4'b0100
`define SEG_SEL_3     4'b1000

// `define SEG_FLASH_DUR 26'd49_999

module SegWrapper #(
   parameter CLK_FREQ = 50_000_000,
   parameter SEG_FLASH_DUR = 49_999
) (
   input                            clk,
   input                            rstn,
   input      [9:0]                 game_score,
   output     [3:0]                 seg_sel,
   output     [7:0]                 seg_data
);


// TODO - NEED TO remove following codes, replaced by your codes
wire[3:0] seg_num_0=game_score/1000;
wire[3:0] seg_num_1=(game_score%1000)/100;
wire[3:0] seg_num_2=(game_score%100)/10; 
wire[3:0] seg_num_3=game_score%10;

reg [15:0] seg_nums; // ÿλ���ֹ�4λ
reg [1:0]  curr_digit;
reg [25:0] flash_cnt;
reg [3:0] seg_sel_r;
reg [7:0] seg_data_r;
assign seg_sel=seg_sel_r;
assign seg_data=seg_data_r;

always @(posedge clk or negedge rstn) begin
   if (!rstn) begin
      flash_cnt <= 0;
      curr_digit <= 0;
   end else if (flash_cnt == SEG_FLASH_DUR) begin
      flash_cnt <= 0;
      curr_digit <= curr_digit + 1;
   end else begin
      flash_cnt <= flash_cnt + 1;
   end
end


reg [3:0] curr_num;
always @(*) begin
   case (curr_digit)
      2'd0: begin
         seg_sel_r = 4'b0001;
         curr_num = seg_num_0;
      end
      2'd1: begin
         seg_sel_r = 4'b0010;
         curr_num = seg_num_1;
      end
      2'd2: begin
         seg_sel_r = 4'b0100;
         curr_num = seg_num_2;
      end
      2'd3: begin
         seg_sel_r = 4'b1000;
         curr_num = seg_num_3;
      end
      default: begin
         seg_sel_r = 4'b0000;
         curr_num = 4'd0;
      end
   endcase
end

always @(*) begin
   case (curr_num)
      4'd0: seg_data_r = 8'b11000000;
      4'd1: seg_data_r = 8'b11111001;
      4'd2: seg_data_r = 8'b10100100;
      4'd3: seg_data_r = 8'b10110000;
      4'd4: seg_data_r = 8'b10011001;
      4'd5: seg_data_r = 8'b10010010;
      4'd6: seg_data_r = 8'b10000010;
      4'd7: seg_data_r = 8'b11111000;
      4'd8: seg_data_r = 8'b10000000;
      4'd9: seg_data_r = 8'b10010000;
      default: seg_data_r = 8'b11111111;
   endcase
end

endmodule