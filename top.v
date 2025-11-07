module top(
    input                     clk_27M,//27m Hz
    input                     rst,
    input                     key_add_1000hz,
    input                     key_add_10hz,
    input                     key_inc_duty,         // 占空比增加按键
    input                     key_dec_duty,         // 占空比减少按键
    input                     key_change_wave,      // 波形切换按键
    input            		  uart_rxd /* synthesis PAP_MARK_DEBUG="1"*/,   
    output           		  uart_txd /* synthesis PAP_MARK_DEBUG="1"*/,
    input            		  uart_rxd1 /* synthesis PAP_MARK_DEBUG="1"*/,   
    output           		  uart_txd1 /* synthesis PAP_MARK_DEBUG="1"*/,
    output        wire        da_clk /* synthesis PAP_MARK_DEBUG="1"*/,
    output        wire        ad_clk /* synthesis PAP_MARK_DEBUG="1"*/,
    output        wire [7:0]  da_data /* synthesis PAP_MARK_DEBUG="1"*/,
    input         wire [7:0]  ad_data_in/* synthesis PAP_MARK_DEBUG="1"*/,
    
    output        wire        auto_check_led,
    output        wire        led_wave,
    output                    lcd_spi_sclk    ,// 屏幕spi时钟接口
    output                    lcd_spi_mosi    ,// 屏幕spi数据接口
    output                    lcd_spi_cs      ,// 屏幕spi使能接口     
    output                    lcd_dc          ,// 屏幕 数据/命令 接口
    output                    lcd_reset       ,// 屏幕复位接口
    output                    lcd_blk          // 屏幕背光接口 
   );

//key signals
wire key_add_1000hz_neg;  // 频率+1000Hz按键消抖后下降沿
wire key_add_10hz_neg;    // 频率+10Hz按键消抖后下降沿
wire key_inc_duty_neg;    // 占空比增加按键消抖后下降沿
wire key_dec_duty_neg;    // 占空比减少按键消抖后下降沿
wire key_change_wave_neg; // 波形切换按键消抖后下降沿

//DDS signals
wire [7:0]    square_out/* synthesis PAP_MARK_DEBUG="1"*/; //方波波形
wire [7:0]    sin_out/* synthesis PAP_MARK_DEBUG="1"*/;    //正弦波波形
wire          wave_flag/* synthesis PAP_MARK_DEBUG="1"*/;  //波形输出标志 0：正弦波 1：方波 默认为0
//measure signals
wire [31:0]        duty       ;
wire [19:0]        ad_freq    ;
wire [7:0]         ad_max     ;
wire [7:0]         ad_min     ;
//fir signals
wire  [7:0]  ad_avg_data/* synthesis PAP_MARK_DEBUG="1"*/;
//fft signals
wire         fft_over/* synthesis PAP_MARK_DEBUG="1"*/;
wire         fft_start/* synthesis PAP_MARK_DEBUG="1"*/;
wire         lcd_draw_over/* synthesis PAP_MARK_DEBUG="1"*/;
wire [7:0]   o_fft_data_re/* synthesis PAP_MARK_DEBUG="1"*/;
wire [7:0]   o_fft_data_im/* synthesis PAP_MARK_DEBUG="1"*/;
wire         o_fft_data_vaild/* synthesis PAP_MARK_DEBUG="1"*/;
wire [31:0]  o_fft_data;
wire [7:0]   fft_data/* synthesis PAP_MARK_DEBUG="1"*/;

//pll signals
wire pll_lock;
wire pll1_lock;
wire clk_50M;
wire clk_30M;
wire rst_n;
//uart
wire            uart_tx_en; 
wire            uart_rx_done; 
wire            uart_tx_done; 
wire  [7:0]     uart_tx_data; 
wire  [7:0]     uart_rx_data; 
wire            uart_fft_over;
//auto check signals
wire         Goal_inc/* synthesis PAP_MARK_DEBUG="1"*/;
wire         Goal_dec/* synthesis PAP_MARK_DEBUG="1"*/;
assign rst_n = rst && pll_lock && pll1_lock ;
assign da_clk = ~ad_clk;
assign da_data = wave_flag ? square_out : sin_out;

