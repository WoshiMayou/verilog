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

    // 当前按键状态缓存
    reg [KEY_CNT-1:0] key_current = {KEY_CNT{1'b1}};
    reg [KEY_CNT-1:0] key_stable_reg = {KEY_CNT{1'b1}};
    reg [31:0] counter [0:KEY_CNT-1];

    // 多按键并行处理
    genvar i;
    generate
        for (i = 0; i < KEY_CNT; i = i + 1) begin : debounce_loop
            always @(posedge clk) begin
                if (keys[i] != key_current[i]) begin
                    // 输入状态变化，更新当前状态并重置计数器
                    key_current[i] <= keys[i];
                    counter[i] <= 0;
                end else if (key_current[i] != key_stable_reg[i]) begin
                    // 状态稳定但与已输出不同，开始计数
                    if (counter[i] >= COUNTER_MAX) begin
                        key_stable_reg[i] <= key_current[i];  // 更新稳定状态
                    end else begin
                        counter[i] <= counter[i] + 1;
                    end
                end else begin
                    // 输入与稳定状态一致，计数器归零
                    counter[i] <= 0;
                end
            end
        end
    endgenerate

    // 输出稳定按键状态
    assign keys_stable = key_stable_reg;




endmodule
