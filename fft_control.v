module fft_control(
    input                 clk,
    input                 rst_n,
    input                 fft_start,
    output reg            fft_over,
    input  [7:0]          i_fft_data,//2048点
    
    output wire           o_fft_data_vaild,
    output wire [7:0]     fft_data,
    output wire [31:0]    o_fft_data,
    output [7:0]          o_fft_data_re/* synthesis PAP_MARK_DEBUG="1"*/,
    output [7:0]          o_fft_data_im/* synthesis PAP_MARK_DEBUG="1"*/
    
   );
parameter IDLE      = 4'd0;
parameter START     = 4'd1;
parameter FFT_IN    = 4'd2;
parameter FFT_OUT   = 4'd3;
parameter OVER      = 4'd4;
reg  [3:0]      state;

wire [31:0]     i_axi4s_data_tdata/* synthesis PAP_MARK_DEBUG="1"*/;//输入数据 虚部+实部
reg             i_axi4s_data_tvalid/* synthesis PAP_MARK_DEBUG="1"*/;//数据有效标志
wire            i_axi4s_data_tlast/* synthesis PAP_MARK_DEBUG="1"*/;//最后一个数据有效标志
reg  [10:0]     i_axi4s_data_count/* synthesis PAP_MARK_DEBUG="1"*/;//输入数据计数器  

