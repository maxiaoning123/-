`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:  FPGA之旅 ----> ValentineHP
// 
// Create Date: 2023/07/19 19:38:26
// Design Name: 
// Module Name: screen_driver
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


module screen_driver(
    input       sys_clk         ,
    input       sys_rst_n       , 

    //用户信号
    output       flush_data_update_o  ,  //更新当前坐标点显示数据使能
    input[15:0]  flush_data_i         ,  //当前坐标点显示的数据
    output[15:0] flush_addr_width_o   ,  //当前刷新的x坐标
    output[15:0] flush_addr_height_o  ,  //当前刷新的y坐标
    //----


     //spi tft screen   屏幕接口          
    output      lcd_spi_sclk    ,           // 屏幕spi时钟接口
    output      lcd_spi_mosi    ,           // 屏幕spi数据接口
    output      lcd_spi_cs      ,           // 屏幕spi使能接口     
    output      lcd_dc          ,           // 屏幕 数据/命令 接口
    output      lcd_reset       ,           // 屏幕复位接口
    output      lcd_blk                     // 屏幕背光接口

);

parameter   SCREEN_WIDTH  = 32'd320;
parameter   SCREEN_HEIGHT = 32'd240;

//屏幕用户接口
reg[7:0]  spi_screen_flush_data   ;  //屏幕显示数据
wire      spi_screen_flush_updte  ;  //像素点数据刷新
wire      spi_screen_flush_fsync  ;  //屏幕帧同步
//------

//长宽计数器
reg[15:0]   width_cnt   ;
reg[15:0]   height_cnt  ;

//数据更新
reg         data_update_cnt;


//跟新数据寄存器
reg[15:0]   flush_data_reg;


assign flush_data_update_o  = (spi_screen_flush_updte == 1'b1 && data_update_cnt == 1'b1) ? 1'b1 : 1'b0;
assign flush_addr_width_o   = width_cnt;
assign flush_addr_height_o  = height_cnt;

always@(posedge sys_clk or negedge sys_rst_n) begin
    if( sys_rst_n == 1'b0)
        data_update_cnt <= 'd0;
    else if( spi_screen_flush_fsync == 1'b1 )
        data_update_cnt <= 'd0;
    else if( spi_screen_flush_updte == 1'b1)
        data_update_cnt <= data_update_cnt + 1'b1;
    else
        data_update_cnt <= data_update_cnt;
end


always@(posedge sys_clk or negedge sys_rst_n) begin
    if( sys_rst_n == 1'b0 )
        width_cnt <= 'd0;
    else if( spi_screen_flush_fsync == 1'b1 )
        width_cnt <= 'd0;
    else if( spi_screen_flush_updte == 1'b1 && data_update_cnt == 1'b1)
        if( width_cnt == (SCREEN_WIDTH - 1'b1))
            width_cnt <= 'd0;
        else
            width_cnt <= width_cnt + 1'b1;
    else
        width_cnt <= width_cnt;
end


always@(posedge sys_clk or negedge sys_rst_n) begin
    if( sys_rst_n == 1'b0 )
        height_cnt <= 'd0;
    else if( spi_screen_flush_fsync == 1'b1)
        height_cnt <= 'd0;
    else if( width_cnt == (SCREEN_WIDTH - 1'b1) && spi_screen_flush_updte == 1'b1 && data_update_cnt == 1'b1)
        height_cnt <= height_cnt + 1'b1;
    else
        height_cnt <= height_cnt;
end



always@(posedge sys_clk or negedge sys_rst_n) begin
    if( sys_rst_n == 1'b0)
        flush_data_reg = 'd0;
    else if( spi_screen_flush_updte == 1'b1)
        if( data_update_cnt == 1'b0 )
            flush_data_reg = flush_data_i;
        else
            flush_data_reg = flush_data_reg << 8;
    else
        flush_data_reg = flush_data_reg;
end


always@(posedge sys_clk or negedge sys_rst_n) begin
    if( sys_rst_n == 1'b0)
        spi_screen_flush_data <= 'd0;
    else 
        spi_screen_flush_data <= flush_data_reg[15:0];
end


spi_tft_screen_driver spi_tft_screen_driver_hp(
    .sys_clk            (   sys_clk         ),
    .sys_rst_n          (   sys_rst_n       ),


    //用户接口
    .spi_screen_flush_data_i   (    spi_screen_flush_data   ),  //屏幕显示数据
    .spi_screen_flush_updte_o  (    spi_screen_flush_updte  ),  //像素点数据刷新
    .spi_screen_flush_fsync_o  (    spi_screen_flush_fsync  ),  //屏幕帧同步
    //------


     //spi tft screen   屏幕接口          
    .lcd_spi_sclk       (   lcd_spi_sclk    ),           // 屏幕spi时钟接口
    .lcd_spi_mosi       (   lcd_spi_mosi    ),           // 屏幕spi数据接口
    .lcd_spi_cs         (   lcd_spi_cs      ),           // 屏幕spi使能接口     
    .lcd_dc             (   lcd_dc          ),           // 屏幕 数据/命令 接口
    .lcd_reset          (   lcd_reset       ),           // 屏幕复位接口
    .lcd_blk            (   lcd_blk         )            // 屏幕背光接口
);
endmodule