pll_30m u_pll1 (
  .clkout0(clk_30M),    // output
  .lock(pll1_lock),          // output
  .clkin1(clk_27M)       // input
);
pll u_pll (
  .clkout0(ad_clk),    // output
  .clkout1(clk_50M),    // output
  .lock(pll_lock),          // output
  .clkin1(clk_30M)       // input
);


DDS_wave u_DDS_wave(
    .clk            (clk_50M),         // 连接DDS工作时钟
    .rst_n          (rst_n),       // 连接系统复位
    .key_add_1000hz (key_add_1000hz_neg),  // 连接消抖后的+1000Hz按键
    .key_add_10hz   (key_add_10hz_neg),    // 连接消抖后的+10Hz按键
    .key_inc_duty   (key_inc_duty_neg),    // 连接消抖后的占空比增加按键
    .key_dec_duty   (key_dec_duty_neg),    // 连接消抖后的占空比减少按键
    .key_change_wave(key_change_wave_neg), // 连接消抖后的波形切换按键
    .wave_flag      (wave_flag),       //波形输出标志 0：正弦波 1：方波 默认为0 
    .square_data    (square_out),      // 方波输出
    .sin_data       (sin_out)          // 正弦波输出
);


measure u_measure (
    // 输入端口连接
    .clk_50M      (clk_50M),    // 连接系统50MHz时钟
    .rst_n        (rst_n),      // 连接系统复位信号
    .ad_data_in   (ad_avg_data),     // 连接外部AD输入数据
    .ad_clk       (ad_clk),         // 输出AD时钟（可直接连接到AD芯片的时钟引脚）
    // 输出端口连接
    
    .duty         (duty),     // 占空比结果输出
    .ad_freq      (ad_freq),        // 频率结果输出
    .ad_max       (ad_max),          // 最大值结果输出
    .ad_min       (ad_min)
);

auto_check u_auto_check (
    .clk        ( clk_50M          ), // 输入：系统时钟
    .rst_n      ( rst_n        ), // 输入：复位信号 (低有效)
    .Goal_inc   ( Goal_inc        ), // 输入：目标频率增加按键
    .Goal_dec   ( Goal_dec        ), // 输入：目标频率减小按键
    .ad_freq    ( ad_freq    ), // 输入：实际测量的频率值 [19:0]
    
    .Goal_flag  ( auto_check_led    )  // 输出：实际频率是否在目标范围内
);

wave_detector u_wave_detector (
    .clk          (ad_clk),         // 连接AD采样时钟
    .rst_n        (rst_n),
    .ad_data_in   (ad_avg_data),    // 连接平滑后的AD数据
    .ad_max_in    (ad_max),         // 连接测量模块输出的 Max
    .ad_min_in    (ad_min),         // 连接测量模块输出的 Min
    .is_square    (led_wave)
);

bluetooth_data u_bluetooth_data (
    .clk            (clk_50M),
    .ad_clk         (ad_clk),
    .rst_n          (rst_n),
    .fft_data       (fft_data),
    .fft_data_vaild (o_fft_data_vaild),
    .uart_tx_done   (uart_tx_done),
    .uart_tx_en     (uart_tx_en),
    .uart_tx_data   (uart_tx_data),
    .uart_fft_over  (uart_fft_over)
);

uart_top uart2_top_inst (
    .sys_clk      (clk_50M),    // 系统时钟，需与 UART 内部波特率适配
    .sys_rst_n    (rst_n),        // 系统复位（低电平有效，与模块定义一致）
    
    .uart_rxd     (uart_rxd1), // 连接外部 UART 接收引脚
    .uart_txd     (uart_txd1), // 连接外部 UART 发送引脚
    
    .uart_tx_en   (uart_tx_en),   
    .uart_rx_done (uart_rx_done), 
    .uart_tx_done (uart_tx_done), 
    
    .uart_tx_data (uart_tx_data), 
    .uart_rx_data (uart_rx_data)  
);



fft_lcd_state_control u_fft_lcd_state_control(
    .clk        (ad_clk),     
    .rst_n      (rst_n),   // 复位信号（低有效）
    .lcd_draw_over(uart_fft_over),
    .ad_data    (ad_avg_data),     // AD采集数据输入
    .fft_over   (fft_over),    // FFT运算完成信号输入
    .fft_start  (fft_start)    // FFT启动信号输出
);


