module UartWrapper #(
   parameter CLK_FREQ = 50_000_000,
   parameter AREA_ROW = 32,
   parameter AREA_COL = 16,
   parameter ROW_ADDR_W = 5,
   parameter COL_ADDR_W = 4,
   parameter BPS_NUM = 16'd434
) (
   input                            clk,
   input                            rstn,
   output                           uart_tx,
   output      [ROW_ADDR_W-1:0]     bitmap_row,
   output      [COL_ADDR_W-1:0]     bitmap_col,
   input       [AREA_COL*2-1:0]     bitmap_data
);


//==========================================================================
// internal signals
//==========================================================================

reg [8:0] uart_encode_data_idx = 9'b0;

assign bitmap_row = uart_encode_data_idx[8:4];
assign bitmap_col = uart_encode_data_idx[3:0];


//==========================================================================
// UART transmit, for 1 byte data send 
//==========================================================================

wire           tx_busy;         // transmitter is free
reg            tx_busy_d0;      //             : current clock     
reg            tx_busy_d1;      //             : before 1 clock
reg     [7:0]  tx_data;         // data need to send out                                    
reg            tx_en;           // enable transmit.

uart_tx #(
    .BPS_NUM            (  BPS_NUM       )    // parameter         BPS_NUM  
) 
u_uart_tx(
    .clk                 (  clk           ),  // input            clk,               
    .tx_data             (  tx_data       ),  // input [7:0]      tx_data,           
    .tx_pluse            (  tx_en         ),  // input            tx_pluse,          
    .uart_tx             (  uart_tx       ),  // output reg       uart_tx,                                  
    .tx_busy             (  tx_busy       )   // output           tx_busy            
);   

always @(posedge clk) begin
   tx_busy_d0 <= tx_busy;
   tx_busy_d1 <= tx_busy_d0;
end 


//==========================================================================
// UART Encode, for 1 packet data (many bytes inside) to send
//==========================================================================

parameter UART_ENCODE_HEAD_R = 2'b00;
parameter UART_ENCODE_HEAD_C = 2'b01;
parameter UART_ENCODE_DATA = 2'b10;
parameter UART_ENCODE_TAIL = 2'b11;

parameter UART_ENCODE_DATA_END = AREA_ROW * AREA_COL - 4;

reg [1:0] uart_encode_cur_state = UART_ENCODE_HEAD_R;
reg [1:0] uart_encode_nxt_state = UART_ENCODE_HEAD_R;

wire uart_tx_finished;
assign uart_tx_finished = (~tx_busy_d0) & tx_busy_d1;

wire uart_data_end;
assign uart_data_end = (uart_encode_data_idx == UART_ENCODE_DATA_END) ? 1'b1 : 1'b0;

always @(posedge clk) begin
   if (~rstn) begin
      uart_encode_cur_state <= UART_ENCODE_HEAD_R;
   end 
   else begin
      uart_encode_cur_state <= uart_encode_nxt_state;
   end 
end 

always @(*) begin
   if (~rstn) begin
      uart_encode_nxt_state = UART_ENCODE_HEAD_R;
   end 
   else begin
      case (uart_encode_cur_state)
         UART_ENCODE_HEAD_R: begin
            uart_encode_nxt_state = uart_tx_finished ? UART_ENCODE_HEAD_C : UART_ENCODE_HEAD_R;
         end 
         UART_ENCODE_HEAD_C: begin
            uart_encode_nxt_state = uart_tx_finished ? UART_ENCODE_DATA : UART_ENCODE_HEAD_C;
         end 
         UART_ENCODE_DATA: begin
            uart_encode_nxt_state = (uart_tx_finished & uart_data_end) ? UART_ENCODE_TAIL : UART_ENCODE_DATA;
         end 
         UART_ENCODE_TAIL: begin
            uart_encode_nxt_state = uart_tx_finished ? UART_ENCODE_HEAD_R : UART_ENCODE_TAIL;
         end 
      endcase 
   end 
end 


always @(posedge clk) begin
   if (~rstn) begin
      uart_encode_data_idx <= 9'b0;
   end 
   else if (uart_encode_cur_state != UART_ENCODE_DATA) begin
      uart_encode_data_idx <= 9'b0;
   end 
   else if (uart_tx_finished) begin // state in UART_ENCODE_DATA
      if (uart_encode_data_idx >= UART_ENCODE_DATA_END) begin
         uart_encode_data_idx <= 9'b0;
      end 
      else begin
         uart_encode_data_idx <= uart_encode_data_idx + 4;
      end 
   end 
end 


//==========================================================================
// udpate tx_data, based on current state
//==========================================================================

reg [7:0] uart_data_chksum = 8'b0;

always @(posedge clk) begin
   
   if (~rstn) begin
      tx_data <= 8'b0;
      uart_data_chksum <= 8'b0;
   end 
   else if (uart_encode_cur_state == UART_ENCODE_HEAD_R) begin
      tx_data <= AREA_ROW;
      uart_data_chksum <= 8'b0;
   end 
   else if (uart_encode_cur_state == UART_ENCODE_HEAD_C) begin
      tx_data <= AREA_COL;
      uart_data_chksum <= 8'b0;
   end 
   else if (uart_encode_cur_state == UART_ENCODE_TAIL) begin
      tx_data <= uart_data_chksum;
   end 
   else begin // state in UART_ENCODE_DATA
      if (bitmap_col == 4'd0) begin
         tx_data <= {
            bitmap_data[19], 
            bitmap_data[3],
            bitmap_data[18], 
            bitmap_data[2],
            bitmap_data[17], 
            bitmap_data[1],
            bitmap_data[16], 
            bitmap_data[0]
         };
      end 
      else if (bitmap_col == 4'd4) begin
         tx_data <= {
            bitmap_data[23], 
            bitmap_data[7],
            bitmap_data[22], 
            bitmap_data[6],
            bitmap_data[21], 
            bitmap_data[5],
            bitmap_data[20], 
            bitmap_data[4]
         };
      end 
      else if (bitmap_col == 4'd8) begin
         tx_data <= {
            bitmap_data[27], 
            bitmap_data[11],
            bitmap_data[26], 
            bitmap_data[10],
            bitmap_data[25], 
            bitmap_data[9],
            bitmap_data[24], 
            bitmap_data[8]
         };
      end 
      else begin
         tx_data <= {
            bitmap_data[31], 
            bitmap_data[15],
            bitmap_data[30], 
            bitmap_data[14],
            bitmap_data[29], 
            bitmap_data[13],
            bitmap_data[28], 
            bitmap_data[12]
         };
      end  
      // tx_data <= bitmap_data;
      if (uart_tx_finished) begin
         uart_data_chksum <= uart_data_chksum ^ tx_data;
      end 
   end 
end 


//==========================================================================
// control tx_en signal, with speed control
//==========================================================================

reg [7:0] uart_wait_cnt = 1;

always @(posedge clk) begin
   if (~rstn) begin
      tx_en <= 1'b0;
      uart_wait_cnt <= 1;
   end  
   else if (uart_tx_finished) begin
      tx_en <= 1'b0;
      uart_wait_cnt <= 1;
   end 
   else begin
      if (uart_wait_cnt != 0) begin
         tx_en <= 1'b0;
         uart_wait_cnt <= uart_wait_cnt + 1;
      end  
      else begin
         uart_wait_cnt <= 0;
         tx_en <= 1'b1;
      end 
      // tx_en <= 1'b1;
   end
end 

endmodule
