module signal_fir(
     input                     sys_clk  ,  
     input                     rst_n,   
     input                     TTL_signal,
     
     output     reg            TTL_signal_fir
    );
    reg [47:0] BufferTTL_signal;
    always @(posedge sys_clk or negedge rst_n)begin
    if(!rst_n)begin
        TTL_signal_fir<=1'b0;
    end
    else begin
        if (BufferTTL_signal == 48'b11111111_11111111_11111111_11111111_11111111_11111111)begin
            TTL_signal_fir<=1'b1;
        end
        else if (BufferTTL_signal == 48'b00000000_00000000_00000000_00000000_00000000_00000000)begin
            TTL_signal_fir<=1'b0;
        end
        else begin
            TTL_signal_fir<=TTL_signal_fir;
        end
    end
    end
    
    
    always @(posedge sys_clk or negedge rst_n)begin
    if(!rst_n)begin
        BufferTTL_signal<=48'b0;
    end
    else begin
        BufferTTL_signal[47] <= BufferTTL_signal[46];
	    BufferTTL_signal[46] <= BufferTTL_signal[45];
	    BufferTTL_signal[45] <= BufferTTL_signal[44];
	    BufferTTL_signal[44] <= BufferTTL_signal[43];
	    BufferTTL_signal[43] <= BufferTTL_signal[42];
	    BufferTTL_signal[42] <= BufferTTL_signal[41];
	    BufferTTL_signal[41] <= BufferTTL_signal[40];
	    BufferTTL_signal[40] <= BufferTTL_signal[39];
	    BufferTTL_signal[39] <= BufferTTL_signal[38];
        BufferTTL_signal[38] <= BufferTTL_signal[37];
        BufferTTL_signal[37] <= BufferTTL_signal[36];
	    BufferTTL_signal[36] <= BufferTTL_signal[35];
	    BufferTTL_signal[35] <= BufferTTL_signal[34];
	    BufferTTL_signal[34] <= BufferTTL_signal[33];
	    BufferTTL_signal[33] <= BufferTTL_signal[32];
	    BufferTTL_signal[32] <= BufferTTL_signal[31];

        BufferTTL_signal[31] <= BufferTTL_signal[30];
	    BufferTTL_signal[30] <= BufferTTL_signal[29];
	    BufferTTL_signal[29] <= BufferTTL_signal[28];
	    BufferTTL_signal[28] <= BufferTTL_signal[27];
	    BufferTTL_signal[27] <= BufferTTL_signal[26];
	    BufferTTL_signal[26] <= BufferTTL_signal[25];
	    BufferTTL_signal[25] <= BufferTTL_signal[24];
	    BufferTTL_signal[24] <= BufferTTL_signal[23];
	    BufferTTL_signal[23] <= BufferTTL_signal[22];
	    BufferTTL_signal[22] <= BufferTTL_signal[21];
        BufferTTL_signal[21] <= BufferTTL_signal[20];
	    BufferTTL_signal[20] <= BufferTTL_signal[19];
	    
	    BufferTTL_signal[19] <= BufferTTL_signal[18];
	    BufferTTL_signal[18] <= BufferTTL_signal[17];
	    BufferTTL_signal[17] <= BufferTTL_signal[16];
	    BufferTTL_signal[16] <= BufferTTL_signal[15];
	    BufferTTL_signal[15] <= BufferTTL_signal[14];
	    BufferTTL_signal[14] <= BufferTTL_signal[13];
	    BufferTTL_signal[13] <= BufferTTL_signal[12];
	    BufferTTL_signal[12] <= BufferTTL_signal[11];
        BufferTTL_signal[11] <= BufferTTL_signal[10];
	    BufferTTL_signal[10] <= BufferTTL_signal[9];
	    
	    BufferTTL_signal[9] <= BufferTTL_signal[8];
	    BufferTTL_signal[8] <= BufferTTL_signal[7];
	    BufferTTL_signal[7] <= BufferTTL_signal[6];
	    BufferTTL_signal[6] <= BufferTTL_signal[5];
	    BufferTTL_signal[5] <= BufferTTL_signal[4];
	    BufferTTL_signal[4] <= BufferTTL_signal[3];
	    BufferTTL_signal[3] <= BufferTTL_signal[2];
	    BufferTTL_signal[2] <= BufferTTL_signal[1];
        BufferTTL_signal[1] <= BufferTTL_signal[0];
	    BufferTTL_signal[0] <= TTL_signal;
    end
    
    end
    
endmodule
