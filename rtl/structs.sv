package structs;

parameter DATAWIDTH = 32;

typedef struct packed {
    logic [DATAWIDTH - 1:0] PC;
    logic [DATAWIDTH - 1:0] IR;
    logic [4:0] rs1_addr;
    logic [4:0] rs2_addr;
    logic [4:0] rd_addr;
} IF_DE_t;

typedef struct packed {
    logic [DATAWIDTH - 1:0] PC;
    logic [DATAWIDTH - 1:0] IR;
    logic [4:0] rs1_addr;
    logic [4:0] rs2_addr;
    logic [4:0] rd_addr;
    logic [DATAWIDTH - 1:0] rs1_data;
    logic [DATAWIDTH - 1:0] rs2_data;
    logic [DATAWIDTH - 1:0] imm;
    logic [3:0] alu_fun;
    logic srcB_sel;
    logic regWrite;
    logic [1:0] rf_sel;
    logic memWrite;
    logic memRead;
    logic jump;
    logic branch;
} DE_EX_t;

typedef struct packed {
    logic [DATAWIDTH - 1:0] PC;
    logic [DATAWIDTH - 1:0] ALU_result;
    logic [DATAWIDTH - 1:0] write_data;
    logic [4:0] rd_addr;
    logic regWrite;
    logic [1:0] rf_sel;
    logic memWrite;
    logic memRead;
    logic [1:0] memRead_size;
    logic memRead_sign;
} EX_MEM_t;

typedef struct packed {
    logic [DATAWIDTH - 1:0] PC_plus4;
    logic [DATAWIDTH - 1:0] ALU_result;
    logic [DATAWIDTH - 1:0] memRead_data;
    logic [4:0] rd_addr;
    logic [1:0] rf_sel;
    logic regWrite;
} MEM_WB_t;

typedef struct packed {
    IF_DE_t IF_DE;
    DE_EX_t DE_EX;
    EX_MEM_t EX_MEM;
    MEM_WB_t MEM_WB;
} Pipeline_Reg_t;

endpackage : structs

module p_structs();
endmodule