fft_control u_fft_control (
    .clk            (ad_clk),      
    .rst_n          (rst_n),    // 连接系统复位
    .fft_start      (fft_start),
    .fft_over       (fft_over),
    .i_fft_data     (ad_avg_data),      // 连接输入数据
    .fft_data       (fft_data),
    .o_fft_data     (o_fft_data),
    .o_fft_data_vaild(o_fft_data_vaild),
    .o_fft_data_re     (o_fft_data_re),  // 连接输出数据
    .o_fft_data_im     (o_fft_data_im)
);

lcd_top u_lcd_top(
    .sys_clk         (clk_50M   ),  // 连接系统时钟
    .sys_rst_n       (rst_n     ),  // 连接系统复位
    .ad_clk          (ad_clk   ), 
    .o_fft_data_vaild(o_fft_data_vaild), 
    .o_fft_data      (fft_data      ),
    .lcd_draw_over   (lcd_draw_over),
    // LCD屏幕接口连接
    .lcd_spi_sclk    (lcd_spi_sclk  ),
    .lcd_spi_mosi    (lcd_spi_mosi  ),
    .lcd_spi_cs      (lcd_spi_cs    ),
    .lcd_dc          (lcd_dc        ),
    .lcd_reset       (lcd_reset     ),
    .lcd_blk         (lcd_blk       )
);

Bluetooth_send u_Bluetooth_send(
    .sys_clk       (clk_50M),      // 连接系统时钟
    .rst_n         (rst_n),    // 连接系统复位（低电平有效）
    
    .uart_rxd      (uart_rxd),// 连接蓝牙模块的UART接收端（FPGA接收蓝牙数据）
    .uart_txd      (uart_txd),// 连接蓝牙模块的UART发送端（FPGA向蓝牙发送数据）
    .Goal_inc      (Goal_inc), 
    .Goal_dec      (Goal_dec), 
    .duty_cycle    (duty),   // 接入占空比测量数据
    .ad_fred       (ad_freq),      // 接入频率测量数据（修正原"ad_fred"拼写）
    .ad_max        (ad_max)        // 接入最大值测量数据
);


avg_filter_8bit #(
    .N(16)  // 可调整为4/16，根据噪声情况优化
) u_avg_filter (
    .clk(ad_clk),         // 连接AD采样时钟（如ad_clk）
    .rst_n(rst_n), // 连接系统复位
    .data_in(ad_data_in), // 连接8bit AD原始数据
    .data_out(ad_avg_data) // 输出平滑后的数据
);



key_debounce u_key_1000hz_debounce (
    .sys_clk       (clk_50M),         // 系统时钟输入
    .rst_n         (rst_n),           // 复位信号（低有效）
    .key           (key_add_1000hz),  // 原始按键输入（+1000Hz）
    .button_negedge(key_add_1000hz_neg) // 消抖后的下降沿信号
);

key_debounce u_key_10hz_debounce (
    .sys_clk       (clk_50M),         // 系统时钟输入
    .rst_n         (rst_n),           // 复位信号（低有效）
    .key           (key_add_10hz),    // 原始按键输入（+10Hz）
    .button_negedge(key_add_10hz_neg) // 消抖后的下降沿信号
);

key_debounce u_key_inc_duty_debounce (
    .sys_clk       (clk_50M),         // 系统时钟输入
    .rst_n         (rst_n),           // 复位信号（低有效）
    .key           (key_inc_duty),    // 原始按键输入（占空比+）
    .button_negedge(key_inc_duty_neg) // 消抖后的下降沿信号
);


key_debounce u_key_dec_duty_debounce (
    .sys_clk       (clk_50M),         // 系统时钟输入
    .rst_n         (rst_n),           // 复位信号（低有效）
    .key           (key_dec_duty),    // 原始按键输入（占空比-）
    .button_negedge(key_dec_duty_neg) // 消抖后的下降沿信号
);



key_debounce u_key_change_wave_debounce (
    .sys_clk       (clk_50M),         // 系统时钟输入
    .rst_n         (rst_n),           // 复位信号（低有效）
    .key           (key_change_wave),     // 原始按键输入（切换）
    .button_negedge(key_change_wave_neg)  // 消抖后的下降沿信号
);




endmodule
