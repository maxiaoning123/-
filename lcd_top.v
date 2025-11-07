module lcd_top(
    input           sys_clk         ,
    input           ad_clk,
    input           sys_rst_n       , 
    input           o_fft_data_vaild,
    input[7 :0]     o_fft_data,
    output          lcd_draw_over,

    //spi tft screen   屏幕接口          
    output          lcd_spi_sclk    ,           // 屏幕spi时钟接口
    output          lcd_spi_mosi    ,           // 屏幕spi数据接口
    output          lcd_spi_cs      ,           // 屏幕spi使能接口     
    output          lcd_dc          ,           // 屏幕 数据/命令 接口
    output          lcd_reset       ,           // 屏幕复位接口
    output          lcd_blk                     // 屏幕背光接口


);
parameter IDLE      = 4'd0;
parameter WIRTE     = 4'd1;
parameter READ      = 4'd2;
parameter OVER      = 4'd3;

//lcd 用户接口
wire            flush_data_update  ;  //更新当前坐标点显示数据使能
reg[15:0]       flush_data         ;  //当前坐标点显示的数据
wire[15:0]      flush_addr_width   ;  //当前刷新的x坐标
wire[15:0]      flush_addr_height  ;  //当前刷新的y坐标

//ram signals
reg [3:0]       ram_state/* synthesis PAP_MARK_DEBUG="1"*/;
wire            wr_en/* synthesis PAP_MARK_DEBUG="1"*/;
reg [9:0]       wr_addr/* synthesis PAP_MARK_DEBUG="1"*/;
reg [9:0]       rd_addr/* synthesis PAP_MARK_DEBUG="1"*/;
wire[7:0]       ram_rd_data/* synthesis PAP_MARK_DEBUG="1"*/;
//寄存器存储fft频谱数据方便画图
reg [7:0]       memory_array [0:319];
reg [7:0]       fft_amplitude;
reg [7:0]       valid_amplitude;

assign wr_en=o_fft_data_vaild && (wr_addr<10'd320) &&(ram_state == WIRTE);//只写入前320点数据
assign lcd_draw_over=(flush_addr_width=='d319)&&(flush_addr_height=='d239)?1'b1:1'b0;//只有在地址扫描完后最后一个点说明画图画完了

always@(posedge sys_clk or negedge sys_rst_n) begin
    if( sys_rst_n == 1'b0) begin
        flush_data <= 16'd0;  // 复位时为黑色
    end else begin
        // 仅处理x坐标在0~319范围内的有效区域
        if(flush_addr_width >= 16'd0 && flush_addr_width < 16'd320) begin
            // 获取当前x坐标对应的FFT幅度值（0~255）
            
            fft_amplitude = memory_array[flush_addr_width[9:0]];  // x坐标低10位作为数组索引
            
            // 限制幅度最大值为240（避免超出屏幕高度）
            
            valid_amplitude = (fft_amplitude > 8'd240) ? 8'd240 : fft_amplitude;
            
            // 设定基线为屏幕底部（y=239），波形从基线向上延伸
            // 当前y坐标在[基线-幅度, 基线]范围内时，显示白色（波形）
            if(flush_addr_height >= (16'd239 - valid_amplitude) && flush_addr_height <= 16'd239) begin
                flush_data <= 16'hffff;  // 波形颜色（白色）
            end else begin
                flush_data <= 16'h0000;  // 背景色（黑色）
            end
        end else begin
            // x坐标超出有效范围（0~319），显示黑色
            flush_data <= 16'h0000;
        end
    end
end
//把ram的数据一个一个放到不同数组索引下存下来
always@(posedge sys_clk ) begin
    if (ram_state == READ && rd_addr < 10'd320) begin
        memory_array[rd_addr] <= ram_rd_data;
    end
end

//状态切换
always @(posedge ad_clk or negedge sys_rst_n)  begin
    if( sys_rst_n == 1'b0) begin
        ram_state <= IDLE; 
    end else begin
        case(ram_state)
        IDLE:begin
            ram_state <= WIRTE;           
        end
        WIRTE:begin
            if(wr_addr == 10'd320)begin
                ram_state <= READ;
            end
            else begin
                ram_state <= WIRTE;           
            end
        end
        READ:begin
            if(rd_addr == 10'd320)begin
                ram_state <= OVER;
            end
            else begin
                ram_state <= READ;           
            end
        end
        OVER:begin
            if(~o_fft_data_vaild)
                ram_state <= IDLE; 
            else
                ram_state <= OVER;
        end
        default:ram_state <= IDLE;
        endcase 
end
end

always@(posedge ad_clk or negedge sys_rst_n) begin
    if( sys_rst_n == 1'b0)
        wr_addr <= 10'd0;
    else if(o_fft_data_vaild && wr_addr<10'd320 && ram_state == WIRTE)
        wr_addr <= wr_addr + 10'd1;
    else
        wr_addr <= 10'd0;
        
end

always@(posedge sys_clk or negedge sys_rst_n) begin
    if( sys_rst_n == 1'b0)
        rd_addr <= 10'd0;
    else if(wr_addr==10'd320)
        rd_addr <= 10'd1;
    else if(rd_addr>10'd0 && rd_addr<10'd320)
        rd_addr <= rd_addr + 10'd1;
    else if(ram_state == OVER)
        rd_addr <= 10'd0;
        
end
ram u_ram (
  .wr_data(o_fft_data),    // input [7:0]
  .wr_addr(wr_addr),    // input [9:0]
  .rd_addr(rd_addr),    // input [9:0]
  .wr_clk(ad_clk),      // input
  .rd_clk(sys_clk),      // input
  .wr_en(wr_en),        // input
  .rst(~sys_rst_n),            // input
  .rd_data(ram_rd_data)     // output [7:0]
);


screen_driver screen_driver_hp(
    .sys_clk            (   sys_clk         ),
    .sys_rst_n          (   sys_rst_n       ),


    //用户信号
    .flush_data_update_o  (     flush_data_update   ),  //更新当前坐标点显示数据使能
    .flush_data_i         (     flush_data          ),  //当前坐标点显示的数据
    .flush_addr_width_o   (     flush_addr_width    ),  //当前刷新的x坐标
    .flush_addr_height_o  (     flush_addr_height   ),  //当前刷新的y坐标
    //----

     //spi tft screen   屏幕接口          
    .lcd_spi_sclk       (   lcd_spi_sclk    ),           // 屏幕spi时钟接口
    .lcd_spi_mosi       (   lcd_spi_mosi    ),           // 屏幕spi数据接口
    .lcd_spi_cs         (   lcd_spi_cs      ),           // 屏幕spi使能接口     
    .lcd_dc             (   lcd_dc          ),           // 屏幕 数据/命令 接口
    .lcd_reset          (   lcd_reset       ),           // 屏幕复位接口
    .lcd_blk            (   lcd_blk         )            // 屏幕背光接口
);

endmodule
