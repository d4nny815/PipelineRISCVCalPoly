// Memory Wrapper

/*
    instaniate MainMemory
    Memory myMemory (
        .MEM_CLK        (),
        .RST            (),
        .MEM_RDEN1      (),        
        .MEM_RDEN2      (),        
        .MEM_WE2        (),        
        .MEM_ADDR1      (),        
        .MEM_ADDR2      (),        
        .MEM_DIN2       (),        
        .MEM_SIZE       (),        
        .MEM_SIGN       (),        
        .MEM_DOUT1      (),        
        .MEM_DOUT2      (),        
        .memValid1      ()
    );
    )
*/

module Memory #(
    parameter DELAY_BITS = 4
    ) (
    input RST,
    input MEM_CLK, 
    input MEM_RDEN1,                // read enable Instruction
    input MEM_RDEN2,                // read enable data
    input MEM_WE2,                  // write enable.
    input [13:0] MEM_ADDR1,         // Instruction Memory word Addr (Connect to PC[15:2])
    input [31:0] MEM_ADDR2,         // Data Memory Addr
    input [31:0] MEM_DIN2,          // Data to save
    input [1:0] MEM_SIZE,           // 0-Byte, 1-Half, 2-Word
    input MEM_SIGN,                 // 1-unsigned 0-signed
    input [31:0] IO_IN,             // Data from IO     
    output logic IO_WR,             // IO 1-write 0-read
    output logic [31:0] MEM_DOUT1,  // Instruction
    output logic [31:0] MEM_DOUT2,  // Data
    output logic memValid1,
    output logic memValid2
    );

    // IMEM signals
    logic imem_hit;
    logic [31:0] instr_buffer;

    // DMEM signals
    logic dmem_hit, dmem_dirty;
    logic [31:0] wb_addr, data_buffer, dmem_addr_i;

    // CL signals
    logic cl_full;
    logic [31:0] line_data, line_addr, cl_addr_i, cl_data_i;

    // MM signals
    logic mm_mem_valid;
    logic [31:0] mm_data;

    // Control signals
    logic clr, imem_we, dmem_we, cl_we, cl_next, mm_re, mm_we;
    logic [1:0] cl_sel;

    logic mem_addr_valid1, mem_addr_valid2;


    always_comb begin
        mem_addr_valid1 = MEM_ADDR1 < (16'h6000 >> 2);
        if (!mem_addr_valid1) $error("MW: Invalid Instruction access memory address %x", {MEM_ADDR1, 2'b0});
        mem_addr_valid2 = MEM_ADDR2 >= (16'h6000 >> 2) && MEM_ADDR2 < (17'h1_0000);
        if (!mem_addr_valid2) $error("MW: Invalid Data access memory address %x", {MEM_ADDR2, 2'b0});
    end

    InstrL1 #(
        .ADDR_SIZE      (14), 
        .WORD_SIZE      (32),
        .LINES_PER_SET  (32),
        .WORDS_PER_LINE (8)
    ) instr_mem (
        .clk            (MEM_CLK),
        .reset          (clr),
        .we             (imem_we),
        .addr           (imem_we ? line_addr[15:2] : MEM_ADDR1),
        .data           (line_data),
        .dout           (instr_buffer),
        .hit            (imem_hit)
    );

    always_comb begin
       case (cl_sel)
            2'b00: dmem_addr_i = MEM_ADDR2;
            2'b01: dmem_addr_i = line_addr;
            2'b10: dmem_addr_i = {MEM_ADDR2[31:5], line_addr[5:0]};
            default: dmem_addr_i = 32'hdead_beef;
        endcase
    end

    DataL1 #(
        .ADDR_SIZE      (32), 
        .WORD_SIZE      (32),
        .LINES_PER_SET  (32),
        .WORDS_PER_LINE (8)
    ) data_mem (
        .clk            (MEM_CLK),
        .reset          (clr),
        .we             (cl_sel[1] ? 1'b0 : MEM_WE2),
        .we_cache       (dmem_we),
        .sign           (cl_sel[0] ? 1'b0 : MEM_SIGN),
        .size           (cl_sel[0] ? 2'b10 : MEM_SIZE),
        .addr           (dmem_addr_i),
        .data           (cl_sel[0] ? line_data : MEM_DIN2),
        .aout           (wb_addr),
        .dout           (data_buffer),
        .hit            (dmem_hit),
        .dirty          (dmem_dirty)
    );

    always_comb begin
        case (cl_sel)
            2'b00: cl_addr_i = {16'h0, MEM_ADDR1, 2'b0};
            2'b01: cl_addr_i = MEM_ADDR2;
            2'b10: cl_addr_i = {wb_addr[31:5], line_addr[4:0]};
            default: cl_addr_i = 32'hdead_beef;
        endcase
    end

    CacheLineAdapter #(
        .WORD_SIZE      (32),
        .WORDS_PER_LINE (8)
    ) cache_line_adapter (
        .clk            (MEM_CLK),
        .clr            (clr),
        .addr_i         (cl_addr_i),
        .data_i         (cl_sel[1] ? data_buffer : mm_data),
        .we             (cl_we),
        .next           (cl_next),
        .addr_o         (line_addr),
        .data_o         (line_data),
        .full           (cl_full)
    );

    MainMemory #(
        .DELAY_BITS     (3)
    ) main_memory (
        .MEM_CLK        (MEM_CLK),
        .MEM_RE         (mm_re),        
        .MEM_WE         (mm_we),        
        .MEM_DATA_IN    (line_data),        
        .MEM_ADDR       (line_addr[31:2]),        
        .MEM_DOUT       (mm_data),        
        .memValid       (mm_mem_valid)
    );

    CacheController cache_controller (
        .clk            (MEM_CLK),
        .reset          (RST),
        .re_imem        (MEM_RDEN1),
        .hit_imem       (imem_hit),
        .re_dmem        (MEM_RDEN2),
        .we_cpu_dmem    (MEM_WE2),
        .hit_dmem       (dmem_hit),
        .dirty_dmem     (dmem_dirty),
        .full_cl        (cl_full),
        .mem_valid_mm   (mm_mem_valid),
        .clr            (clr),
        .memValid1      (memValid1),
        .memValid2      (memValid2),
        .sel_cl         (cl_sel),
        .we_imem        (imem_we),
        .we_dmem        (dmem_we),
        .we_cl          (cl_we),
        .next_cl        (cl_next),
        .re_mm          (mm_re),
        .we_mm          (mm_we)
    );

    always_comb begin
        if (MEM_ADDR2 >= (17'h1_0000)) begin // MEM MAPPED IO
            IO_WR = MEM_WE2;
            MEM_DOUT2 = MEM_RDEN2 ? IO_IN : 32'hdead_beef;
        end
        else begin
            IO_WR = 1'b0;
            MEM_DOUT2 = memValid2 & mem_addr_valid2 ? data_buffer : 32'hdead_beef;
        end
        MEM_DOUT1 = memValid1 & mem_addr_valid1 ? instr_buffer : 32'hdead_beef;
    end

endmodule