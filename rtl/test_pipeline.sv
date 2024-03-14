`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/27/2023 01:15:15 PM
// Design Name: 
// Module Name: test_pipeline
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


module test_pipeline();
    logic clk, rst;

    logic [15:0] leds;
    logic [4:0] btns;
    logic [3:0] an;
    OTTER_Wrapper DUT (
        .clk        (clk),
        .buttons    (btns),
        .switches   (16'b0),
        .leds       (leds),
        .segs       (),
        .an         (an)
    );


    assign btns[4] = rst;

    always begin
    #20 clk = ~clk; 
    end  


    initial begin
        clk = 0; rst = 0;
//        # 100;
//        rst = 0;

        #1000;
        $finish;
    end

endmodule
