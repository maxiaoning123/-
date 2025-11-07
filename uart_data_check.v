module uart_data_check(
    input         clk,
    input         rst_n,
    input         uart_rx_done,   // UART 接收完成且数据有效的标志（通常是单周期脉冲）
    input  [7:0]  uart_rx_data,   // 接收到的 8 位数据
    
    output        Goal_inc,       // 目标频率增加脉冲 (对应数据 '2B')
    output        Goal_dec        // 目标频率减小脉冲 (对应数据 '2D')
   );

// ------------------------------------------
// I. 参数定义
// ------------------------------------------
// ASCII 码 '2B' 和 '2D'
// 注意：如果您的UART发送的是ASCII字符 '2' 和 'B'，那它们不是一个字节 '2B'H。
// 假设这里 '2B' 和 '2D' 是一个单字节的十六进制值。
localparam DATA_INC = 8'h2B; // 对应 Goal_inc 的数据字节
localparam DATA_DEC = 8'h2D; // 对应 Goal_dec 的数据字节

reg r_Goal_inc;
reg r_Goal_dec;

always @(posedge clk or negedge rst_n) begin
    if (rst_n == 1'b0) begin
        r_Goal_inc <= 1'b0;
        r_Goal_dec <= 1'b0;
    end else begin
        // Goal_inc 脉冲
        if (uart_rx_done & (uart_rx_data == DATA_INC)) begin
            r_Goal_inc <= 1'b1; // 在数据接收完成的周期置高
        end else begin
            r_Goal_inc <= 1'b0; // 否则置低
        end
        
        // Goal_dec 脉冲
        if (uart_rx_done & (uart_rx_data == DATA_DEC)) begin
            r_Goal_dec <= 1'b1; // 在数据接收完成的周期置高
        end else begin
            r_Goal_dec <= 1'b0; // 否则置低
        end
    end
end

assign Goal_inc = r_Goal_inc;
assign Goal_dec = r_Goal_dec;


endmodule