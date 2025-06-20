module KeyDebounce #(
                              // clock frequency(Mhz), 50 MHz
   parameter CLK_FREQ = 50_000_000,
   parameter KEY_CNT = 8
)
(
   input                clk,               // clock input
   input  [KEY_CNT-1:0] keys,              // input key pins, raw input
   output [KEY_CNT-1:0] keys_stable        // output stable key status, 0 - press down
);


// TODO - NEED TO remove following codes, replaced by your codes
    // debounce time: 20ms -> COUNTER_MAX = CLK_FREQ * 20ms
    parameter COUNTER_MAX = (CLK_FREQ / 1000) * 20;

    // ��ǰ����״̬����
    reg [KEY_CNT-1:0] key_current = {KEY_CNT{1'b1}};
    reg [KEY_CNT-1:0] key_stable_reg = {KEY_CNT{1'b1}};
    reg [31:0] counter [0:KEY_CNT-1];

    // �ఴ�����д���
    genvar i;
    generate
        for (i = 0; i < KEY_CNT; i = i + 1) begin : debounce_loop
            always @(posedge clk) begin
                if (keys[i] != key_current[i]) begin
                    // ����״̬�仯�����µ�ǰ״̬�����ü�����
                    key_current[i] <= keys[i];
                    counter[i] <= 0;
                end else if (key_current[i] != key_stable_reg[i]) begin
                    // ״̬�ȶ������������ͬ����ʼ����
                    if (counter[i] >= COUNTER_MAX) begin
                        key_stable_reg[i] <= key_current[i];  // �����ȶ�״̬
                    end else begin
                        counter[i] <= counter[i] + 1;
                    end
                end else begin
                    // �������ȶ�״̬һ�£�����������
                    counter[i] <= 0;
                end
            end
        end
    endgenerate

    // ����ȶ�����״̬
    assign keys_stable = key_stable_reg;




endmodule
