`timescale 1ns / 1ps

module HazardUnit (
    input reset,
    input [4:0] rs1_D,
    input [4:0] rs2_D,
    input [4:0] rs1_E,
    input [4:0] rs2_E,
    input [4:0] rd_E,
    input [4:0] rd_M,
    input [4:0] rd_W,
    input regWrite_M,
    input regWrite_W,
    input pcSource_E,
    input [1:0] rf_wr_sel_E,
    output logic [1:0] forwardA_E,
    output logic [1:0] forwardB_E,
    output logic stall_F,
    output logic stall_D,
    output logic flush_F,
    output logic flush_D,
    output logic flush_E,
    output logic flush_M,
    output logic flush_W
    );

    typedef enum logic [1:0] {
        EX = 2'b00,
        MEM = 2'b01,
        WB = 2'b10
    } ForwardReg_t;

    parameter MEM_READ_DATA = 2'b10;
    
    logic load;
    always_comb begin
        if ((rs1_E == rd_M) && regWrite_M && (rs1_E != 0)) begin
            forwardA_E = MEM;
        end
        else if ((rs1_E == rd_W) && regWrite_W && (rs1_E != 0)) begin
            forwardA_E = WB;
        end
        else begin
            forwardA_E = EX;
        end
    end

    always_comb begin
        if ((rs2_E == rd_M) && regWrite_M && (rs2_E != 0)) begin
            forwardB_E = MEM;
        end
        else if ((rs2_E == rd_W) && regWrite_W && (rs2_E != 0)) begin
            forwardB_E = WB;
        end
        else begin
            forwardB_E = EX;
        end
    end

    always_comb begin
        load = ((rf_wr_sel_E == MEM_READ_DATA) & ((rs1_D == rd_E) | (rs2_D == rd_E)));
        stall_F = load;
        stall_D = load;
        flush_E = load | pcSource_E | reset;
        flush_D = pcSource_E | reset;
    end

    always_comb begin
        flush_F = reset;
        flush_M = reset;
        flush_W = reset;
    end


endmodule
