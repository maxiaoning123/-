module auto_check(
    input         clk,
    input         rst_n,
    input         Goal_inc,//目标频率增加按键
    input         Goal_dec,//目标频率减小按键
    input [19:0]  ad_freq, // 实际测量的频率（单位：Hz）
    
    output        Goal_flag // 目标频率是否在范围内
   );

// ------------------------------------------
// I. 参数定义 (假设频率单位是 Hz)
// ------------------------------------------
localparam FREQ_RANGE_HZ    = 20'd1000;    // max与min之间的固定差值：1000 Hz
localparam ADJUST_STEP_HZ   = 20'd10000;   // 每次增加/减少的步进值：10 kHz (10000 Hz)

// 频率限制（假设最大频率不超过 1MHz, 即 1,000,000 Hz）
localparam MAX_LIMIT_HZ     = 20'd1000000; // 1MHz
localparam MIN_LIMIT_HZ     = 20'd10000;   // 10kHz

// ------------------------------------------
// II. 内部信号和寄存器
// ------------------------------------------
reg [19:0]    Goal_freq_max; // 目标频率范围上限
reg [19:0]    Goal_freq_min; // 目标频率范围下限

// 按键同步和边沿检测（简化处理，实际中建议使用更完善的消抖逻辑）
reg           Goal_inc_d;
reg           Goal_dec_d;
wire          inc_pulse;
wire          dec_pulse;

// ------------------------------------------
// III. 按键脉冲生成 (简化为上升沿检测)
// ------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (rst_n == 1'b0) begin
        Goal_inc_d <= 1'b0;
        Goal_dec_d <= 1'b0;
    end else begin
        Goal_inc_d <= Goal_inc;
        Goal_dec_d <= Goal_dec;
    end
end

assign inc_pulse = Goal_inc & (~Goal_inc_d); // 增加按键的上升沿
assign dec_pulse = Goal_dec & (~Goal_dec_d); // 减小按键的上升沿

// ------------------------------------------
// IV. 目标频率寄存器控制逻辑
// ------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (rst_n == 1'b0) begin
        // 复位时初始化目标频率范围 (例如从 10kHz 开始)
        Goal_freq_min <= 20'd10000; 
        Goal_freq_max <= 20'd10000 + FREQ_RANGE_HZ; // 11kHz
    end else if (inc_pulse) begin
        // 目标频率增加
        // 检查 Goal_freq_max 增加后是否超过最大限制
        if (Goal_freq_max + ADJUST_STEP_HZ <= MAX_LIMIT_HZ) begin
            Goal_freq_min <= Goal_freq_min + ADJUST_STEP_HZ;
            Goal_freq_max <= Goal_freq_max + ADJUST_STEP_HZ;
        end else begin
            // 达到上限，保持不变
            Goal_freq_min <= Goal_freq_min; 
            Goal_freq_max <= Goal_freq_max;
        end
    end else if (dec_pulse) begin
        // 目标频率减小
        // 检查 Goal_freq_min 减小后是否低于最小限制
        if (Goal_freq_min >= MIN_LIMIT_HZ + ADJUST_STEP_HZ) begin 
            Goal_freq_min <= Goal_freq_min - ADJUST_STEP_HZ;
            Goal_freq_max <= Goal_freq_max - ADJUST_STEP_HZ;
        end else begin
            // 达到下限，保持不变
            Goal_freq_min <= Goal_freq_min; 
            Goal_freq_max <= Goal_freq_max;
        end
    end
    // 注意：由于 Goal_freq_max 和 Goal_freq_min 总是通过加减 ADJUST_STEP_HZ 调整，
    // 且初始值满足 Goal_freq_max = Goal_freq_min + FREQ_RANGE_HZ，
    // 它们之间的差值 (FREQ_RANGE_HZ) 会自动保持不变。
end

// ------------------------------------------
// V. 目标频率检测逻辑
// ------------------------------------------
assign Goal_flag = (ad_freq >= Goal_freq_min) && (ad_freq <= Goal_freq_max);

endmodule