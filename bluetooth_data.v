/*
 * 模块: bluetooth_data
 * 描述:
 * 1. 通过FIFO缓存来自AD时钟域的FFT数据。
 * 2. 使用系统时钟 (clk) 域的FSM（有限状态机）读取FIFO。
 * 3. 在发送2048个FFT数据点之前，首先发送两个字节的帧头 (8'h05, 8'h64)。
 * 4. 通过 uart_tx_en 和 uart_tx_data 控制UART模块进行发送。
 * 5. 在2048点数据发送完成后，拉高 uart_fft_over 信号。
 */
module bluetooth_data(
    input        clk,            // 系统时钟 (用于FSM和FIFO读)
    input        ad_clk,         // ADC时钟 (用于FIFO写)
    input        rst_n,          // 异步复位 (低有效)
    input[7:0]   fft_data,       // FFT数据输入
    input        fft_data_vaild, // FFT数据有效信号
    input        uart_tx_done,   // UART模块发送完成脉冲
    
    output reg   uart_tx_en,     // UART发送使能 (脉冲)
    output [7:0] uart_tx_data,   // 发送给UART的数据 (帧头或FFT数据)
    output reg   uart_fft_over     // 一帧(2048点)数据发送完成标志
   );
   
// ----------------------------------------------------------------
// FIFO 实例化 (异步FIFO)
// ----------------------------------------------------------------

// FIFO 内部信号
wire        wr_full;
wire        almost_full;

reg         rd_en;          // FIFO 读使能 (由FSM控制)
wire[7:0]   rd_data;        // 从FIFO读出的数据
wire        rd_empty;       // FIFO 空标志
wire        almost_empty;

// 实例化FIFO (假设您已有名为 'fifo' 的IP核或模块)
fifo u_fifo (
  .wr_clk(ad_clk),                    // 写时钟 (ADC时钟域)
  .wr_rst(~rst_n),                    // 写复位 (高有效)
  .wr_en(fft_data_vaild),             // 写使能
  .wr_data(fft_data),                 // 写入数据
  .wr_full(wr_full),                  // output
  .almost_full(almost_full),          // output
  
  .rd_clk(clk),                       // 读时钟 (系统时钟域)
  .rd_rst(~rst_n),                    // 读复位 (高有效)
  .rd_en(rd_en),                      // 读使能
  .rd_data(rd_data),                  // 读出数据
  .rd_empty(rd_empty),                // output
  .almost_empty(almost_empty)         // output
);

// ----------------------------------------------------------------
// 串口发送FSM (有限状态机)
// ----------------------------------------------------------------

// FSM 状态定义
localparam S_IDLE         = 4'd0; // 空闲状态
localparam S_SEND_HEADER1 = 4'd1; // 发送帧头1 (0x05)
localparam S_WAIT_HEADER1 = 4'd2; // 等待帧头1发送完成
localparam S_SEND_HEADER2 = 4'd3; // 发送帧头2 (0x64)
localparam S_WAIT_HEADER2 = 4'd4; // 等待帧头2发送完成
localparam S_READ_FIFO    = 4'd5; // 从FIFO读取数据
localparam S_SEND_UART    = 4'd6; // 发送FIFO数据到UART
localparam S_WAIT_UART    = 4'd7; // 等待UART数据发送完成
localparam S_FINISH       = 4'd8; // 2048点全部发送完成

// FSM 状态寄存器
reg [3:0] state_reg; 
// FFT数据发送计数器 (0 到 2047)
reg [10:0] count_reg;

// 用于保存帧头数据的变量
reg [7:0] header_data_reg;

// ----------------------------------------------------------------
// 数据路径 MUX (数据选择器)
// ----------------------------------------------------------------
// 根据FSM状态决定 uart_tx_data 的输出
// 状态 <= S_WAIT_HEADER2 (4) 时, 输出帧头
// 状态 >  S_WAIT_HEADER2 (4) 时, 输出FIFO数据
assign uart_tx_data = (state_reg > S_WAIT_HEADER2) ? rd_data : header_data_reg;


