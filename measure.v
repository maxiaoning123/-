module measure(
    input               clk_50M ,       // 时钟
    input               rst_n  ,    // 复位信号

    input                ad_clk,     // AD时钟
    input      [7:0]     ad_data_in,
    output [31:0]        duty,
    output [19:0]        ad_freq,
    output [7:0]         ad_max,
    output [7:0]         ad_min
    

    
);
wire              ad_pulse/* synthesis PAP_MARK_DEBUG="1"*/;   //pulse_gen模块输出的脉冲信号,仅用于调试
wire              ad_pulse_reg/* synthesis PAP_MARK_DEBUG="1"*/;   

wire  [7:0]    ad_vpp;   // AD峰峰值 

//wire      [7:0]    ad_min;      // AD最小值
//parameter define
parameter CLK_FS = 26'd50_000_000;  // 基准时钟频率值

//wire clk_100m;
wire [17:0]o_duty_num;

signal_fir u_signal_fir(
    .sys_clk       (clk_50M),     // 连接系统时钟（确保滤波时序与系统同步）
    .rst_n         (rst_n),   // 连接系统复位（低电平有效）
    .TTL_signal    (ad_pulse_reg),     // 输入带毛刺的原始TTL信号
    .TTL_signal_fir(ad_pulse) // 输出滤波后的稳定TTL信号
);


//脉冲生成模块
pulse_gen u_pulse_gen(
    .rst_n          (rst_n),        //系统复位，低电平有效

    .trig_level     (8'd128),   // 触发电平
    .ad_clk         (ad_clk),       //AD9280驱动时钟
    .ad_data        (ad_data_in),      //AD输入数据

    .ad_pulse       (ad_pulse_reg)      //输出的脉冲信号
    );

//等精度频率计模块
cymometer #(
    .CLK_FS         (CLK_FS)        // 基准时钟频率值
) u_cymometer(
    .clk_fs         (clk_50M),
    .rst_n          (rst_n),

    .clk_fx         (ad_pulse),     // 被测时钟信号
    .data_fx        (ad_freq)       // 被测时钟频率输出
    );

//计算峰峰值
vpp_measure u_vpp_measure(
    .rst_n          (rst_n),
    
    .ad_clk         (ad_clk), 
    .ad_data        (ad_data_in),
    .ad_pulse       (ad_pulse),
    .ad_vpp         (ad_vpp),
    .ad_max         (ad_max),
    .ad_min         (ad_min)
    );
wire [31:0]high_time;
wire [31:0]low_time;

duty_cycle u_duty_cycle(
    .clk(clk_50M),
    
    .rst_n(rst_n),
    .signal_in(ad_pulse),
    .high_time(high_time),
    .low_time(low_time),
    .duty(duty)
);
endmodule
