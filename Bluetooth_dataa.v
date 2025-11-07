module Bluetooth_dataa(
    input                     clk,
    input                     rst_n,
    input   [31:0]            duty_cycle/* synthesis PAP_MARK_DEBUG="1"*/,  // 占空比（0-100）
    input   [19:0]            ad_fred/* synthesis PAP_MARK_DEBUG="1"*/,     // 频率（0-1048575）
    input   [7:0]             ad_max/* synthesis PAP_MARK_DEBUG="1"*/,      // ADC数字量（128-255）
	 
    input                     uart_tx_done, // UART发送完成信号
    input   [7:0]             uart_rx_data, // UART接收数据
    input                     uart_rx_done, // UART接收完成信号
    
    output  reg               uart_tx_en/* synthesis PAP_MARK_DEBUG="1"*/,   // UART发送使能
    output  reg     [7:0]     uart_tx_data/* synthesis PAP_MARK_DEBUG="1"*/   // UART发送数据
    

);
	 
// 状态定义
parameter IDLE              = 4'd0;  // 空闲态
parameter DATA_CHANGE       = 4'd1;  // 数据分解与无效位替换态
parameter WAIT_1s           = 4'd2;  // 等待1s
parameter SEND              = 4'd3;  // UART发送态
parameter OVER              = 4'd4;  // 发送完成态

// 等待1s计数最大值
parameter count_max         = 32'd50_000_000;
reg  [7:0]   max_tx_count/* synthesis PAP_MARK_DEBUG="1"*/;  // 各数据发送字节数（duty:12, fred:16, mv:13）

reg [15:0]        ad_mv_output; // 16位模拟幅值输出

// 状态机与计数寄存器
reg  [3:0]    state/* synthesis PAP_MARK_DEBUG="1"*/;        // 当前状态
reg  [31:0]   count;        // WAIT_1s计数
reg  [5:0]    tx_count/* synthesis PAP_MARK_DEBUG="1"*/;     // 发送字节计数
reg  [1:0]    tx_en_count;  // 发送使能计数
reg           uart_tx_en_temp; // 发送使能临时信号
reg  [1:0]    change_count/* synthesis PAP_MARK_DEBUG="1"*/; // 数据切换计数（0:duty,1:fred,2:mv）

// -------------------------- 1. 数据分解与无效位替换核心逻辑 --------------------------
// 1.1 原始ASCII分解寄存器（临时存储未处理的ASCII码）
reg [7:0] duty_ascii_raw [2:0];  // 占空比原始ASCII
reg [7:0] fred_ascii_raw [6:0];  // 频率原始ASCII
reg [7:0] mv_ascii_raw [4:0];    // 模拟幅值原始ASCII：[4]万位,[3]千位,[2]百位,[1]十位,[0]个位 (5位, max 49784)

// 1.2 最终发送ASCII寄存器（无效位已替换为空格）
reg [7:0] duty_ascii_final [2:0]; // 占空比最终ASCII
reg [7:0] fred_ascii_final [6:0]; // 频率最终ASCII
reg [7:0] mv_ascii_final [4:0];   // 模拟幅值最终ASCII

// 1.3 临时数据寄存器（存储限幅后的数据）
reg [31:0] temp_duty;  // 限幅后占空比（0-100）
reg [19:0] temp_fred;  // 频率（0-1048575）
reg [15:0] ad_mv;      // 16位无符号模拟幅值（0-49784）
reg [8:0]  ad_max_minus_128; // 9位无符号数，最大 255-128 = 127

// -------------------------- 2. 步骤1：原始数据分解（转换为ASCII） --------------------------
// 2.1 占空比分解（原逻辑不变）
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        temp_duty <= 32'd0;
        duty_ascii_raw[0] <= 8'h30;
        duty_ascii_raw[1] <= 8'h30;
        duty_ascii_raw[2] <= 8'h30;
    end
    else begin
        // 占空比限幅（超出0-100按边界处理）
        temp_duty <= (duty_cycle > 1000) ? 32'd999 : (duty_cycle < 0 ? 32'd0 : duty_cycle);
        // 转换为ASCII（0→8'h30，9→8'h39）
        duty_ascii_raw[0] <= (temp_duty % 10) + 8'h30;        // 个位
        duty_ascii_raw[1] <= ((temp_duty % 100) / 10) + 8'h30;// 十位
        duty_ascii_raw[2] <= (temp_duty / 100) + 8'h30;       // 百位
    end
end

