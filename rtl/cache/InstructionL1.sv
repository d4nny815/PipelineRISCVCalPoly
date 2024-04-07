/*
    instruction cache L1
    InstrL1 #(
        .ADDR_SIZE      (14), 
        .WORD_SIZE      (32),
        .LINES_PER_SET  (32),
        .WORDS_PER_LINE (8)
    ) instr_mem (
        .clk            (),
        .reset          (),
        .we             (),
        .addr           (),
        .data           (),
        .dout           (),
        .hit            ()
    );
*/


module InstrL1 #(
    parameter WORD_SIZE = 32,
    parameter ADDR_SIZE = 14,
    parameter LINES_PER_SET = 32,
    parameter WORDS_PER_LINE = 8
    ) (
    input logic clk,
    input logic reset,
    input logic we,
    input logic [ADDR_SIZE - 1:0] addr,
    input logic [WORD_SIZE - 1:0] data,
    output logic [WORD_SIZE - 1:0] dout,
    output logic hit
    );


    localparam SET_LINE_BITS = $clog2(LINES_PER_SET);
    localparam WORD_OFFSET_BITS = $clog2(WORDS_PER_LINE);
    localparam TAG_BITS = ADDR_SIZE - SET_LINE_BITS - WORD_OFFSET_BITS;
    localparam SET_SIZE = WORDS_PER_LINE * WORD_SIZE;

    logic [SET_SIZE - 1:0] set0 [LINES_PER_SET - 1:0];
    logic [SET_SIZE - 1:0] set1 [LINES_PER_SET - 1:0];
    logic [TAG_BITS - 1:0] tag0 [LINES_PER_SET - 1:0];
    logic [TAG_BITS - 1:0] tag1 [LINES_PER_SET - 1:0];
    logic [LINES_PER_SET - 1:0] valid0, valid1;
    logic [LINES_PER_SET - 1:0] lru_bits;

    logic [WORD_SIZE * WORDS_PER_LINE - 1:0] line_buffer;
    logic [WORD_OFFSET_BITS - 1:0] word_offset;
    logic [SET_LINE_BITS - 1:0] set_index;
    logic [TAG_BITS:0] tag;
    logic hit0, hit1;

    always_comb begin
        word_offset = addr[WORD_OFFSET_BITS - 1:0];
        set_index = addr[SET_LINE_BITS + WORD_OFFSET_BITS - 1:WORD_OFFSET_BITS];
        tag = addr[ADDR_SIZE - 1:SET_LINE_BITS + WORD_OFFSET_BITS];
    end


    // async read
    always_comb begin
        if (valid0[set_index] && tag0[set_index] == tag) begin
            hit0 = 1'b1;
            hit1 = 1'b0;
            line_buffer = set0[set_index];
        end else if (valid1[set_index] && tag1[set_index] == tag) begin
            hit1 = 1'b1;
            hit0 = 1'b0;
            line_buffer = set1[set_index];
        end else begin
            hit0 = 1'b0;
            hit1 = 1'b0;
            line_buffer = -1;
        end

        hit = hit0 ^ hit1;
        dout = line_buffer[WORD_SIZE * (word_offset + 1) - 1 -: WORD_SIZE];
    end
    

    // sync write
    always_ff @( negedge clk ) begin
        if (reset) begin
            for (int i = 0; i < LINES_PER_SET; i++) begin
                valid0[i] <= 0;
                valid1[i] <= 0;
                lru_bits[i] <= 0;
            end
        end
        else begin
            if (we) begin
                if (lru_bits[set_index] == 0) begin // set1 is LRU
                    set0[set_index][WORD_SIZE * word_offset +: WORD_SIZE] <= data;
                    if (word_offset == 2 ** WORD_OFFSET_BITS - 1) begin  // last word in line
                        valid0[set_index] <= 1;
                        tag0[set_index] <= tag;
                    end
                end
                else begin   // set0 is LRU
                    set1[set_index][WORD_SIZE * word_offset +: WORD_SIZE] <= data;
                    if (word_offset == 2 ** WORD_OFFSET_BITS - 1) begin  // last word in line
                        valid1[set_index] <= 1;
                        tag1[set_index] <= tag;
                    end
                end
            end

            if (hit0) begin
                lru_bits[set_index] <= 1;
            end
            else if (hit1) begin
                lru_bits[set_index] <= 0;
            end
        end
    end
endmodule