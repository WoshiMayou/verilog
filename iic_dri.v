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
// Additional Comments: �޸�IIC״̬�����ڶ���Ϊ����߼�����ֵӦʹ�á�=��������=���滻��<= `UD��
//                       �޸�busy���䣬����iic_dri���ܻ������Ӧ�ڽ���һ�δ�����ͽ���busy״̬��
//                                �޸���䣺if(start_en)       busy <= `UD 1'b1;   
//////////////////////////////////////////////////////////////////////////////////
`define UD #1
module iic_dri #(
    parameter            CLK_FRE = 27'd50_000_000,  //system clock frequency
    parameter            IIC_FREQ = 20'd400_000,    //I2c clock frequency
    parameter            T_WR = 10'd5,              //I2c transmit delay ms
    parameter            ADDR_BYTE = 2'd1,          //I2C addr byte number
    parameter            LEN_WIDTH = 8'd3,          //I2C transmit byte width
    parameter            DATA_BYTE = 2'd1           //I2C data byte number
)(                       
    input                clk,
    input                rstn,
    input                pluse,                     //I2C transmit trigger
    input  [7:0]         device_id,                 //I2C divice id
    input                w_r,                       //I2C transmit direction 1:send  0:receive
    input  [LEN_WIDTH:0] byte_len,                  //I2C transmit data byte length of once trigger
                    
    input  [ADDR_BYTE*8 - 1:0]         addr,                      //I2C transmit addr
    input  [7:0]         data_in,                   //I2C send data
                         
    output reg           busy=0,                    //I2C bus status
    output reg           byte_over=0,               //I2C byte transmit over flag
                         
    output reg[7:0]      data_out,                  //I2C receive data
                         
    output               scl,
    input                sda_in,
    output   reg         sda_out=1'b1,
    output               sda_out_en
);

    localparam CLK_DIV = CLK_FRE/IIC_FREQ;  //�������������ֵ������ʱ����
    localparam ID_ADDR_BYTE = ADDR_BYTE + 1'b1;//��ַ��deviceID�ֽ���
    localparam DATA_SET = CLK_DIV>>2;//���data�仯λ��
    localparam T_WR_DELAY = T_WR*CLK_FRE/1000_000;

    //  iic clock time counter
    reg [20:0] fre_cnt;//=21'd0;
    always @(posedge clk)
    begin
        if(!rstn)
            fre_cnt <= `UD 21'd0;
        else if(fre_cnt == CLK_DIV - 1'b1)
            fre_cnt <= `UD 21'd0;
        else
            fre_cnt <= `UD fre_cnt + 1'b1;
    end
    
    wire  full_cycle;
    wire  half_cycle;
    assign full_cycle = (fre_cnt == CLK_DIV - 1'b1) ? 1'b1 : 1'b0;  //SCL�����أ�1��SCL����λ��
    assign half_cycle = (fre_cnt == (CLK_DIV>>1'b1) - 1'b1) ? 1'b1 : 1'b0;//SCL�½��أ�1/2��SCL����λ��
    
    wire start_h;
    wire dsu;
    assign start_h = (fre_cnt == DATA_SET - 1'b1) ? 1'b1 : 1'b0; //��ʼֹͣ��־SDA��תλ�� ��1/4��SCL����λ��
    assign dsu = (fre_cnt == (CLK_DIV>>1'b1) + DATA_SET - 1'b1) ? 1'b1 : 1'b0; //���ݴ������SDA�仯λ�ã�3/4��SCL����λ��
    
    //============================================================================
    //pluse trige the iic bus transmit start
    wire   start;
    reg    start_en;
    reg    pluse_1d,pluse_2d,pluse_3d;
    always @(posedge clk)
    begin
        if(!rstn)
        begin
            pluse_1d <= `UD 1'b0;
            pluse_2d <= `UD 1'b0;
            pluse_3d <= `UD 1'b0;
        end
        else
        begin
            pluse_1d <= `UD pluse   ;
            pluse_2d <= `UD pluse_1d;//ͬ��
            pluse_3d <= `UD pluse_2d;//ȡ������
        end
    end
    
    always @ (posedge clk)
    begin
        if(start || (!rstn))//��ʼ��ʼʹ���ź�����
            start_en <= `UD 1'b0;
        else if(~pluse_3d & pluse_2d)//������
            start_en <= `UD 1'b1;
        else
            start_en <= `UD start_en;
    end
    
    assign start = (start_en & full_cycle) ? 1'b1 : 1'b0;
    
    reg w_r_1d=1'b0,w_r_2d=1'b0;
    always @(posedge clk)
    begin
        if(!rstn)
        begin
            w_r_1d <= `UD 1'b0;
            w_r_2d <= `UD 1'b0;
        end
        else
        begin
            w_r_1d <= `UD w_r;
            w_r_2d <= `UD w_r_1d;
        end
    end

    //==========================================================================
    //     IIC FSM STATE
    //==========================================================================
    localparam IDLE   = 3'd0;
    localparam S_START= 3'd1;
    localparam SEND   = 3'd2;
    localparam S_ACK  = 3'd3;
    localparam RECEIV = 3'd4;
    localparam R_ACK  = 3'd5;
    localparam STOP   = 3'd6;
    reg [2:0] state;
    reg [2:0] state_n;
    reg [2:0] trans_bit = 3'd0;
    
    reg [LEN_WIDTH :0] trans_byte = 5'd0;
    reg [LEN_WIDTH :0] trans_byte_max = 5'd0;
    reg       restart = 1'b0;
    reg [7:0] send_data=8'd0;
    reg [7:0] receiv_data=8'd0;
    reg       trans_en=0;
    reg       trans_over=0;
    reg       scl_out= 1'b1/*synthesis PAP_MARK_DEBUG="true"*/;
    
//    assign sda = sda_out_en ? sda_out : 1'bz;
//    assign sda_in = sda;
    assign scl = scl_out;
    
    //============================================================================
    //transmit status
    always @ (posedge clk)
    begin
        if(start)//���������ʼ��־
            trans_en <= `UD 1'b1;
        else if(state == STOP && start_h)//����STOP��־������
            trans_en <= `UD 1'b0;
        else
            trans_en <= `UD trans_en;
    end
    
//    always @(posedge clk)//����
//    begin
//        if(start)
//            trans_over <= `UD 1'b0;
//        else if(state == STOP && start_h)
//            trans_over <= `UD 1'b1;
//        else 
//            trans_over <= `UD trans_over;
//    end
    
    //===========================================================================
    // IIC Bus status
    reg           twr_en=0;
    reg  [26:0]   twr_cnt=0;
    always @(posedge clk)
    begin
        if(state == STOP && dsu)//STOP״̬��ʼ��ʱ
            twr_en <= `UD 1'b1;
        else if(twr_cnt == T_WR_DELAY)//��ʱ��5ms
            twr_en <= `UD 1'b0;
        else
            twr_en <= `UD twr_en;    
    end
    
    always @(posedge clk)
    begin
        if(twr_en)
        begin
            if(twr_cnt == T_WR_DELAY)//��ʱ��5ms
                twr_cnt <= `UD 1'b0;
            else
                twr_cnt <= `UD twr_cnt + 1'b1; 
        end
        else
            twr_cnt <= `UD twr_cnt;
    end
    
    always @(posedge clk)
    begin
        if(start_en)  //���տ�ʼָ�����busy
            busy <= `UD 1'b1;
        else if(twr_cnt == T_WR_DELAY)//busy��ʱ���
            busy <= `UD 1'b0;
        else
            busy <= `UD busy;
    end
    
    //============================================================================
    //iic bus controller
    always @(posedge clk)
    begin
        if(trans_en)
        begin
            if(half_cycle || full_cycle)
                scl_out <= ~scl_out;
            else
                scl_out <= scl_out;
        end
        else
            scl_out <= 1'b1;
    end
    
    assign sda_out_en = ((state == S_ACK) || (state == RECEIV)) ? 1'b0 : 1'b1;
    
    //tx data control
    always @(posedge clk)
    begin
        if(start)//��ʼ����ʱ��ǰ׼����һ���豸ID+д��־
            send_data <= `UD {device_id[7:1],1'b0};//{�豸ID����д��־}   �����λ��ǰ
        else if(state == S_ACK && full_cycle) //��SACK״̬��ȡһ������ǰ׼������
        begin
        	if(ADDR_BYTE == 2'd1)
        	begin
                case(trans_byte)//�������ݱ仯
                    5'd0 : send_data <= `UD {device_id[7:1],1'b0};
                    5'd1 : send_data <= `UD addr[7:0];
                    5'd2 : send_data <= `UD (w_r_2d) ? data_in : {device_id[7:1],1'b1};
                    default: send_data <= `UD data_in;
                endcase
            end
            else
            begin
            	case(trans_byte)//�������ݱ仯
                    5'd0 : send_data <= `UD {device_id[7:1],1'b0};
                    5'd1 : send_data <= `UD addr[ 7:0];
                    5'd2 : send_data <= `UD addr[15:8];
                    5'd3 : send_data <= `UD (w_r_2d) ? data_in : {device_id[7:1],1'b1};
                    default: send_data <= `UD data_in;
                endcase
            end
        end
        else
            send_data <= `UD send_data;
    end
    
    //transmit byte number,contain device ID��ADDR��DATA
    always @(posedge clk)
    begin
        if(start)
        begin
            if(w_r_2d)
                trans_byte_max <= `UD ADDR_BYTE + byte_len + 2'd1;
            else
                trans_byte_max <= `UD ADDR_BYTE + byte_len + 2'd2;
        end
        else
            trans_byte_max <= `UD trans_byte_max;
    end
    
    //sda out control
    always @(posedge clk)
    begin
        case(state)
            IDLE  ://����״̬
            begin
                sda_out <= `UD 1'b1;
            end
            S_START ://��ʼ״̬
            begin
                if(start_h)//��ʼ��־����
                    sda_out <= `UD 1'b0;
                else if(dsu)//������SCL������ǰ����
                    sda_out <= `UD send_data[7-trans_bit];//��λ�ȷ�
                else
                    sda_out <= `UD sda_out;
            end
            SEND  :
            begin
                sda_out <= `UD send_data[7-trans_bit];//�仯���ݣ���λ�ȷ�
            end
            S_ACK :
            begin
                if(trans_byte == ID_ADDR_BYTE && dsu && !w_r_2d)//��״̬�µ�ַ������ɣ�׼������ڶ���S_START
                    sda_out <= `UD 1'b1;
                else
                    sda_out <= `UD 1'h0;
            end
            R_ACK :
            begin
                if(trans_byte < trans_byte_max)//������ȡ�ظ�ACK
                    sda_out <= `UD 1'b0;
                else
                begin
                    if(dsu)//����ACK����������STOP״̬����ǰ��SDA����
                        sda_out <= `UD 1'b0;
                    else//�������ټ���������ʾ�л����䷽��
                        sda_out <= `UD 1'b1;
                end
            end
            STOP  :
            begin
                if(start_h)//ֹͣ��־��
                    sda_out <= `UD 1'b1;
                else
                    sda_out <= `UD sda_out;
            end
            default: sda_out <= `UD 1'b1;
        endcase
    end
    
    // iic read data
    always @(posedge clk)
    begin
        if(state == RECEIV)
        begin
            if(full_cycle)//������λ�ý�����������
                receiv_data <= `UD {receiv_data[6:0],sda_in};
            else
                receiv_data <= `UD receiv_data;
        end
        else
            receiv_data <= `UD 8'd0;
    end
    
    always @(posedge clk)
    begin
        if(state == RECEIV && trans_bit == 3'd7 && half_cycle)//����1byte���ݺ󣬽����ݴ���
            data_out <= `UD receiv_data;
        else
            data_out <= `UD data_out;
    end
    
    //one byte data transmit over flag
    always @(posedge clk)
    begin
        if(w_r_2d)
        begin
            if(trans_byte > ID_ADDR_BYTE - 1'b1 && dsu && trans_bit == 3'd7)//д��ַ��ɺ��ٴ����ֽڽ��б�ʶ
                byte_over <= `UD 1'b1;
            else
                byte_over <= `UD 1'b0;
        end
        else
        begin
            if(trans_byte > ID_ADDR_BYTE && dsu && trans_bit == 3'd7)//д��ڶ���ID���ٴ����ֽڽ��б�ʶ
                byte_over <= `UD 1'b1;
            else
                byte_over <= `UD 1'b0;
        end
    end
    
    always @(posedge clk)
    begin
        if(state == SEND || state == RECEIV)
        begin
            if(dsu)
                trans_bit <= `UD trans_bit + 1'b1;
            else
                trans_bit <= `UD trans_bit;
        end
        else
            trans_bit <= `UD 3'd0;
    end
    
    always @(posedge clk)
    begin
        if(start)//ÿ�ο�ʼ����ʱ����byte����
            trans_byte <= `UD 5'd0;
        else if(state == SEND || state == RECEIV)//��д״̬��Ҫ����
        begin
            if(dsu && trans_bit == 3'd7)//������1byteʱ������1
                trans_byte <= `UD trans_byte + 1'b1;
            else//����ʱ�򱣳�״̬
                trans_byte <= `UD trans_byte;
        end
        else//����ʱ�򱣳�״̬
            trans_byte <= `UD trans_byte;
    end
    
    //==========================================================================
    //     IIC FSM STATE CHANGE
    //==========================================================================
    always @(posedge clk)
    begin
        if(!rstn)
            state <= `UD IDLE;
        else
            state <= `UD state_n;
    end
    
    // next state set
    always @(*)
    begin
        state_n = state;
        case(state)
            IDLE  :
            begin
                if(start)
                    state_n = S_START;
                else
                    state_n = state;
            end
            S_START :
            begin
//                if(full_cycle && trans_byte == 3'd0) //��д������һ��
//                    state_n = SEND;
//                else if(!w_r_2d && trans_byte == ID_ADDR_BYTE && dsu)//�������ڶ���
//                    state_n = SEND;
                if(dsu) 
                    state_n = SEND;
                else
                    state_n = state;
            end
            SEND  :
            begin
                if(trans_bit == 3'd7 & dsu)
                    state_n = S_ACK;
                else
                    state_n = state;
            end
            S_ACK :
            begin
                if(dsu)// & sda_in)
                begin
                    if(w_r_2d)
                    begin
                        if(trans_byte < ID_ADDR_BYTE)//д��ID+ADDR
                            state_n = SEND;
                        else if(trans_byte < trans_byte_max)//д������
                            state_n = SEND;
                        else//д���������
                            state_n = STOP;
                    end
                    else
                    begin
                        if(trans_byte < ID_ADDR_BYTE)//д��ID+ADDR
                            state_n = SEND;
                        else if(trans_byte == ID_ADDR_BYTE)//���¿�ʼ��д��ID�Ͷ���־λ
                            state_n = S_START;
                        else//�����״̬
                            state_n = RECEIV;
                    end
                end
                else
                    state_n = state;
            end
            RECEIV:
            begin
                if(trans_bit == 3'd7 & dsu)
                    state_n = R_ACK;
                else
                    state_n = state;
            end
            R_ACK :
            begin
                if(dsu)
                begin
                    if(trans_byte < trans_byte_max)
                        state_n = RECEIV;
                    else
                        state_n = STOP;
                end
                else
                    state_n = state;
            end
            STOP  :
            begin
                if(dsu)
                    state_n = IDLE;
                else
                    state_n = state;
            end
            default: state_n = IDLE;
        endcase
    end
    
    //===========================================================================

endmodule
 