// 2.2 频率分解（原逻辑不变）
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        temp_fred <= 20'd0;
        fred_ascii_raw[0] <= 8'h30;
        fred_ascii_raw[1] <= 8'h30;
        fred_ascii_raw[2] <= 8'h30;
        fred_ascii_raw[3] <= 8'h30;
        fred_ascii_raw[4] <= 8'h30;
        fred_ascii_raw[5] <= 8'h30;
        fred_ascii_raw[6] <= 8'h30;
    end
    else begin
        temp_fred <= ad_fred;
        // 转换为ASCII
        fred_ascii_raw[0] <= (temp_fred / 1000000) + 8'h30;        // 百万位
        fred_ascii_raw[1] <= ((temp_fred % 1000000) / 100000) + 8'h30;// 十万位
        fred_ascii_raw[2] <= ((temp_fred % 100000) / 10000) + 8'h30;  // 万位
        fred_ascii_raw[3] <= ((temp_fred % 10000) / 1000) + 8'h30;    // 千位
        fred_ascii_raw[4] <= ((temp_fred % 1000) / 100) + 8'h30;     // 百位
        fred_ascii_raw[5] <= ((temp_fred % 100) / 10) + 8'h30;       // 十位
        fred_ascii_raw[6] <= (temp_fred % 10) + 8'h30;               // 个位
    end
end

// 2.3 模拟幅值 ad_mv 计算和分解 (替换原ad_max分解逻辑)
always @(posedge clk or negedge rst_n) begin
    
    
    if (!rst_n) begin
        ad_mv <= 16'd0;
        mv_ascii_raw[0] <= 8'h30;
        mv_ascii_raw[1] <= 8'h30;
        mv_ascii_raw[2] <= 8'h30;
        mv_ascii_raw[3] <= 8'h30;
        mv_ascii_raw[4] <= 8'h30;
        ad_mv_output <= 16'd0;
    end
    else begin
        // 计算 ad_mv = (ad_max - 128) * 392
        // 由于 ad_max 范围 [128, 255]， ad_max - 128 范围 [0, 127]
        ad_max_minus_128 <= ad_max - 8'd128; // 确保 ad_max 不小于 128
        
        // 16'd392 * 9'd127 = 49784 < 65536， 16位无符号数足够
        ad_mv <= ad_max_minus_128 * 16'd392; 
        ad_mv_output <= ad_mv; // 更新输出
        
        // 转换为ASCII (5位数字，最大49784)
        mv_ascii_raw[0] <= (ad_mv % 10) + 8'h30;          // 个位
        mv_ascii_raw[1] <= ((ad_mv / 10) % 10) + 8'h30;   // 十位
        mv_ascii_raw[2] <= ((ad_mv / 100) % 10) + 8'h30;  // 百位
        mv_ascii_raw[3] <= ((ad_mv / 1000) % 10) + 8'h30; // 千位
        mv_ascii_raw[4] <= (ad_mv / 10000) + 8'h30;       // 万位
    end
end


