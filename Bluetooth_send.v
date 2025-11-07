module Bluetooth_send(
    input                     sys_clk  ,  
    input                     rst_n,
       
    input            		  uart_rxd ,   
    output           		  uart_txd ,
    output                    Goal_inc ,      
    output                    Goal_dec ,      
    
    input   [31:0]            duty_cycle,
    input   [19:0]            ad_fred,
    input   [7 :0]            ad_max
    );
//uart
wire            uart_tx_en; 
wire            uart_rx_done; 
wire            uart_tx_done; 
wire  [7:0]     uart_tx_data; 
wire  [7:0]     uart_rx_data; 


uart_top uart_top_inst (
    .sys_clk      (sys_clk),    // 系统时钟，需与 UART 内部波特率适配
    .sys_rst_n    (rst_n),        // 系统复位（低电平有效，与模块定义一致）
    
    .uart_rxd     (uart_rxd), // 连接外部 UART 接收引脚
    .uart_txd     (uart_txd), // 连接外部 UART 发送引脚
    
    .uart_tx_en   (uart_tx_en),   
    .uart_rx_done (uart_rx_done), 
    .uart_tx_done (uart_tx_done), 
    
    .uart_tx_data (uart_tx_data), 
    .uart_rx_data (uart_rx_data)  
);

Bluetooth_dataa bluetooth_dataa_inst (
    .clk          (sys_clk),  // 系统时钟，需与UART波特率适配
    .rst_n        (rst_n),      // 系统复位（低有效）
    
    // 待发送的原始数据
    .duty_cycle   (duty_cycle),     // 占空比（31位，实际有效0-100）
    .ad_fred      (ad_fred),        // 频率（19位，实际有效0-9999999）
    .ad_max       (ad_max),         // 幅值（7位，实际有效0-999）
    
    .uart_tx_done (uart_tx_done),   // UART发送完成标志
    .uart_rx_data (uart_rx_data),   // UART接收到的数据
    .uart_rx_done (uart_rx_done),   // UART接收完成标志
    
    .uart_tx_en   (uart_tx_en),     // 发送使能信号
    .uart_tx_data (uart_tx_data)    // 待发送的字节数据
);

// ----------------------------------------------------
// uart_data_check 解析接受数据
// ----------------------------------------------------
uart_data_check u_uart_decoder (
    .clk          ( sys_clk        ), // 输入：系统时钟
    .rst_n        ( rst_n      ), // 输入：复位信号 (低有效)
    .uart_rx_done ( uart_rx_done     ), // 输入：UART接收完成/数据有效信号
    .uart_rx_data ( uart_rx_data ), // 输入：UART接收到的8位数据 [7:0]
    
    .Goal_inc     ( Goal_inc ), // 输出：频率增加脉冲
    .Goal_dec     ( Goal_dec )  // 输出：频率减小脉冲
);




endmodule
