`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Myminieye
// Engineer: Ori
// 
// Create Date: 2019-09-16 19:46
// Design Name: 
// Module Name: outputserdes
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// Revision: v1.0
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`define UD #1
module outputserdes#(
    parameter                  KPARALLELWIDTH = 10
) (
	input                         pixelclk  ,//input
	input                         serialclk ,// 5x serialclk input
	input [KPARALLELWIDTH-1:0]    pdataout  ,// input data for serialisation
    input                         rstn      ,

	output                        sdataout_p,// out DDR data
	output                        sdataout_n // out DDR data
  ) ;  
wire         padt0_p     ;	
wire         padt1_p     ;
wire         padt2_p     ;
wire         padt3_p     ;
wire  [3:0]  stxd_rgm_p  ; 
wire         padt0_n     ;	
wire         padt1_n     ;
wire         padt2_n     ;
wire         padt3_n     ;
wire  [3:0]  stxd_rgm_n  ;  
reg [2:0] TMDS_mod5 = 0;  // modulus 5 counter

reg [4:0] TMDS_shift_0h = 0, TMDS_shift_0l = 0;


wire [4:0] TMDS_0_l = {pdataout[9],pdataout[7],pdataout[5],pdataout[3],pdataout[1]};
wire [4:0] TMDS_0_h = {pdataout[8],pdataout[6],pdataout[4],pdataout[2],pdataout[0]};

always @(posedge serialclk)
begin
	TMDS_shift_0h  <= TMDS_mod5[2] ? TMDS_0_h : TMDS_shift_0h[4:1];
	TMDS_shift_0l  <= TMDS_mod5[2] ? TMDS_0_l : TMDS_shift_0l[4:1];	
	TMDS_mod5 <= (TMDS_mod5[2]) ? 3'd0 : TMDS_mod5 + 3'd1;
end

    
GTP_OSERDES #(
 .OSERDES_MODE("ODDR"),  //"ODDR","OMDDR","OGSER4","OMSER4","OGSER7","OGSER8",OMSER8"
 .WL_EXTEND   ("FALSE"),     //"TRUE"; "FALSE"
 .GRS_EN      ("TRUE"),         //"TRUE"; "FALSE"
 .LRS_EN      ("TRUE"),          //"TRUE"; "FALSE"
 .TSDDR_INIT  (1'b0)         //1'b0;1'b1
) u0_GTP_OSERDES(
   .DO    (stxd_rgm_p[0]),
   .TQ    (padt0_p),
   .DI    ({6'd0,TMDS_shift_0l[0],TMDS_shift_0h[0]}),
   .TI    (4'd0),
   .RCLK  (serialclk),
   .SERCLK(serialclk),
   .OCLK  (1'd0),
   .RST   (1'b0)
); 
GTP_OUTBUFT  u0_GTP_OUTBUFT
(
    
    .I(stxd_rgm_p[0]),     
    .T(padt0_p)  ,
    .O(sdataout_p)        
);             

GTP_OSERDES #(
 .OSERDES_MODE("ODDR"),  //"ODDR","OMDDR","OGSER4","OMSER4","OGSER7","OGSER8",OMSER8"
 .WL_EXTEND   ("FALSE"),     //"TRUE"; "FALSE"
 .GRS_EN      ("TRUE"),         //"TRUE"; "FALSE"
 .LRS_EN      ("TRUE"),          //"TRUE"; "FALSE"
 .TSDDR_INIT  (1'b0)         //1'b0;1'b1
) u1_GTP_OSERDES(
   .DO    (stxd_rgm_n[0]),
   .TQ    (padt0_n),
   .DI    ({6'd0,~TMDS_shift_0l[0],~TMDS_shift_0h[0]}),
   .TI    (4'd0),
   .RCLK  (serialclk),
   .SERCLK(serialclk),
   .OCLK  (1'd0),
   .RST   (1'b0)
); 
GTP_OUTBUFT  u1_GTP_OUTBUFT
(
    
    .I(stxd_rgm_n[0]),     
    .T(padt0_n)  ,
    .O(sdataout_n)        
);             

	
endmodule