// -------------------------- 3. 步骤2：无效位替换 --------------------------
// 3.1 占空比无效位替换（原逻辑不变）
always @(*) begin
    if (!rst_n) begin
        duty_ascii_final[0] = 8'h30;
        duty_ascii_final[1] = 8'h30;
        duty_ascii_final[2] = 8'h30;
    end
    else begin
        // ... (原占空比无效位替换逻辑) ...
        duty_ascii_final[0] = duty_ascii_raw[0];
        
        if (temp_duty < 10 && duty_ascii_raw[2] == 8'h30) 
            duty_ascii_final[1] = 8'h20; // 空格
        else 
            duty_ascii_final[1] = duty_ascii_raw[1];
        
        if (temp_duty < 100) 
            duty_ascii_final[2] = 8'h20; // 空格
        else 
            duty_ascii_final[2] = duty_ascii_raw[2];
    end
end

// 3.2 频率无效位替换（原逻辑不变）
always @(*) begin
    if (!rst_n) begin
        // ... (复位状态) ...
        fred_ascii_final[0] = 8'h30;
        fred_ascii_final[1] = 8'h30;
        fred_ascii_final[2] = 8'h30;
        fred_ascii_final[3] = 8'h30;
        fred_ascii_final[4] = 8'h30;
        fred_ascii_final[5] = 8'h30;
        fred_ascii_final[6] = 8'h30;
    end
    else begin
        // ... (原频率无效位替换逻辑) ...
        fred_ascii_final[6] = fred_ascii_raw[6];
        
        if (temp_fred < 10 && (fred_ascii_raw[0] == 8'h30) && (fred_ascii_raw[1] == 8'h30) 
            && (fred_ascii_raw[2] == 8'h30) && (fred_ascii_raw[3] == 8'h30) && (fred_ascii_raw[4] == 8'h30))
            fred_ascii_final[5] = 8'h20;
        else
            fred_ascii_final[5] = fred_ascii_raw[5];
        
        if (temp_fred < 100 && (fred_ascii_raw[0] == 8'h30) && (fred_ascii_raw[1] == 8'h30) 
            && (fred_ascii_raw[2] == 8'h30) && (fred_ascii_raw[3] == 8'h30))
            fred_ascii_final[4] = 8'h20;
        else
            fred_ascii_final[4] = fred_ascii_raw[4];
        
        if (temp_fred < 1000 && (fred_ascii_raw[0] == 8'h30) && (fred_ascii_raw[1] == 8'h30) && (fred_ascii_raw[2] == 8'h30))
            fred_ascii_final[3] = 8'h20;
        else
            fred_ascii_final[3] = fred_ascii_raw[3];
        
        if (temp_fred < 10000 && (fred_ascii_raw[0] == 8'h30) && (fred_ascii_raw[1] == 8'h30))
            fred_ascii_final[2] = 8'h20;
        else
            fred_ascii_final[2] = fred_ascii_raw[2];
        
        if (temp_fred < 100000 && (fred_ascii_raw[0] == 8'h30))
            fred_ascii_final[1] = 8'h20;
        else
            fred_ascii_final[1] = fred_ascii_raw[1];
        
        if (temp_fred < 1000000)
            fred_ascii_final[0] = 8'h20;
        else
            fred_ascii_final[0] = fred_ascii_raw[0];
    end
end

// 3.3 模拟幅值 ad_mv 无效位替换（替换原ad_max逻辑）
always @(*) begin
    if (!rst_n) begin
        mv_ascii_final[0] = 8'h30;
        mv_ascii_final[1] = 8'h30;
        mv_ascii_final[2] = 8'h30;
        mv_ascii_final[3] = 8'h30;
        mv_ascii_final[4] = 8'h30;
    end
    else begin
        // 个位：始终有效
        mv_ascii_final[0] = mv_ascii_raw[0];
        
        // 十位：仅当"数据＜10"时无效
        if (ad_mv < 10) 
            mv_ascii_final[1] = 8'h20; // 空格
        else 
            mv_ascii_final[1] = mv_ascii_raw[1];
        
        // 百位：仅当"数据＜100"时无效
        if (ad_mv < 100) 
            mv_ascii_final[2] = 8'h20; // 空格
        else 
            mv_ascii_final[2] = mv_ascii_raw[2];
        
        // 千位：仅当"数据＜1000"时无效
        if (ad_mv < 1000) 
            mv_ascii_final[3] = 8'h20; // 空格
        else 
            mv_ascii_final[3] = mv_ascii_raw[3];
        
        // 万位：仅当"数据＜10000"时无效
        if (ad_mv < 10000) 
            mv_ascii_final[4] = 8'h20; // 空格
        else 
            mv_ascii_final[4] = mv_ascii_raw[4];
    end
end


// -------------------------- 4. 步骤3：UART发送数据选择 --------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        uart_tx_data <= 8'd0;
    end
    // 发送占空比（change_count=0）
    else if (change_count == 2'd0 && state == SEND) begin
        case(tx_count)
            6'd0: uart_tx_data <= 8'h64; // "d"
            6'd1: uart_tx_data <= 8'h75; // "u"
            6'd2: uart_tx_data <= 8'h74; // "t"
            6'd3: uart_tx_data <= 8'h79; // "y"
            6'd4: uart_tx_data <= 8'h3A; // ":"
            6'd5: uart_tx_data <= duty_ascii_final[2];
            6'd6: uart_tx_data <= duty_ascii_final[1];
            6'd7: uart_tx_data <= 8'h2E; // "."
            6'd8: uart_tx_data <= duty_ascii_final[0];
            6'd9: uart_tx_data <= 8'h25; // "%"
            6'd10: uart_tx_data <= 8'h0D; // "\r"
            6'd11:uart_tx_data <= 8'h0A; // "\n"
            default: uart_tx_data <= 8'd0;
        endcase
    end
    // 发送频率（change_count=1）
    else if (change_count == 2'd1 && state == SEND) begin
        case(tx_count)
            6'd0: uart_tx_data <= 8'h66; // "f"
            6'd1: uart_tx_data <= 8'h72; // "r"
            6'd2: uart_tx_data <= 8'h65; // "e"
            6'd3: uart_tx_data <= 8'h71; // "q"
            6'd4: uart_tx_data <= 8'h3A; // ":"
            6'd5: uart_tx_data <= fred_ascii_final[0];
            6'd6: uart_tx_data <= fred_ascii_final[1];
            6'd7: uart_tx_data <= fred_ascii_final[2];
            6'd8: uart_tx_data <= fred_ascii_final[3];
            6'd9: uart_tx_data <= fred_ascii_final[4];
            6'd10:uart_tx_data <= fred_ascii_final[5];
            6'd11:uart_tx_data <= fred_ascii_final[6];
            6'd12:uart_tx_data <= 8'h48; // "H"
            6'd13:uart_tx_data <= 8'h7A; // "z"
            6'd14:uart_tx_data <= 8'h0D; // "\r"
            6'd15:uart_tx_data <= 8'h0A; // "\n"
            default: uart_tx_data <= 8'd0;
        endcase
    end
    // 发送模拟幅值 ad_mv（change_count=2）(新的逻辑)
    else if (change_count == 2'd2 && state == SEND) begin
        case(tx_count)
            6'd0: uart_tx_data <= 8'h61; // "a"
            6'd1: uart_tx_data <= 8'h64; // "d"
            6'd2: uart_tx_data <= 8'h6D; // "m"
            6'd3: uart_tx_data <= 8'h61; // "a"
            6'd4: uart_tx_data <= 8'h78; // "x"
            6'd5: uart_tx_data <= 8'h3A; // ":"
            6'd6: uart_tx_data <= mv_ascii_final[4]; // 万位（有效/空格）
            6'd7: uart_tx_data <= mv_ascii_final[3]; // 千位（有效/空格）
            6'd8: uart_tx_data <= mv_ascii_final[2]; // 百位（有效/空格）
            6'd9: uart_tx_data <= mv_ascii_final[1]; // 十位（有效/空格）
            6'd10:uart_tx_data <= 8'h20; // 个位（有效）
            6'd11:uart_tx_data <= 8'h6D; // "m"
            6'd12:uart_tx_data <= 8'h76; // "v"
            6'd13:uart_tx_data <= 8'h0D; // "\r"
            6'd14:uart_tx_data <= 8'h0A; // "\n"
            default: uart_tx_data <= 8'd0;
        endcase
    end
end


// -------------------------- 5. 发送使能控制（原逻辑不变） --------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tx_en_count <= 2'b0;
    end
    else if (state == SEND && tx_en_count < 2'd1 && tx_count == 8'd0) begin
        tx_en_count <= tx_en_count + 1'd1;
    end
    else if (state == SEND && tx_en_count == 2'd1 && tx_count == 8'd0) begin
        tx_en_count <= 2'd3;
    end
    else if (state == OVER) begin
        tx_en_count <= 2'd0;
    end
end

// -------------------------- 6. 发送字节计数（原逻辑不变） --------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tx_count <= 8'd0;
    end
    else if (state == SEND && uart_tx_done == 1'd1) begin
        tx_count <= tx_count + 1'b1;
    end
    else if (state != SEND) begin
        tx_count <= 8'd0;
    end
end

// -------------------------- 7. UART发送使能输出（原逻辑不变） --------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        uart_tx_en_temp <= 1'b0;
    end
    else if (state == SEND && tx_en_count == 2'd1) begin
        uart_tx_en_temp <= 1'b1;
    end
    else if (state == SEND && tx_count < (max_tx_count - 1) && uart_tx_done == 1'd1) begin
        uart_tx_en_temp <= 1'b1;
    end
    else begin
        uart_tx_en_temp <= 1'b0;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        uart_tx_en <= 1'b0;
    end
    else begin
        uart_tx_en <= uart_tx_en_temp;
    end
end

// -------------------------- 8. WAIT_1s计数（原逻辑不变） --------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        count <= 32'd0;
    end
    else if (state == WAIT_1s && count < count_max) begin
        count <= count + 32'd1;
    end
    else if (state == WAIT_1s && count == count_max) begin
        count <= 32'd0;
    end
end

// -------------------------- 9. 状态机跳转（原逻辑不变） --------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        change_count <= 2'd0;
    end
    else begin
        case(state)
            IDLE: begin
                state <= DATA_CHANGE;
            end
            DATA_CHANGE: begin
                state <= WAIT_1s;
            end
            WAIT_1s: begin
                if (count == count_max) begin
                    state <= SEND;
                end
            end
            SEND: begin
                if (tx_count == max_tx_count) begin
                    state <= OVER;
                end
            end
            OVER: begin
                state <= IDLE;
                // 切换下一个数据（0:duty→1:fred→2:mv→0:duty循环）
                if (change_count == 2'd0) begin
                    change_count <= 2'd1;
                end
                else if (change_count == 2'd1) begin
                    change_count <= 2'd2;
                end
                else begin // change_count == 2'd2
                    change_count <= 2'd0;
                end
            end
            default: state <= IDLE;
        endcase
    end
end

// -------------------------- 10. 各数据发送字节数配置（已修改） --------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        max_tx_count <= 8'd12;
    end
    else if (change_count == 2'd2 ) begin
        max_tx_count <= 8'd15; // 模拟幅值 ad_mv：15字节
    end
    else if (change_count == 2'd0 ) begin
        max_tx_count <= 8'd12; // 占空比：12字节
    end
    else begin
        max_tx_count <= 8'd16; // 频率：16字节
    end
end

endmodule