// ----------------------------------------------------------------
// FSM 控制逻辑 (时序逻辑)
// ----------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // 异步复位
        state_reg       <= S_IDLE;
        count_reg       <= 11'd0;
        uart_tx_en      <= 1'b0;
        uart_fft_over   <= 1'b0;
        rd_en           <= 1'b0;
        header_data_reg <= 8'h00;
    end else begin
        // 默认将脉冲信号拉低
        rd_en      <= 1'b0;
        uart_tx_en <= 1'b0;

        // FSM 状态转移
        case (state_reg)
            // 0: 空闲状态
            S_IDLE: begin
                count_reg <= 11'd0; // 重置数据计数器
                
                // 检查FIFO中是否有数据，若有，则开始发送
                if (!rd_empty) begin
                    uart_fft_over   <= 1'b0; // 清除上一帧的完成标志
                    header_data_reg <= 8'h05; // 预加载第一个帧头
                    state_reg       <= S_SEND_HEADER1; 
                end else begin
                    // 保持空闲，等待数据
                    state_reg       <= S_IDLE;
                end
            end
            
            // 1: 发送帧头1 (0x05)
            S_SEND_HEADER1: begin
                uart_tx_en   <= 1'b1; // 发送使能 (此时 uart_tx_data = 8'h05)
                state_reg    <= S_WAIT_HEADER1;
            end
            
            // 2: 等待帧头1发送完成
            S_WAIT_HEADER1: begin
                if (uart_tx_done) begin
                    header_data_reg <= 8'h64; // 预加载第二个帧头
                    state_reg       <= S_SEND_HEADER2; 
                end else begin
                    state_reg       <= S_WAIT_HEADER1; // 继续等待
                end
            end

            // 3: 发送帧头2 (0x64)
            S_SEND_HEADER2: begin
                uart_tx_en   <= 1'b1; // 发送使能 (此时 uart_tx_data = 8'h64)
                state_reg    <= S_WAIT_HEADER2;
            end
            
            // 4: 等待帧头2发送完成
            S_WAIT_HEADER2: begin
                if (uart_tx_done) begin
                    // 帧头发送完毕，准备开始发送数据
                    // 再次检查FIFO确保安全
                    if (!rd_empty) begin
                        state_reg <= S_READ_FIFO;
                    end else begin
                        state_reg <= S_IDLE; // 异常：FIFO空了，返回IDLE
                    end
                end else begin
                    state_reg <= S_WAIT_HEADER2; // 继续等待
                end
            end
            
            // 5: 从FIFO读取数据
            S_READ_FIFO: begin
                rd_en     <= 1'b1; // 发出一个时钟周期的读使能
                state_reg <= S_SEND_UART; // 下一拍去发送
            end

            // 6: 发送FIFO数据
            S_SEND_UART: begin
                // (此时 uart_tx_data = rd_data, 由 assign 语句处理)
                uart_tx_en   <= 1'b1; // 发送使能
                state_reg    <= S_WAIT_UART;
            end

            // 7: 等待UART数据发送完成
            S_WAIT_UART: begin
                if (uart_tx_done) begin
                    // 检查是否是最后一个数据
                    if (count_reg == 11'd2047) begin // (0 到 2047 共 2048个)
                        state_reg <= S_FINISH;
                    end else begin
                        // 还未发完，准备发下一个
                        count_reg <= count_reg + 1;
                        if (!rd_empty) begin
                            state_reg <= S_READ_FIFO; // 回去读下一个数据
                        end else begin
                            // 错误：发生FIFO欠载 (Underrun)
                            state_reg <= S_IDLE; 
                        end
                    end
                end else begin
                    // 串口还没发完，继续等待
                    state_reg <= S_WAIT_UART;
                end
            end

            // 8: 完成
            S_FINISH: begin
                uart_fft_over <= 1'b1; // 置位完成标志
                state_reg     <= S_IDLE; // 回到IDLE状态，等待下一帧
            end

            default: begin
                state_reg <= S_IDLE;
            end
        endcase
    end
end

endmodule