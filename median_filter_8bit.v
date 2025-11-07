module median_filter_8bit #(
    parameter WINDOW = 3  // 窗口大小（3/5/7，奇数，3点最省资源）
) (
    input               clk,
    input               rst_n,
    input  [7:0]        data_in,
    output reg [7:0]    data_out
);

reg [7:0] buf1 [WINDOW-1:0];  // 滑动窗口缓存
reg [7:0] temp [WINDOW-1:0]; // 排序临时变量
integer i, j;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i = 0; i < WINDOW; i = i + 1) buf1[i] <= 0;
        data_out <= 0;
    end else begin
        // 窗口移位：移除最旧数据，加入新数据
        for (i = WINDOW-1; i > 0; i = i - 1) buf1[i] <= buf1[i-1];
        buf1[0] <= data_in;
        
        // 复制数据到临时数组（避免修改原缓存）
        for (i = 0; i < WINDOW; i = i + 1) temp[i] <= buf1[i];
        
        // 冒泡排序（8bit数据排序效率高）
        for (i = 0; i < WINDOW-1; i = i + 1) begin
            for (j = 0; j < WINDOW-1 - i; j = j + 1) begin
                if (temp[j] > temp[j+1]) begin
                    temp[j] <= temp[j+1];
                    temp[j+1] <= temp[j];
                end
            end
        end
        
        // 取中间值（窗口为奇数，直接取中间索引）
        data_out <= temp[WINDOW/2];
    end
end

endmodule