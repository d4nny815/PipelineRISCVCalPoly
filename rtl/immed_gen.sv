`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/22/2023 11:19:34 PM
// Design Name: 
// Module Name: immed_gen
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

// immed_gen.v
// Members: Daniel Gutierrez
// Description: Generates five different instructional 
// formats from the instruction register

module ImmedGen (
    input [31:7] ir,
    input [2:0] immed_sel,
    output logic [31:0] immed_ext
    );

    always_comb begin
        case(immed_sel)
            3'b000: immed_ext = { {21{ir[31]}}, ir[30:25], ir[24:20]};
            3'b001: immed_ext = { {21{ir[31]}}, ir[30:25], ir[11:7]};
            3'b010: immed_ext = { {20{ir[31]}}, ir[7], ir[30:25], ir[11:8], 1'b0};
            3'b011: immed_ext = { {12{ir[31]}}, ir[19:12], ir[20], ir[30:21], 1'b0};
            3'b100: immed_ext = { ir[31:12], 12'b0};
            default : immed_ext = 32'hdeadbeef;
        endcase
    end

        
endmodule