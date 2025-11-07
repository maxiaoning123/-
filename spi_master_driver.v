`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: FPGA之旅 ----> ValentineHP
// 
// Create Date: 2023/07/08 08:38:50
// Design Name: 
// Module Name: spi_master_driver
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////



// //模式0：CPOL= 0，CPHA=0。SCK串行时钟线空闲是为低电平，数据在SCK时钟的上升沿被采样，数据在SCK时钟的下降沿切换
// //模式1：CPOL= 0，CPHA=1。SCK串行时钟线空闲是为低电平，数据在SCK时钟的下降沿被采样，数据在SCK时钟的上升沿切换
// //模式2：CPOL= 1，CPHA=0。SCK串行时钟线空闲是为高电平，数据在SCK时钟的下降沿被采样，数据在SCK时钟的上升沿切换
// //模式3：CPOL= 1，CPHA=1。SCK串行时钟线空闲是为高电平，数据在SCK时钟的上升沿被采样，数据在SCK时钟的下降沿切换




//模式3：CPOL= 1，CPHA=1。SCK串行时钟线空闲是为高电平，数据在SCK时钟的上升沿被采样，数据在SCK时钟的下降沿切换
module spi_master_driver(
    //系统接口
    input sys_clk                   ,
    input sys_rst_n                 ,

    //用户接口
    input           spi_start_i     ,   // spi开始信号
    input           spi_end_i       ,   // spi结束信号
    input[7:0]      spi_send_data_i ,   // spi发送数据
    output          spi_send_ack_o  ,   // spi发送8bit数据完成信号
      
    input           lcd_dc_i        ,   //数据还是命令信号输入
    output  reg     lcd_dc          ,   //数据还是命令信号输出
    //spi  端口
    output  reg     spi_sclk        ,
    output  reg     spi_mosi        ,
    output  reg     spi_cs          
);


reg[7:0] spi_send_data_reg;         //数据寄存器
reg[3:0] spi_send_data_bit_cnt;     //数据发送bit计数器
reg      spi_end_reg;               //spi结束标志


assign   spi_send_ack_o = ( spi_send_data_bit_cnt == 'd6 && spi_sclk == 1'b1) ? 1'b1 : 1'b0;


//发送数据缓存
always@(posedge sys_clk or negedge sys_rst_n) begin
    if( sys_rst_n == 1'b0 )
        spi_send_data_reg <= 'd0;
    else if(spi_send_data_bit_cnt == 'd0)    //8bit数据发送完成后，缓存新的数据
        spi_send_data_reg <= spi_send_data_i;
    else
        spi_send_data_reg <= spi_send_data_reg;
end

//结束spi发送
always@(posedge sys_clk or negedge sys_rst_n) begin
    if( sys_rst_n == 1'b0)
        spi_end_reg <= 1'b0;
    else if( spi_cs == 1'b1)   //清除结束标志
        spi_end_reg <= 1'b0;
    else if( spi_end_i == 1'b1)  //缓存结束标志
        spi_end_reg <= 1'b1;
    else
        spi_end_reg <= spi_end_reg;

end

//数据是命令还是数据
always@(posedge sys_clk or negedge sys_rst_n) begin
    if( sys_rst_n == 1'b0)
        lcd_dc <= 1'b1;
    else if( spi_start_i == 1'b1)
        lcd_dc <= lcd_dc_i;
    else
        lcd_dc <= lcd_dc;
end

//片选spi
always@(posedge sys_clk or negedge sys_rst_n) begin
    if( sys_rst_n == 1'b0)
        spi_cs <= 1'b1;
    else if( spi_end_reg == 1'b1 && spi_send_data_bit_cnt == 'd0)
        spi_cs <= 1'b1;
    else if( spi_start_i == 1'b1 )  
        spi_cs <= 1'b0;
    else
        spi_cs <= spi_cs;
end


//产生spi时钟
always@(posedge sys_clk or negedge sys_rst_n) begin
    if( sys_rst_n == 1'b0)
        spi_sclk <= 1'b1;
    else if( spi_end_reg == 1'b1 && spi_send_data_bit_cnt == 'd0)
        spi_sclk <= spi_sclk;
    else if( spi_cs == 1'b0 )
        spi_sclk <= ~spi_sclk;
    else 
        spi_sclk <= 1'b1;
end


//数据发送bit数寄存器
always@(posedge sys_clk or negedge sys_rst_n) begin
    if( sys_rst_n == 1'b0) 
        spi_send_data_bit_cnt <= 'd0;
   else if( spi_end_reg == 1'b1 && spi_send_data_bit_cnt == 'd0)
        spi_send_data_bit_cnt <= 'd0;
    else if( spi_cs == 1'b0 && spi_sclk == 1'b0)
        if( spi_send_data_bit_cnt == 'd7)
            spi_send_data_bit_cnt <= 'd0;
        else
            spi_send_data_bit_cnt <= spi_send_data_bit_cnt + 1'b1;
    else if( spi_cs == 1'b0)
        spi_send_data_bit_cnt <= spi_send_data_bit_cnt;
    else
        spi_send_data_bit_cnt <= 'd0;
end

//spi数据发送
always@(posedge sys_clk or negedge sys_rst_n) begin
    if( sys_rst_n == 1'b0)
        spi_mosi <= 1'b1;
    else if( spi_cs == 1'b0)
        spi_mosi <= spi_send_data_reg['d7 - spi_send_data_bit_cnt];
    else
        spi_mosi <= spi_mosi;
end

endmodule