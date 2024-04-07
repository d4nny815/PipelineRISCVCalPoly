/*
    instaniate MainMemory
    MainMemory #(
        .DELAY_CYCLES(10),
        .BURST_WIDTH(8)
    ) myMemory (
        .MEM_CLK        (),
        .RST            (),
        .MEM_RE         (),        
        .MEM_WE         (),        
        .MEM_DATA_IN    (),        
        .MEM_ADDR       (),        
        .MEM_DOUT       (),        
        .memValid       ()
    );
*/
 
 module SinglePortDelayMemory #(
    parameter DELAY_CYCLES = 10,
    parameter BURST_LEN = 4
    ) (
    input CLK,
    input RE,
    input WE,
    input [31:0] DATA_IN,
    input [31:0] ADDR,
    output logic MEM_VALID,
    output logic [31:0] DATA_OUT
    );
    
    logic [31:0] memory [0:16383];
    initial begin
        $readmemh("otter_mem.mem", memory, 0, 16383);
    end

    initial begin
        forever begin
            MEM_VALID = 0;
            @(posedge CLK iff RE | WE);
            for (int i = 0; i < DELAY_CYCLES; i++) begin
                @(posedge CLK);
            end
            for (int i = 0; i < BURST_LEN; i++) begin
                if (RE ^ WE)
                    MEM_VALID = 1;
                else
                    MEM_VALID = 0;
                @(posedge CLK);
            end
        end
    end

    always_comb begin 
        DATA_OUT = MEM_VALID ? memory[ADDR] : 32'hdeadbeef;
    end

    always_ff @(negedge CLK) begin
        if (WE && MEM_VALID) begin
            memory[ADDR] <= DATA_IN;
        end
    end
 
endmodule
