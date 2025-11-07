module duty_cycle(
    input wire clk,
    input wire rst_n,
    input wire signal_in,
    output reg [31:0] high_time/* synthesis PAP_MARK_DEBUG="1"*/,
    output reg [31:0] low_time/* synthesis PAP_MARK_DEBUG="1"*/,
    output reg [31:0] duty
);

    reg [31:0] high_counter;
    reg [31:0] low_counter;
    reg signal_in_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            high_counter <= 32'd0;
            low_counter <= 32'd0;
            high_time <= 32'd0;
            low_time <= 32'd0;
            duty <= 32'd0;
            signal_in_d <= 1'b0;
        end else begin
            signal_in_d <= signal_in;
            if (signal_in) begin
                if (!signal_in_d) begin
                    low_time <= low_counter;
                    low_counter <= 32'd0;
                end
                high_counter <= high_counter + 1;
            end else begin
                if (signal_in_d) begin
                    high_time <= high_counter;
                    high_counter <= 32'd0;
                end
                low_counter <= low_counter + 1;
            end

            if (high_time + low_time > 0) begin
                duty <= (high_time * 1000) / (high_time + low_time);
            end
        end
    end

endmodule