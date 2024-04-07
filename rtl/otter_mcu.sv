import structs::*;

module OTTER_MCU (
    input CLK,    
    input INTR,       
    input RESET,      
    input [31:0] IOBUS_IN,    
    output [31:0] IOBUS_OUT,    
    output [31:0] IOBUS_ADDR,
    output logic IOBUS_WR
    // output logic [31:0] PC_CNT
);

    IF_DE_t IF_DE;
    DE_EX_t DE_EX;
    EX_MEM_t EX_MEM;
    MEM_WB_t MEM_WB;

    // FETCH stage signals
    logic [DATAWIDTH - 1:0] PC, PC_in, IR;
    logic pc_sel;

    // DECODE stage signals
    logic regWrite, memWrite, memRead2, jump, branch, srcB_sel;
    logic [1:0] rf_wr_sel;
    logic [2:0] immed_sel;
    logic [3:0] alu_fun;
    logic [4:0] rs1_addr, rs2_addr, rd_addr;
    logic [DATAWIDTH - 1:0] rs1_data, rs2_data, immed_ext;
    
    // EXECUTE stage signals
    logic [DATAWIDTH - 1:0] ALU_srcB, ALU_forward_muxA, ALU_forward_muxB, BRANCH_target, alu_result, internal_alu;
    logic branch_conditional_E;

    // MEMORY stage signals
    logic [DATAWIDTH - 1:0] memRead_data;

    // WRITEBACK stage signals
    logic [DATAWIDTH - 1:0] rf_write_data;

    // HAZARD SIGNALS
    logic stall_F, stall_D, stall_E, stall_M, stall_W, 
        flush_F, flush_E, flush_D, flush_M, flush_W, 
        memValid1, memValid2;
    logic [1:0] forwardA_E, forwardB_E;

// *********************************************************************************
// * Fetch (Instruction Memory) Stage
// *********************************************************************************
    always_comb begin
        // PC_CNT = PC;
        case(pc_sel)
            1'b0: PC_in = PC + 4;
            1'b1: PC_in = BRANCH_target;
        endcase
    end

    reg_nb #(.n(32)) PROGRAM_COUNTER (
        .clk            (CLK), 
        .data_in        (PC_in), 
        .ld             (stall_F), 
        .clr            (flush_F), 
        .data_out       (PC)
    );

