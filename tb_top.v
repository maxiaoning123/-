`timescale 1ns/1ps 
module tb_top();

// 输入信号定义
reg         clk_27M;  // 50MHz时钟
reg         rst_n;    // 复位信号（低电平有效）

// 实例化顶层模块
top u_top(
    .clk_27M  (clk_27M),
    .rst_n    (rst_n)
);


// 生成50MHz时钟（周期20ns）
initial begin
    clk_27M = 1'b0;
    forever #18.52 clk_27M = ~clk_27M;  // 每10ns翻转一次，频率50MHz
end

// 生成复位信号（初始复位，一段时间后释放）
initial begin
    rst_n = 1'b0;          // 初始复位有效
    #100;                  // 保持复位100ns
    rst_n = 1'b1;          // 释放复位
    #100000;               // 仿真足够长时间（100us），确保测量稳定

end

GTP_GRS GRS_INST(.GRS_N (1'b1));

endmodule