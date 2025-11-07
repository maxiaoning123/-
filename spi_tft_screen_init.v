`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: FPGA之旅 ----> ValentineHP
// 
// Create Date: 2023/07/08 18:40:05
// Design Name: 
// Module Name: spi_tft_screen_init
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



//对spi tft屏幕进行初始化
module spi_tft_screen_init(
    input           sys_clk                 ,
    input           sys_rst_n               ,


    input           tft_screen_init_req_i   ,  //初始化请求
    output          tft_screen_init_ack_o   ,  //初始化完成  
    output reg[7:0] tft_screen_init_data_o  ,  //初始化数据
    output reg      tft_screen_init_dc_o    ,  //初始化dc

    output          spi_send_init_req_o     ,  //spi发送数据请求
    output          spi_send_init_end_o     ,  //结束spi发送
    input           spi_send_init_ack_i        //spi一个数据发送完成
);
parameter   SCREEN_WIDTH  = 16'd320;
parameter   SCREEN_HEIGHT = 16'd240;
parameter   SCREEN_ORIENT = 2'b00;


localparam DELAY_255ms = 32'd255_000;//32'd255_000;  //255ms
localparam DELAY_200us = 32'd10; //200us


localparam  S_IDLE      = 4'b0001;
localparam  S_SEND_DATA = 4'b0010;
localparam  S_DELAY     = 4'b0100;
localparam  S_ACK       = 4'b1000;


reg[4:0]    init_cnt;    //初始化命令/数据计数
reg[31:0]   delay_cnt;   //延时计数
reg[3:0]    next_state;
reg[3:0]    state ;



assign tft_screen_init_ack_o = (state == S_ACK) ? 1'b1 : 1'b0;
assign spi_send_init_req_o   = (state == S_SEND_DATA) ? 1'b1 : 1'b0;
assign spi_send_init_end_o   = (state == S_DELAY) ? 1'b1 : 1'b0;

always@(posedge sys_clk or negedge sys_rst_n) begin
    if( sys_rst_n == 1'b0)
        state <= S_IDLE;
    else
        state <= next_state;  // 对state使用非阻塞赋值是正确的
end


always@(*) begin
    // 在组合逻辑块中，对next_state应使用阻塞赋值
    case(state)
    S_IDLE:
        if( tft_screen_init_req_i == 1'b1)
            next_state = S_SEND_DATA;  // 修改为阻塞赋值
        else
            next_state = S_IDLE;       // 修改为阻塞赋值
    S_SEND_DATA:
        if( spi_send_init_ack_i == 1'b1)
            next_state = S_DELAY;      // 修改为阻塞赋值
        else
            next_state = S_SEND_DATA;  // 修改为阻塞赋值
    S_DELAY:
        if( init_cnt == 'd19)
            if( delay_cnt == DELAY_255ms)
                next_state = S_ACK;    // 修改为阻塞赋值
            else
                next_state = S_DELAY;  // 修改为阻塞赋值
        else if(init_cnt == 'd1 )
            if(delay_cnt == DELAY_255ms)
                next_state = S_SEND_DATA;  // 修改为阻塞赋值
            else
                next_state = S_DELAY;      // 修改为阻塞赋值
        else if(init_cnt == 'd2 )
             if(delay_cnt == DELAY_255ms)
                next_state = S_SEND_DATA;  // 修改为阻塞赋值
            else
                next_state = S_DELAY;      // 修改为阻塞赋值
        else if(init_cnt == 'd4 )
              if(delay_cnt == DELAY_255ms)
                next_state = S_SEND_DATA;  // 修改为阻塞赋值
            else
                next_state = S_DELAY;      // 修改为阻塞赋值
        else if(init_cnt == 'd17 )
              if(delay_cnt == DELAY_255ms)
                next_state = S_SEND_DATA;  // 修改为阻塞赋值
            else
                next_state = S_DELAY;      // 修改为阻塞赋值
        else if(init_cnt == 'd18 )
            if(delay_cnt == DELAY_255ms)
                next_state = S_SEND_DATA;  // 修改为阻塞赋值
            else
                next_state = S_DELAY;      // 修改为阻塞赋值
        else if( delay_cnt == DELAY_200us)
            next_state = S_SEND_DATA;      // 修改为阻塞赋值
        else
            next_state = S_DELAY;          // 修改为阻塞赋值
    S_ACK:
        next_state = S_IDLE;              // 修改为阻塞赋值
    default: next_state = S_IDLE;         // 修改为阻塞赋值
    endcase

end




//初始化数据计数
always@(posedge sys_clk or negedge sys_rst_n) begin
    if( sys_rst_n == 1'b0) 
        init_cnt <= 'd0;
    else if( spi_send_init_ack_i == 1'b1)
        init_cnt <= init_cnt + 1'b1;
    else
        init_cnt <= init_cnt;
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


//命令数据输出
always@(*)begin
    case (init_cnt)
        'd0: begin
            tft_screen_init_data_o  = 8'h01;
            tft_screen_init_dc_o    = 1'b0;
        end
        'd1: begin
            tft_screen_init_data_o  = 8'h11;
            tft_screen_init_dc_o    = 1'b0;
        end
        'd2: begin
            tft_screen_init_data_o  = 8'h3A;
            tft_screen_init_dc_o    = 1'b0;
        end
        'd3: begin
            tft_screen_init_data_o  = 8'h55;
            tft_screen_init_dc_o    = 1'b1;
        end
        'd4: begin
            tft_screen_init_data_o  = 8'h36;
            tft_screen_init_dc_o    = 1'b0;
        end
        'd5: begin
            tft_screen_init_data_o  = 8'h78;
            tft_screen_init_dc_o    = 1'b1;
        end
        'd6: begin
            tft_screen_init_data_o  = 8'h2A;
            tft_screen_init_dc_o    = 1'b0;
        end

        'd7: begin
            tft_screen_init_data_o  = 8'h00;
            tft_screen_init_dc_o    = 1'b1;
        end
        'd8: begin
            tft_screen_init_data_o  = 8'h00;
            tft_screen_init_dc_o    = 1'b1;
        end
        'd9: begin
            tft_screen_init_data_o  = SCREEN_WIDTH[15:8];
            tft_screen_init_dc_o    = 1'b1;
        end
        'd10: begin
            tft_screen_init_data_o  = SCREEN_WIDTH[7:0] - 1'b1;
            tft_screen_init_dc_o    = 1'b1;
        end

        'd11: begin
            tft_screen_init_data_o  = 8'h2B;
            tft_screen_init_dc_o    = 1'b0;
        end

        'd12: begin
            tft_screen_init_data_o  = 8'h00;
            tft_screen_init_dc_o    = 1'b1;
        end
        'd13: begin
            tft_screen_init_data_o  = 8'h00;
            tft_screen_init_dc_o    = 1'b1;
        end
        'd14: begin
            tft_screen_init_data_o  = SCREEN_HEIGHT[15:8];
            tft_screen_init_dc_o    = 1'b1;
        end
        'd15: begin
            tft_screen_init_data_o  = SCREEN_HEIGHT[7:0] - 1'b1;
            tft_screen_init_dc_o    = 1'b1;
        end
        'd16: begin
            tft_screen_init_data_o  = 8'h21;
            tft_screen_init_dc_o    = 1'b0;
        end
        'd17: begin
            tft_screen_init_data_o  = 8'h13;
            tft_screen_init_dc_o    = 1'b0;
        end
        'd18: begin
            tft_screen_init_data_o  = 8'h29;
            tft_screen_init_dc_o    = 1'b0;
        end
        default: begin
            tft_screen_init_data_o  = 8'h01;
            tft_screen_init_dc_o    = 1'b0;
        end
    endcase
end

endmodule
