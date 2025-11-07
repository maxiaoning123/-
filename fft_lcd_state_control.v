module fft_lcd_state_control(
    input             clk,//与ad时钟保持一致
    input             rst_n,
    input [7:0]       ad_data,          //输入ad采样滤波后的数据
    input             fft_over,         //fft计算完标志
    input             lcd_draw_over,    //lcd画图画完标志
    output    reg     fft_start         //fft计算开始标志
    
    
   );


parameter IDLE      = 4'd0;
parameter START     = 4'd1;
parameter FFT       = 4'd2;
parameter LCD_DRAW  = 4'd3;
parameter OVER      = 4'd4;
parameter WAIT      = 4'd5;
reg    [3:0]         state /* synthesis PAP_MARK_DEBUG="1"*/;
//reg    [31:0]        wait_count
//fft 开始标志
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        fft_start <= 1'b0;
    end
    else if (state == START) begin 
        fft_start <= 1'b1;
    end
    else begin
        fft_start <= 1'b0;
    end
end
//fft与lcd画图大状态控制
always @(posedge clk or  negedge rst_n)  
begin
    if(!rst_n)begin
        state <= IDLE;
    end
    else begin
        case(state)
        IDLE:begin
            state <= START;
        end
        START:begin
            state <= FFT;
        end
        FFT:begin
            if(fft_over)begin
                state <= LCD_DRAW;
            end
            else begin
                state <= FFT;           
            end
        end

        LCD_DRAW:begin
            if(lcd_draw_over)begin
                state <= IDLE;
            end
            else begin
                state <= LCD_DRAW;           
            end
        end
//        OVER:begin
//            state <= IDLE;
//        end
        default:state <= IDLE;
        endcase
    end 
end

//always @(posedge clk or negedge rst_n) begin
//    if (!rst_n) begin
//        wait_count <= 32'd0;
//    end
//    else if (state == LCD_DRAW && wait_count < 32'd100000) begin 
//        wait_count <= wait_count+ 32'd1;
//    end
//    else if (state == LCD_DRAW && wait_count == 32'd100000) begin 
//        wait_count <= 32'd0;
//    end
//    else begin
//        wait_count <= 32'd0;
//    end
//end



endmodule