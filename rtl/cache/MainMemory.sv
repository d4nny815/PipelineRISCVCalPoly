/*
    instaniate MainMemory
    MainMemory #(
        .DELAY_BITS     ()
    ) myMemory (
        .MEM_CLK        (),
        .MEM_RE         (),        
        .MEM_WE         (),        
        .MEM_DATA_IN    (),        
        .MEM_ADDR       (),        
        .MEM_DOUT       (),        
        .memValid       ()
    );
*/


module MainMemory #(
    parameter DELAY_BITS = 4
    ) (
    input MEM_CLK,
    // input RST,
    input MEM_RE,                // read enable Instruction
    input MEM_WE,
    input [31:0] MEM_DATA_IN,          // Data to save
    input [29:0] MEM_ADDR,         // Data Memory Addr
    output logic [31:0] MEM_DOUT,  // Instruction
    output logic memValid
    ); 

    logic [DELAY_BITS - 1:0] count = 0;
    always_ff @(posedge MEM_CLK) begin
        if (MEM_RE | MEM_WE)
            count <= count + 1;
        else
            count <= 0;
    end

    always_comb begin
        memValid = &count;
    end
    
       
    (* rom_style="{distributed | block}" *)
    (* ram_decomp = "power" *) logic [31:0] memory [0:16383];
    
    initial begin
        $readmemh("otter_memory.mem", memory, 0, 16383);
    end
    

    always_ff @(negedge MEM_CLK) begin
        if (MEM_WE & memValid)
            memory[MEM_ADDR] <= MEM_DATA_IN;
    end
        
    always_comb begin
        MEM_DOUT = memValid & MEM_RE ? memory[MEM_ADDR] : 32'hdead_beef;        
    end
        
 endmodule