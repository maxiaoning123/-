module kalman_filter_8bit (
    input               clk,
    input               rst_n,
    input  [7:0]        data_in,    // 8bit AD输入
    output reg [7:0]    data_out    // 8bit 滤波输出
);

// 8bit适配参数（Q=过程噪声，R=观测噪声，可微调）
parameter Q = 8'd2;    // 过程噪声（越小越相信历史值，滤波越平滑）
parameter R = 8'd10;   // 观测噪声（越小越相信AD数据，响应越快）

reg [15:0] P = 16'd0;  // 协方差（扩展位宽避免溢出）
reg [15:0] LastP = 16'd0;
reg [15:0] Kg = 16'd0; // 卡尔曼增益（16位定点数，高8位整数+低8位小数）
reg [7:0] LastOut = 8'd0;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        P <= 16'd0;
        LastP <= 16'd0;
        Kg <= 16'd0;
        LastOut <= 8'd0;
        data_out <= 8'd0;
    end else begin
        // 预测协方差
        P <= LastP + Q;
        // 计算卡尔曼增益（定点数运算，避免浮点数）
        Kg <= (P << 8) / (P + R);  // 左移8位放大，右移8位还原
        // 最优估计（处理正负差）
        if (data_in > LastOut) begin
            data_out <= LastOut + ((Kg * (data_in - LastOut)) >> 8);
        end else begin
            data_out <= LastOut - ((Kg * (LastOut - data_in)) >> 8);
        end
        // 更新协方差
        LastP <= ((16'd255 - Kg[15:8]) * P) >> 8;  // 取Kg整数部分
        LastOut <= data_out;
    end
end

endmodule