module DDS_wave(
    input clk,
    input rst_n,
    input key_add_1000hz,
    input key_add_10hz,
    input key_inc_duty,         // 占空比增加按键
    input key_dec_duty,         // 占空比减少按键
    input key_change_wave,
    output reg   wave_flag,
    output [7:0] square_data,
    output [7:0] sin_data
   );
parameter fre_word = 32'd1717991; 
reg [31:0] addr;
reg [31:0] key_word;

always @(posedge clk or  negedge rst_n)  
begin
    if(!rst_n)
        key_word <= 32'd0;
    else  if(key_add_1000hz)  
        key_word <= key_word + 32'd858990;
    else  if(key_add_10hz)  
        key_word <= key_word + 32'd86;
    else 
        key_word <= key_word;
end

always @(posedge clk or  negedge rst_n)  
begin
    if(!rst_n)
        addr <= 32'b0;
    else
        addr <= addr + fre_word + key_word;
end

wire [11:0]addra = addr[31:20];
sin_wave u_sin_wave (
  .addr(addra),          // input [11:0]
  .clk(clk),            // input
  .rst(~rst_n),            // input
  .rd_data(sin_data)     // output [7:0]
);

reg [11:0] duty_cycle;         // 占空比阈值（0~4095，对应0~100%）
//reg        wave_flag;          //波形输出标志 0：正弦波 1：方波 默认为0
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        duty_cycle <= 12'd2048;  // 初始占空比50%（2048/4096）
    else if(key_inc_duty) begin
        // 限制最大值为4095（100%）
        duty_cycle <= (duty_cycle >= 12'd4095) ? 12'd4095 : duty_cycle + 12'd16;
    end
    else if(key_dec_duty) begin
        // 限制最小值为0（0%）
        duty_cycle <= (duty_cycle <= 12'd0) ? 12'd0 : duty_cycle - 12'd16;
    end
    else
        duty_cycle <= duty_cycle;
end

assign square_data = (addra < duty_cycle) ? 8'h00  : 8'hFF;// 高电平时输出幅值参数，低电平时输出0

always @(posedge clk or  negedge rst_n)  
begin
    if(!rst_n)
        wave_flag <= 1'b0;
    else if(key_change_wave)
        wave_flag <= ~wave_flag;
end

endmodule