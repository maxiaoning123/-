/*
 * 模块名: wave_detector_auto (自控采样版)
 * 功  能: 检测波形是正弦波还是方波，并自行控制采样窗口。
 * 时  钟: ad_clk 用于数据采样和逻辑执行。
 */
module wave_detector (
    input             clk,         // AD采样时钟，即ad_clk
    input             rst_n,       // 系统复位
    input      [7:0]  ad_data_in,  // 输入的平均化AD数据 (ad_avg_data)
    input      [7:0]  ad_max_in,   // 8位宽的当前波形最大值
    input      [7:0]  ad_min_in,   // 8位宽的当前波形最小值
    output reg        is_square    // 识别结果：1'b1 = 方波，1'b0 = 正弦波
);

// --- 参数定义 ---
// 方波判断的阈值
parameter THRESHOLD_CNT = 10; 

// 内部动态阈值计算
// UPPER_THRESH_DYN = ad_max_in - 10
// LOWER_THRESH_DYN = ad_min_in + 10

// --- 状态机定义 ---
localparam S_WAIT_LOW  = 2'd0; // 等待数据低于 LOWER_THRESH_DYN
localparam S_COUNT_UP  = 2'd1; // 数据在两个阈值之间变化时计数
localparam S_WAIT_HIGH = 2'd2; // 等待数据高于 UPPER_THRESH_DYN

// --- 内部信号 ---
reg  [15:0] count/* synthesis PAP_MARK_DEBUG="1"*/;         // 计数器，用于记录上升所需时钟周期
reg  [1:0]  state/* synthesis PAP_MARK_DEBUG="1"*/;         // 状态机寄存器

// 计算动态阈值
// 确保减法和加法不会溢出，尽管在 8 位宽上可能性较小
wire [7:0] UPPER_THRESH_DYN;
wire [7:0] LOWER_THRESH_DYN;

// 动态计算阈值：ad_max_in - 10 和 ad_min_in + 10
// 使用条件运算符确保阈值合理（例如，ad_max_in - 10 至少为 10）
assign UPPER_THRESH_DYN = (ad_max_in > 8'd10) ? (ad_max_in - 8'd10) : 8'd10; 
assign LOWER_THRESH_DYN = (ad_min_in < 8'd245) ? (ad_min_in + 8'd10) : 8'd245;

// --- 计数器和状态机逻辑 ---
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state     <= S_WAIT_LOW;
        count     <= 16'd0;
        is_square <= 1'b0; // 默认正弦波
    end else begin
        case (state)
            S_WAIT_LOW: begin
                // 状态0：等待波形下降到 LOWER_THRESH_DYN 以下
                if (ad_data_in < LOWER_THRESH_DYN) begin
                    // 已经低于阈值，准备开始上升沿计数
                    state <= S_COUNT_UP;
                    count <= 16'd0; // 重置计数器
                end
            end
            
            S_COUNT_UP: begin
                // 状态1：开始计数，直到波形达到 UPPER_THRESH_DYN
                if (ad_data_in < LOWER_THRESH_DYN) begin
                    // 发生了意外的下降，重新回到等待低位状态，重置计数
                    state <= S_WAIT_LOW;
                    count <= 16'd0;
                end else if (ad_data_in >= UPPER_THRESH_DYN) begin
                    // 达到峰值，上升沿完成
                    state <= S_WAIT_HIGH;
                    
                    // --- 判决逻辑 ---
                    if (count <= THRESHOLD_CNT) begin
                        // 计数很小，跳变非常快 -> 方波
                        is_square <= 1'b1;
                    end else begin
                        // 计数较大，变化平滑 -> 正弦波
                        is_square <= 1'b0;
                    end
                end else begin
                    // 还在上升过程中，继续计数
                    count <= count + 1'b1;
                    // 避免计数器溢出
                    if (count == 16'hFFFF) begin 
                         state <= S_WAIT_HIGH; 
                         is_square <= 1'b0; // 变化太慢，判为正弦波
                    end
                end
            end
            
            S_WAIT_HIGH: begin
                // 状态2：等待波形下降到 LOWER_THRESH_DYN 以下，以开始下一轮判断
                if (ad_data_in < LOWER_THRESH_DYN) begin
                    state <= S_WAIT_LOW;
                end
            end
            
            default: state <= S_WAIT_LOW;
        endcase
    end
end

endmodule