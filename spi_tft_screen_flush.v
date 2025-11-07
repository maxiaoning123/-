`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:  FPGA之旅 ----> ValentineHP
// 
// Create Date: 2023/07/13 22:12:18
// Design Name: 
// Module Name: spi_tft_screen_flush
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

//对spi tft屏幕进行刷新
module spi_tft_screen_flush(
    input           sys_clk                   ,
    input           sys_rst_n                 ,

    
    //用户接口
    input[7:0]      spi_screen_flush_data_i   ,  //屏幕显示数据
    output          spi_screen_flush_updte_o  ,  //像素点数据刷新
    output          spi_screen_flush_fsync_o  ,  //屏幕帧同步
    //------
    
    

    //驱动模块
    input           tft_screen_flush_req_i    ,  //刷新请求
    output reg[7:0] tft_screen_flush_data_o   ,  //刷新数据
    output reg      tft_screen_flush_dc_o     ,  //刷新dc

    //SPI主模块     
    output          spi_send_flush_req_o      ,  //spi发送数据请求
    output          spi_send_flush_end_o      ,  //结束spi发送
    input           spi_send_flush_ack_i         //spi一个数据发送完成
);
parameter   SCREEN_WIDTH  = 16'd320;
parameter   SCREEN_HEIGHT = 16'd240;
parameter Number_Of_Pixels = 32'd240*32'd320*32'd2 ; // 像素点个数


localparam S_IDLE       = 4'b0001;
localparam S_DATA       = 4'b0010;  //发送数据
localparam S_DELAY      = 4'b0100;  //延时
localparam S_FRAME_SYNC = 4'b1000;  // 帧同步


localparam DELAY_5clk = 'd5; //命令与数据之间切换等待5个时钟周期

reg[31:0]   flush_cnt;
reg[12:0]   delay_cnt;
reg[3:0] state , next_state;


assign spi_send_flush_req_o = (state == S_DATA) ? 1'b1 : 1'b0;
assign spi_send_flush_end_o = (state == S_DELAY || state == S_FRAME_SYNC) ? 1'b1 : 1'b0;


assign spi_screen_flush_updte_o = ( spi_send_flush_ack_i == 1'b1 && flush_cnt >= 'd11 ) ? 1'b1 : 1'b0;
assign spi_screen_flush_fsync_o = ( state == S_FRAME_SYNC ) ? 1'b1 : 1'b0;

always@(posedge sys_clk or negedge sys_rst_n) begin
    if( sys_rst_n == 1'b0 )
        state <= S_IDLE;
    else
        state <= next_state;
end


always@(*) begin
    case(state)
    S_IDLE:
        if( tft_screen_flush_req_i == 1'b1 )
            next_state = S_DATA;
        else
            next_state = S_IDLE;
    S_DATA:
        if( spi_send_flush_ack_i == 1'b1 && flush_cnt <= 'd10 )  //设置XY
            next_state = S_DELAY;
        else if( spi_send_flush_ack_i == 1'b1 && flush_cnt == (Number_Of_Pixels + 'd10))  //一帧图像数据发送完成
            next_state = S_FRAME_SYNC;
        else
            next_state = S_DATA;
    S_DELAY:
        if( delay_cnt == DELAY_5clk)
            next_state = S_DATA;
        else
            next_state = S_DELAY;
    S_FRAME_SYNC:
        next_state = S_IDLE;
    default: next_state = S_IDLE;
    endcase
end


//发送数据计数
always@(posedge sys_clk or negedge sys_rst_n) begin
    if( sys_rst_n == 1'b0 )
        flush_cnt <= 'd0;
    else if( spi_send_flush_ack_i == 1'b1 &&  flush_cnt == (Number_Of_Pixels + 'd10))
        flush_cnt <= 'd0;
    else if( spi_send_flush_ack_i == 1'b1 )
        flush_cnt <= flush_cnt + 1'b1;
    else
        flush_cnt <= flush_cnt;
end


//延时计数
always@(posedge sys_clk or negedge sys_rst_n) begin
    if( sys_rst_n == 1'b0)
        delay_cnt <= 'd0;
    else if( state == S_DELAY)
        delay_cnt <= delay_cnt + 1'b1;
    else
        delay_cnt <= 'd0;
end


always @(*) begin
    case(flush_cnt)
    'd0: begin
        tft_screen_flush_data_o = 8'h2A;
        tft_screen_flush_dc_o   = 1'b0;
    end
    //写X
    'd1: begin
        tft_screen_flush_data_o = 8'h00;
        tft_screen_flush_dc_o   = 1'b1;
    end
    'd2: begin
        tft_screen_flush_data_o = 8'h00;
        tft_screen_flush_dc_o   = 1'b1;
    end
    'd3: begin
        tft_screen_flush_data_o = SCREEN_WIDTH[15:8];
        tft_screen_flush_dc_o   = 1'b1;
    end
    'd4: begin
        tft_screen_flush_data_o = SCREEN_WIDTH[7:0] - 1'b1;
        tft_screen_flush_dc_o   = 1'b1;
    end
    //写Y
    'd5: begin
        tft_screen_flush_data_o = 8'h2B;
        tft_screen_flush_dc_o   = 1'b0;
    end
    'd6: begin
        tft_screen_flush_data_o = 8'h00;
        tft_screen_flush_dc_o   = 1'b1;
    end
    'd7: begin
        tft_screen_flush_data_o = 8'h00;
        tft_screen_flush_dc_o   = 1'b1;
    end
    'd8: begin
        tft_screen_flush_data_o = SCREEN_HEIGHT[15:8];
        tft_screen_flush_dc_o   = 1'b1;
    end
    'd9: begin
        tft_screen_flush_data_o = SCREEN_HEIGHT[7:0] - 1'b1;
        tft_screen_flush_dc_o   = 1'b1;
    end

    //写数据
    'd10: begin
        tft_screen_flush_data_o = 8'h2C;
        tft_screen_flush_dc_o   = 1'b0;
    end
    default: begin
        tft_screen_flush_data_o = spi_screen_flush_data_i;  //图像显示数据
        tft_screen_flush_dc_o   = 1'b1;
    end
    endcase
end




endmodule
