//****************************************************************************************//

module uart_top( 
    input            sys_clk  ,  
    input            sys_rst_n,  
     
    input            uart_rxd ,  
    output           uart_txd ,  
    input  wire         uart_tx_en,    
    output wire         uart_rx_done,  
    output wire         uart_tx_done,  
    
         
    input wire  [7:0]  uart_tx_data,    
    output wire  [7:0]  uart_rx_data       
    );

//parameter define
parameter CLK_FREQ = 50000000;    
parameter UART_BPS = 9600  ;    


uart_rx #(
    .CLK_FREQ  (CLK_FREQ),
    .UART_BPS  (UART_BPS)
    )    
    u_uart_rx1(
    .clk           (sys_clk     ),
    .rst_n         (sys_rst_n   ),
    .uart_rxd      (uart_rxd    ),
    .uart_rx_done  (uart_rx_done),
    .uart_rx_data  (uart_rx_data)
    );


uart_tx #(
    .CLK_FREQ  (CLK_FREQ),
    .UART_BPS  (UART_BPS)
    )    
    u_uart_tx1(
    .clk          (sys_clk     ),
    .rst_n        (sys_rst_n   ),
    .uart_tx_en   (uart_tx_en),
    .uart_tx_data (uart_tx_data),
    .uart_tx_done (uart_tx_done),
    .uart_txd     (uart_txd    ),
    .uart_tx_busy (            )
    );
    
endmodule
