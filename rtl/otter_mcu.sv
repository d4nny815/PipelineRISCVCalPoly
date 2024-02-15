import structs::*;

module OTTER_MCU (
    input CLK,    
    input INTR,       
    input RESET,      
    input [31:0] IOBUS_IN,    
    output [31:0] IOBUS_OUT,    
    output [31:0] IOBUS_ADDR,
    output logic IOBUS_WR
);

    Pipeline_Reg_t pipeline_reg;


    // FETCH stage signals
    logic [DATAWIDTH - 1:0] PC, PC_in, IR;
    logic pc_sel;

    // DECODE stage signals
    logic [2:0] immed_sel;

    // EXECUTE stage signals
    logic [DATAWIDTH - 1:0] ALU_srcB, ALU_forward_muxA, ALU_forward_muxB, BRANCH_target, alu_result;
    logic branch_conditional_E;

    // MEMORY stage signals

    // WRITEBACK stage signals
    logic [DATAWIDTH - 1:0] rf_write_data;

    // HAZARD SIGNALS
    logic stall_F, stall_D, flush_E, flush_D;
    logic [1:0] forwardA_E, forwardB_E;

// ************************************************************************************************
// * Fetch (Instruction Memory) Stage
// ************************************************************************************************
    always_comb begin
        case(pc_sel)
            1'b0: PC_in = PC + 4;
            1'b1: PC_in = BRANCH_target;
        endcase
    end

    reg_nb #(.n(32)) PROGRAM_COUNTER (
        .clk            (CLK), 
        .data_in        (PC_in), 
        .ld             (stall_F), 
        .clr            (RESET), 
        .data_out       (PC)
    );

    Memory OTTER_MEMORY (
        .MEM_CLK        (CLK),
        .MEM_RDEN1      (1'b1),             // ! hardcoded for now  
        .MEM_RDEN2      (pipeline_reg.EX_MEM.memRead),    
        .MEM_WE2        (pipeline_reg.EX_MEM.memWrite),
        .MEM_ADDR1      (PC[15:2]),
        .MEM_ADDR2      (pipeline_reg.EX_MEM.ALU_result),
        .MEM_DIN2       (pipeline_reg.EX_MEM.write_data),  
        .MEM_SIZE       (pipeline_reg.EX_MEM.memRead_size),
        .MEM_SIGN       (pipeline_reg.EX_MEM.memRead_sign),
        .IO_IN          (0),
        .IO_WR          (),
        .MEM_DOUT1      (IR),
        .MEM_DOUT2      ()  
    );


// ************************************************************************************************
// * Decode (Register File) stage
// ************************************************************************************************

    // PIPELINE REG IF_DE
    always_ff @(posedge CLK ) begin
        if (flush_D == 1'b1) begin
            pipeline_reg.IF_DE.PC <= 0;
            pipeline_reg.IF_DE.IR <= 0;
        end
        else if (stall_D == 1'b0) begin
            pipeline_reg.IF_DE.PC <= PC;
            pipeline_reg.IF_DE.IR <= IR;
        end
    end

    always_comb begin
        pipeline_reg.IF_DE.rs1_addr = pipeline_reg.IF_DE.IR[19:15];
        pipeline_reg.IF_DE.rs2_addr = pipeline_reg.IF_DE.IR[24:20];
        pipeline_reg.IF_DE.rd_addr = pipeline_reg.IF_DE.IR[11:7];
    end

    ControlUnit CONTROL_UNIT (
        .opcode         (pipeline_reg.IF_DE.IR[6:0]),
        .func3          (pipeline_reg.IF_DE.IR[14:12]),
        .func7          (pipeline_reg.IF_DE.IR[30]),
        .regWrite       (),
        .memWrite       (),
        .memRead2       (),
        .jump           (),
        .branch         (),
        .alu_fun        (),
        .immed_sel      (immed_sel),
        .srcB_sel       (),
        .rf_wr_sel      ()
    );

    ImmedGen IMMED_GEN (
        .ir             (pipeline_reg.IF_DE.IR[31:7]),
        .immed_sel      (immed_sel),
        .immed_ext      ()
    );

    RegFile OTTER_REG_FILE (
        .clk            (CLK), 
        .en             (pipeline_reg.MEM_WB.regWrite),
        .adr1           (pipeline_reg.IF_DE.rs1_addr),
        .adr2           (pipeline_reg.IF_DE.rs2_addr),
        .wa             (pipeline_reg.MEM_WB.rd_addr),
        .wd             (rf_write_data),
        .rs1            (), 
        .rs2            ()  
    );


// ************************************************************************************************
// * Execute (ALU) Stage
// ************************************************************************************************

    // PIPELINE REG DE_EX
    always_ff @(posedge CLK) begin
        if (flush_E == 1'b1) begin
            pipeline_reg.DE_EX.PC <= 0;
            pipeline_reg.DE_EX.IR <= 0;
            pipeline_reg.DE_EX.regWrite <= 0;
            pipeline_reg.DE_EX.memWrite <= 0;
            pipeline_reg.DE_EX.memRead <= 0;
            pipeline_reg.DE_EX.jump <= 0;
            pipeline_reg.DE_EX.branch <= 0;
            pipeline_reg.DE_EX.alu_fun <= 0;
            pipeline_reg.DE_EX.imm <= 0;
            pipeline_reg.DE_EX.srcB_sel <= 0;
            pipeline_reg.DE_EX.rf_sel <= 0;
            pipeline_reg.DE_EX.rs1_data <= 0;
            pipeline_reg.DE_EX.rs2_data <= 0;
        end
        else begin
            pipeline_reg.DE_EX.PC <= pipeline_reg.IF_DE.PC;
            pipeline_reg.DE_EX.IR <= pipeline_reg.IF_DE.IR;
            pipeline_reg.DE_EX.rs1_data <= OTTER_REG_FILE.rs1;
            pipeline_reg.DE_EX.rs2_data <= OTTER_REG_FILE.rs2;
            pipeline_reg.DE_EX.rs1_addr <= pipeline_reg.IF_DE.rs1_addr;
            pipeline_reg.DE_EX.rs2_addr <= pipeline_reg.IF_DE.rs2_addr;
            pipeline_reg.DE_EX.rd_addr <= pipeline_reg.IF_DE.rd_addr;
            pipeline_reg.DE_EX.regWrite <= CONTROL_UNIT.regWrite;
            pipeline_reg.DE_EX.memWrite <= CONTROL_UNIT.memWrite;
            pipeline_reg.DE_EX.memRead <= CONTROL_UNIT.memRead2;
            pipeline_reg.DE_EX.jump <= CONTROL_UNIT.jump;
            pipeline_reg.DE_EX.branch <= CONTROL_UNIT.branch;
            pipeline_reg.DE_EX.alu_fun <= CONTROL_UNIT.alu_fun;
            pipeline_reg.DE_EX.imm <= IMMED_GEN.immed_ext;
            pipeline_reg.DE_EX.srcB_sel <= CONTROL_UNIT.srcB_sel;
            pipeline_reg.DE_EX.rf_sel <= CONTROL_UNIT.rf_wr_sel;
        end
    end

    

    branch_cond_gen branch_conditional(
        .rs1            (ALU_forward_muxA),
        .rs2            (ALU_forward_muxB),
        .instr          (pipeline_reg.DE_EX.IR[14:12]),
        .branch         (branch_conditional_E)
    );

    // MUXs for ALU inputs
    always_comb begin
        case (forwardA_E)
            2'b00: ALU_forward_muxA = pipeline_reg.DE_EX.rs1_data;
            2'b01: ALU_forward_muxA = rf_write_data;
            2'b10: ALU_forward_muxA = pipeline_reg.EX_MEM.ALU_result;
            default: ALU_forward_muxA = 32'hdeadbeef;
        endcase

        case (forwardB_E) 
            2'b00: ALU_forward_muxB = pipeline_reg.DE_EX.rs2_data;
            2'b01: ALU_forward_muxB = rf_write_data;
            2'b10: ALU_forward_muxB = pipeline_reg.EX_MEM.ALU_result;
            default: ALU_forward_muxB = 32'hdeadbeef;
        endcase

        case (pipeline_reg.DE_EX.srcB_sel)
            1'b0: ALU_srcB = ALU_forward_muxB;
            1'b1: ALU_srcB = pipeline_reg.DE_EX.imm;
            default: ALU_forward_muxB = 32'hdeadbeef;
        endcase

        pc_sel = pipeline_reg.DE_EX.jump | (pipeline_reg.DE_EX.branch & branch_conditional_E);

        case (pipeline_reg.DE_EX.IR[6:0])
            7'b1100111: BRANCH_target = OTTER_ALU.result; 
            default: BRANCH_target = pipeline_reg.DE_EX.PC + pipeline_reg.DE_EX.imm;
        endcase

        // ?auipc
        case (pipeline_reg.DE_EX.IR[6:0])
            7'b0010111: alu_result = BRANCH_target;
            default : alu_result = ALU.result;
        endcase

    end

    ALU OTTER_ALU(
        .alu_fun        (pipeline_reg.DE_EX.alu_fun),
        .srcA           (ALU_forward_muxA), 
        .srcB           (ALU_srcB), 
        .result         ()
    );


// ************************************************************************************************
// * Memory (Data Memory) stage 
// ************************************************************************************************

    // PIPELINE REG EX_MEM
    always_ff @(posedge CLK) begin
        if (flush_E == 1'b1) begin
            pipeline_reg.EX_MEM.PC <= 0;
            pipeline_reg.EX_MEM.ALU_result <= 0;
            pipeline_reg.EX_MEM.write_data <= 0;
            pipeline_reg.EX_MEM.rd_addr <= 0;
            pipeline_reg.EX_MEM.regWrite <= 0;
            pipeline_reg.EX_MEM.rf_sel <= 0;
            pipeline_reg.EX_MEM.memWrite <= 0;
            pipeline_reg.EX_MEM.memRead <= 0;
            pipeline_reg.EX_MEM.memRead_size <= 0;
            pipeline_reg.EX_MEM.memRead_sign <= 0;
        end
        else begin
            pipeline_reg.EX_MEM.PC <= pipeline_reg.DE_EX.PC;
            pipeline_reg.EX_MEM.ALU_result <= alu_result;
            pipeline_reg.EX_MEM.write_data <= ALU_forward_muxB;
            pipeline_reg.EX_MEM.rf_sel <= pipeline_reg.DE_EX.rf_sel;
            pipeline_reg.EX_MEM.rd_addr <= pipeline_reg.DE_EX.rd_addr;
            pipeline_reg.EX_MEM.regWrite <= pipeline_reg.DE_EX.regWrite;
            pipeline_reg.EX_MEM.memWrite <= pipeline_reg.DE_EX.memWrite;
            pipeline_reg.EX_MEM.memRead <= pipeline_reg.DE_EX.memRead;
            pipeline_reg.EX_MEM.memRead_size <= pipeline_reg.DE_EX.IR[13:12];
            pipeline_reg.EX_MEM.memRead_sign <= pipeline_reg.DE_EX.IR[14];
        end
    end

// ************************************************************************************************
// * Write (Write Back) stage
// ************************************************************************************************

    // PIPELINE REG MEM_WB
    always_ff @(posedge CLK) begin
        if (flush_E == 1'b1) begin
            pipeline_reg.MEM_WB.PC_plus4 <= 0;
            pipeline_reg.MEM_WB.ALU_result <= 0;
            pipeline_reg.MEM_WB.memRead_data <= 0;
            pipeline_reg.MEM_WB.rd_addr <= 0;
            pipeline_reg.MEM_WB.rf_sel <= 0;
            pipeline_reg.MEM_WB.regWrite <= 0;
        end
        else begin
            pipeline_reg.MEM_WB.PC_plus4 <= pipeline_reg.EX_MEM.PC + 4;
            pipeline_reg.MEM_WB.ALU_result <= pipeline_reg.EX_MEM.ALU_result;
            pipeline_reg.MEM_WB.memRead_data <= OTTER_MEMORY.MEM_DOUT2;
            pipeline_reg.MEM_WB.rd_addr <= pipeline_reg.EX_MEM.rd_addr;
            pipeline_reg.MEM_WB.rf_sel <= pipeline_reg.EX_MEM.rf_sel;
            pipeline_reg.MEM_WB.regWrite <= pipeline_reg.EX_MEM.regWrite;
        end
    end

    always_comb begin
        case (pipeline_reg.MEM_WB.rf_sel)
            2'b00: rf_write_data = pipeline_reg.MEM_WB.PC_plus4;
            2'b10: rf_write_data = pipeline_reg.MEM_WB.memRead_data;
            2'b11: rf_write_data = pipeline_reg.MEM_WB.ALU_result;
            default: rf_write_data = 32'hdead_beef;
        endcase
    end

// ************************************************************************************************
// * HAZARD UNUT
// ************************************************************************************************
    Hazard_Unit hazard_unit (
        .rs1_D          (pipeline_reg.IF_DE.IR[19:15]),
        .rs2_D          (pipeline_reg.IF_DE.IR[24:20]),
        .rs1_E          (pipeline_reg.DE_EX.rs1_addr),
        .rs2_E          (pipeline_reg.DE_EX.rs2_addr),
        .rd_E           (pipeline_reg.DE_EX.rd_addr),
        .rd_M           (pipeline_reg.EX_MEM.rd_addr),
        .rd_W           (pipeline_reg.MEM_WB.rd_addr),
        .rf_wr_sel_E    (pipeline_reg.DE_EX.rf_sel),
        .regWrite_M     (pipeline_reg.EX_MEM.regWrite),
        .regWrite_W     (pipeline_reg.MEM_WB.regWrite),
        .forwardA_E     (forwardA_E),
        .forwardB_E     (forwardB_E),
        .stall_F        (stall_F),
        .stall_D        (stall_D),
        .flush_D        (flush_D),
        .flush_E        (flush_E),
        .pcSource_E     (pc_sel)
    );

endmodule

