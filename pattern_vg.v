`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:Meyesemi 
// Engineer: Will
// 
// Create Date: 2023-01-29 20:31  
// Design Name:  
// Module Name: 
// Project Name: 
// Target Devices: Pango
// Tool Versions: 
// Description: 
//      
// Dependencies: 
// 
// Revision:
// Revision 1.0 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`define UD #1

module pattern_vg # (
    parameter                            COCLOR_DEPP=8, // number of bits per channel
    parameter                            H_ACT = 12'd1280,
    parameter                            V_ACT = 12'd720
)(                                       
    input                                rstn, 
    input                                pix_clk,
    input [1:0]                          pix_data, // 00 - white; 01 - moving, red; 10 - fixed, blue; 11 - border, black
    input                                vs_in, 
    input                                hs_in, 
    input                                de_in,
    output reg                           vs_out, 
    output reg                           hs_out, 
    output reg                           de_out,
    output reg [COCLOR_DEPP-1:0]         r_out, 
    output reg [COCLOR_DEPP-1:0]         g_out, 
    output reg [COCLOR_DEPP-1:0]         b_out
);

    parameter DATA_WHITE = 2'b00;
    parameter DATA_RED   = 2'b01;
    parameter DATA_BLUE  = 2'b10;
    // parameter DATA_BLACK = 2'b11;
    
    always @(posedge pix_clk)
    begin
        vs_out <= `UD vs_in;
        hs_out <= `UD hs_in;
        de_out <= `UD de_in;
    end

    always @(posedge pix_clk)
    begin
        if (de_in)
        begin
            if (pix_data == DATA_WHITE) begin
                r_out <= 8'hff;
                g_out <= 8'hff;
                b_out <= 8'hff;
            end 
            else if (pix_data == DATA_RED) begin
                r_out <= 8'hff;
                g_out <= 8'h00;
                b_out <= 8'h00;
            end 
            else if (pix_data == DATA_BLUE) begin
                r_out <= 8'h00;
                g_out <= 8'h00;
                b_out <= 8'hff;
            end 
            else begin // black
                r_out <= 8'h0;
                g_out <= 8'h0;
                b_out <= 8'h0;
            end 
        end
        else
        begin
            r_out <= 8'h00;
            g_out <= 8'h00;
            b_out <= 8'h00;
        end
    end
    
endmodule
