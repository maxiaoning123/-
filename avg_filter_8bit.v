module avg_filter_8bit #(
    parameter N = 16  // 平均点数（2的幂次，如2/4/8/16，N越大滤波越强）
) (
    input               clk,        // 建议用AD采样时钟（如ad_clk）
    input               rst_n,      // 低电平有效复位
    input  [7:0]        data_in,    // 8bit AD原始数据
    output reg [7:0]    data_out    // 8bit 滤波后数据
);

// 累加和位宽：8bit + log2(N)（避免溢出，如N=8时需11bit）
reg [7 + $clog2(N):0] sum;
reg [7:0] buf1 [N-1:0];  // 滑动窗口缓存
integer i;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sum <= 0;
        data_out <= 0;
        for (i = 0; i < N; i = i + 1) buf1[i] <= 0;
    end else begin
        // 移除最旧数据，添加新数据
        sum <= sum - buf1[N-1] + data_in;
        // 窗口移位
        for (i = N-1; i > 0; i = i - 1) buf1[i] <= buf1[i-1];
        buf1[0] <= data_in;
        // 移位代替除法（N为2的幂次，效率最高）
        data_out <= sum >> $clog2(N);
    end
end

endmodule