wire [63:0]     o_axi4s_data_tdata/* synthesis PAP_MARK_DEBUG="1"*/;//输出数据 虚部+实部
wire            o_axi4s_data_tvalid/* synthesis PAP_MARK_DEBUG="1"*/;//输出数据有效标志
wire            o_axi4s_data_tlast/* synthesis PAP_MARK_DEBUG="1"*/;//输出最后一个数据有效标志
wire [23:0]     o_axi4s_data_tuser/* synthesis PAP_MARK_DEBUG="1"*/;//user
wire [10:0]      o_axi4s_data_count/* synthesis PAP_MARK_DEBUG="1"*/;//输出数据计数器
wire            o_axi4s_data_tready/* synthesis PAP_MARK_DEBUG="1"*/;//当前允许输入数据
wire            o_alm/* synthesis PAP_MARK_DEBUG="1"*/;
wire            o_stat/* synthesis PAP_MARK_DEBUG="1"*/;
wire [31:0]     fft_data_re/* synthesis PAP_MARK_DEBUG="1"*/;//输出数据实部
wire [31:0]     fft_data_im/* synthesis PAP_MARK_DEBUG="1"*/;//输出数据实部
assign i_axi4s_data_tdata ={24'h0,i_fft_data};
assign i_axi4s_data_tlast =(i_axi4s_data_count==11'd2047)?1'b1:1'b0;
assign o_fft_data_re = o_axi4s_data_tvalid ? fft_data_re[7:0] : 8'd0;
assign o_fft_data_im = o_axi4s_data_tvalid ? fft_data_im[7:0] : 8'd0;
assign fft_data_re = (o_axi4s_data_tvalid && o_axi4s_data_count>10'd0) ? o_axi4s_data_tdata[31:0]: 32'd0;
assign fft_data_im = o_axi4s_data_tvalid ? o_axi4s_data_tdata[63:32]: 32'd0;
assign o_axi4s_data_count = o_axi4s_data_tuser[10:0];

always @(posedge clk or  negedge rst_n)  
begin
    if(!rst_n)begin
        state <= IDLE;
    end
    else begin
        case(state)
        IDLE:begin
            if(fft_start && o_axi4s_data_tready)begin
                state <= START;
            end
            else begin
                state <= IDLE;           
            end
        end
        START:begin
            state <= FFT_IN;
        end
        FFT_IN:begin
            if(i_axi4s_data_tlast)begin
                state <= FFT_OUT;
            end
            else begin
                state <= FFT_IN;           
            end
        end
        FFT_OUT:begin
            if(o_axi4s_data_tlast)begin
                state <= OVER;
            end
            else begin
                state <= FFT_OUT;           
            end
        end
        OVER:begin
            state <= IDLE; 
        end
        default:state <= IDLE;
        endcase
    end 
end

always @(posedge clk or  negedge rst_n)  
begin
    if(!rst_n)
        fft_over <= 1'b0;
    else if(state == OVER)begin
        fft_over <= 1'b1;
    end
    else
        fft_over <= 1'b0;
end


//FFT_IN状态下进行输入数据的计数器
always @(posedge clk or  negedge rst_n)  
begin
    if(!rst_n)
        i_axi4s_data_count <= 11'd0;
    else if(i_axi4s_data_tvalid)begin
        if(i_axi4s_data_count <11'd2047)
            i_axi4s_data_count <= i_axi4s_data_count + 11'd1;
        else if(i_axi4s_data_count == 11'd2047)
            i_axi4s_data_count <= 11'd0;
    end
    else
        i_axi4s_data_count <= 11'd0;
end

//数据有效标志
always @(posedge clk or  negedge rst_n)  
begin
    if(!rst_n)
        i_axi4s_data_tvalid <= 1'b0;
    else if(state == FFT_IN)begin
        if( i_axi4s_data_count < 11'd2047)
            i_axi4s_data_tvalid <= 1'b1;
        else
            i_axi4s_data_tvalid <= 1'b0;
    end
    else
        i_axi4s_data_tvalid <= 1'b0;
end
//最后一个数据有效标志

fft u_fft (
  .i_axi4s_data_tdata(i_axi4s_data_tdata),      // input [31:0]
  .i_axi4s_data_tvalid(i_axi4s_data_tvalid),    // input
  .i_axi4s_data_tlast(i_axi4s_data_tlast),      // input
  .o_axi4s_data_tready(o_axi4s_data_tready),    // output
  .i_axi4s_cfg_tdata(1'b1),        // input
  .i_axi4s_cfg_tvalid(~rst_n),      // input
  .i_aclk(clk),                              // input
  .o_axi4s_data_tdata(o_axi4s_data_tdata),      // output [63:0]
  .o_axi4s_data_tvalid(o_axi4s_data_tvalid),    // output
  .o_axi4s_data_tlast(o_axi4s_data_tlast),      // output
  .o_axi4s_data_tuser(o_axi4s_data_tuser),      // output [23:0]
  .o_alm(o_alm),                                // output
  .o_stat(o_stat)                               // output
);
wire           fft_data2_vaild;
reg [2:0]      fft_data2_delay_reg;
assign fft_data2_vaild = fft_data2_delay_reg[2];
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        fft_data2_delay_reg <= 3'b000;
    end else begin
        fft_data2_delay_reg[0] <= o_axi4s_data_tvalid;
        fft_data2_delay_reg[1] <= fft_data2_delay_reg[0];
        fft_data2_delay_reg[2] <= fft_data2_delay_reg[1];
    end
end

wire [63:0]    fft_data_re2;
mult u_multre (
  .a(fft_data_re),        // input [31:0]
  .b(fft_data_re),        // input [31:0]
  .clk(clk),    // input
  .rst(~rst_n),    // input
  .ce(1'b1),      // input
  .p(fft_data_re2)         // output [63:0]
);

wire [63:0]    fft_data_im2;
mult u_multim (
  .a(fft_data_im),        // input [31:0]
  .b(fft_data_im),        // input [31:0]
  .clk(clk),    // input
  .rst(~rst_n),    // input
  .ce(1'b1),      // input
  .p(fft_data_im2)         // output [63:0]
);
wire [64:0]    fft_re_im;
assign fft_re_im = fft_data_re2 + fft_data_im2;


sqrt_1
#(
    .d_width    (64)    // 输入数据位宽32
)
u_fft_sqrt
(
    .clk        (clk),
    .rst        (~rst_n),
    .i_vaild    (fft_data2_vaild),
    .data_i     (fft_re_im), // 32位数据→33位data_i（符号位补0，确保正数）
    
    .o_vaild    (o_fft_data_vaild),
    .data_o     (o_fft_data),              // 16位结果（q_width+1=15+1=16）
    .data_r     ()                  // 余数忽略
);

wire [64:0]    fft_data_temp;
assign fft_data_temp=(o_fft_data * 240)>>15; //>>16

assign fft_data=fft_data_temp[7:0];
endmodule