//    Memory OTTER_MEMORY (
//        .MEM_CLK        (CLK),
//        .MEM_RDEN1      (1'b1),             // ! hardcoded for now  
//        .MEM_RDEN2      (EX_MEM.memRead),    
//        .MEM_WE2        (EX_MEM.memWrite),
//        .MEM_ADDR1      (PC[15:2]),
//        .MEM_ADDR2      (EX_MEM.ALU_result),
//        .MEM_DIN2       (EX_MEM.write_data),  
//        .MEM_SIZE       (EX_MEM.memRead_size),
//        .MEM_SIGN       (EX_MEM.memRead_sign),
//        .IO_IN          (IOBUS_IN),
//        .IO_WR          (IOBUS_WR),
//        .MEM_DOUT1      (IR),
//        .MEM_DOUT2      (memRead_data)  
//    );

    OtterMemory OTTER_MEMORY (
        .MEM_CLK        (CLK),
        .MEM_RST        (RESET),
        .MEM_RDEN1      (1'b1),             // ! hardcoded for now  
        .MEM_RDEN2      (EX_MEM.memRead),    
        .MEM_WE2        (EX_MEM.memWrite),
        .MEM_ADDR1      (PC[15:2]),
        .MEM_ADDR2      (EX_MEM.ALU_result),
        .MEM_DIN2       (EX_MEM.write_data),  
        .MEM_SIZE       (EX_MEM.memRead_size),
        .MEM_SIGN       (EX_MEM.memRead_sign),
        .IO_IN          (IOBUS_IN),
        .IO_WR          (IOBUS_WR),
        .MEM_DOUT1      (IR),
        .MEM_DOUT2      (memRead_data),
        .MEM_VALID1     (memValid1),
        .MEM_VALID2     (memValid2)  
    );
    

// *********************************************************************************
// * Decode (Register File) stage
// *********************************************************************************
    // PIPELINE REG IF_DE
    always_ff @(posedge CLK ) begin
        if (flush_D == 1'b1) begin
            IF_DE.PC <= 0;
            IF_DE.IR <= 0;
        end
        else if (stall_D == 1'b0) begin
            IF_DE.PC <= PC;
            IF_DE.IR <= IR;
        end
    end

    always_comb begin
        IF_DE.rs1_addr = IF_DE.IR[19:15];
        IF_DE.rs2_addr = IF_DE.IR[24:20];
        IF_DE.rd_addr = IF_DE.IR[11:7];
    end

    ControlUnit CONTROL_UNIT (
        .opcode         (IF_DE.IR[6:0]),
        .func3          (IF_DE.IR[14:12]),
        .func7          (IF_DE.IR[30]),
        .regWrite       (regWrite),
        .memWrite       (memWrite),
        .memRead2       (memRead2),
        .jump           (jump),
        .branch         (branch),
        .alu_fun        (alu_fun),
        .immed_sel      (immed_sel),
        .srcB_sel       (srcB_sel),
        .rf_wr_sel      (rf_wr_sel)
    );

    ImmedGen IMMED_GEN (
        .ir             (IF_DE.IR[31:7]),
        .immed_sel      (immed_sel),
        .immed_ext      (immed_ext)
    );

    RegFile OTTER_REG_FILE (
        .clk            (CLK), 
        .en             (MEM_WB.regWrite),
        .adr1           (IF_DE.rs1_addr),
        .adr2           (IF_DE.rs2_addr),
        .wa             (MEM_WB.rd_addr),
        .wd             (rf_write_data),
        .rs1            (rs1_data), 
        .rs2            (rs2_data)  
    );


// *********************************************************************************
// * Execute (ALU) Stage
// *********************************************************************************
    // PIPELINE REG DE_EX
    always_ff @(posedge CLK) begin
        if (flush_E == 1'b1) begin
            DE_EX.PC <= 0;
            DE_EX.IR <= 0;
            DE_EX.regWrite <= 0;
            DE_EX.memWrite <= 0;
            DE_EX.memRead <= 0;
            DE_EX.jump <= 0;
            DE_EX.branch <= 0;
            DE_EX.alu_fun <= 0;
            DE_EX.imm <= 0;
            DE_EX.srcB_sel <= 0;
            DE_EX.rf_sel <= 0;
            DE_EX.rs1_data <= 0;
            DE_EX.rs2_data <= 0;
            DE_EX.rs1_addr <= 0;
            DE_EX.rs2_addr <= 0;
            DE_EX.rd_addr <= 0;
        end
        else if (stall_E == 1'b0) begin
            DE_EX.PC <= IF_DE.PC;
            DE_EX.IR <= IF_DE.IR;
            DE_EX.regWrite <= regWrite;
            DE_EX.memWrite <= memWrite;
            DE_EX.memRead <= memRead2;
            DE_EX.jump <= jump;
            DE_EX.branch <= branch;
            DE_EX.alu_fun <= alu_fun;
            DE_EX.imm <= immed_ext;
            DE_EX.srcB_sel <= srcB_sel;
            DE_EX.rf_sel <= rf_wr_sel;
            DE_EX.rs1_data <= rs1_data;
            DE_EX.rs2_data <= rs2_data;
            DE_EX.rs1_addr <= IF_DE.rs1_addr;
            DE_EX.rs2_addr <= IF_DE.rs2_addr;
            DE_EX.rd_addr <= IF_DE.rd_addr;
        end
    end
    

    BranchCondGen BRANCH_CONDITIONAL(
        .rs1            (ALU_forward_muxA),
        .rs2            (ALU_forward_muxB),
        .instr          (DE_EX.IR[14:12]),
        .branch         (branch_conditional_E)
    );

    // MUXs for ALU inputs
    always_comb begin
        case (forwardA_E)
            2'b00: ALU_forward_muxA = DE_EX.rs1_data;
            2'b01: ALU_forward_muxA = EX_MEM.ALU_result;
            2'b10: ALU_forward_muxA = rf_write_data;
            default: ALU_forward_muxA = 32'hdeadbeef;
        endcase

        case (forwardB_E) 
            2'b00: ALU_forward_muxB = DE_EX.rs2_data;
            2'b01: ALU_forward_muxB = EX_MEM.ALU_result;
            2'b10: ALU_forward_muxB = rf_write_data;
            default: ALU_forward_muxB = 32'hdeadbeef;
        endcase

        case (DE_EX.srcB_sel)
            1'b0: ALU_srcB = ALU_forward_muxB;
            1'b1: ALU_srcB = DE_EX.imm;
            default: ALU_forward_muxB = 32'hdeadbeef;
        endcase

        pc_sel = DE_EX.jump | (DE_EX.branch & branch_conditional_E);

        case (DE_EX.IR[6:0])
            7'b1100111: BRANCH_target = internal_alu; 
            default: BRANCH_target = DE_EX.PC + DE_EX.imm;
        endcase

        // ? auipc
        case (DE_EX.IR[6:0])
            7'b0010111: alu_result = BRANCH_target;
            default : alu_result = internal_alu;
        endcase

    end

    ALU OTTER_ALU(
        .alu_fun        (DE_EX.alu_fun),
        .srcA           (ALU_forward_muxA), 
        .srcB           (ALU_srcB), 
        .result         (internal_alu)
    );
    

// *********************************************************************************
// * Memory (Data Memory) stage 
// *********************************************************************************

    // PIPELINE REG EX_MEM
    always_ff @(posedge CLK) begin
        if (flush_M == 1'b1) begin
            EX_MEM.PC           <= 0;
            EX_MEM.ALU_result   <= 0;
            EX_MEM.write_data   <= 0;
            EX_MEM.rf_sel       <= 0;
            EX_MEM.rd_addr      <= 0;
            EX_MEM.regWrite     <= 0;
            EX_MEM.memWrite     <= 0;
            EX_MEM.memRead      <= 0;
            EX_MEM.memRead_size <= 0;
            EX_MEM.memRead_sign <= 0;
        end
        else if (stall_M == 1'b0) begin
            EX_MEM.PC           <= DE_EX.PC;
            EX_MEM.ALU_result   <= alu_result;
            EX_MEM.write_data   <= ALU_forward_muxB;
            EX_MEM.rf_sel       <= DE_EX.rf_sel;
            EX_MEM.rd_addr      <= DE_EX.rd_addr;
            EX_MEM.regWrite     <= DE_EX.regWrite;
            EX_MEM.memWrite     <= DE_EX.memWrite;
            EX_MEM.memRead      <= DE_EX.memRead;
            EX_MEM.memRead_size <= DE_EX.IR[13:12];
            EX_MEM.memRead_sign <= DE_EX.IR[14];
        end
    end
    
    assign IOBUS_OUT = EX_MEM.write_data;
    assign IOBUS_ADDR = EX_MEM.ALU_result;


// *********************************************************************************
// * Write (Write Back) stage
// *********************************************************************************
    // PIPELINE REG MEM_WB
    always_ff @(posedge CLK) begin
        if (flush_W == 1'b1) begin
            MEM_WB.PC_plus4     <= 0;
            MEM_WB.ALU_result   <= 0;
            MEM_WB.memRead_data <= 0;
            MEM_WB.rd_addr      <= 0;
            MEM_WB.rf_sel       <= 0;
            MEM_WB.regWrite     <= 0;
        end
        else if (stall_W == 1'b0) begin
            MEM_WB.PC_plus4     <= EX_MEM.PC + 4;
            MEM_WB.ALU_result   <= EX_MEM.ALU_result;
            MEM_WB.memRead_data <= memRead_data;
            MEM_WB.rd_addr      <= EX_MEM.rd_addr;
            MEM_WB.rf_sel       <= EX_MEM.rf_sel;
            MEM_WB.regWrite     <= EX_MEM.regWrite;
        end
    end

    always_comb begin
        case (MEM_WB.rf_sel)
            2'b00: rf_write_data = MEM_WB.PC_plus4;
            2'b10: rf_write_data = MEM_WB.memRead_data;
            2'b11: rf_write_data = MEM_WB.ALU_result;
            default: rf_write_data = 32'hdead_beef;
        endcase
    end


// *********************************************************************************
// * HAZARD UNUT
// *********************************************************************************
    HazardUnit HAZARD_UNIT (
        .reset          (RESET),
        .rs1_D          (IF_DE.rs1_addr),
        .rs2_D          (IF_DE.rs2_addr),
        .rs1_E          (DE_EX.rs1_addr),
        .rs2_E          (DE_EX.rs2_addr),
        .rd_E           (DE_EX.rd_addr),
        .rd_M           (EX_MEM.rd_addr),
        .rd_W           (MEM_WB.rd_addr),
        .rf_wr_sel_E    (DE_EX.rf_sel),
        .regWrite_M     (EX_MEM.regWrite),
        .regWrite_W     (MEM_WB.regWrite),
        .memValid1      (memValid1),
        .memValid2      (memValid2),
        .forwardA_E     (forwardA_E),
        .forwardB_E     (forwardB_E),
        .stall_F        (stall_F),
        .stall_D        (stall_D),
        .stall_E        (stall_E),
        .stall_M        (stall_M),
        .stall_W        (stall_W),
        .flush_F        (flush_F),
        .flush_D        (flush_D),
        .flush_E        (flush_E),
        .flush_M        (flush_M),
        .flush_W        (flush_W),
        .pcSource_E     (pc_sel)
    );

endmodule

