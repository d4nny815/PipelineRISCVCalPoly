
module CacheLineAdapter #(
    parameter WORD_SIZE = 32,
    parameter WORDS_PER_LINE = 8
    ) (
    input clk,
    input clr,
    input [WORD_SIZE - 1:0] addr_i,
    input [WORD_SIZE - 1:0] data_i,
    input we,
    input next,
    output logic [WORD_SIZE - 1:0] addr_o,
    output logic [WORD_SIZE - 1:0] data_o,
    output logic full
    );

    localparam LINE_BITS = $clog2(WORDS_PER_LINE);
    localparam BYTE_BITS = 2;

    // addr_gen
    logic [LINE_BITS - 1:0] counter = 0;
    always_ff @(posedge clk) begin
        if (clr == 1) begin
            counter <= 0;
        end
        else if (next == 1)
            counter <= counter + 1;
    end


    logic [WORD_SIZE - 1:0] line_buffer [WORDS_PER_LINE - 1:0];

    always_comb begin
        full = (counter == WORDS_PER_LINE - 1);
        addr_o = (addr_i[WORD_SIZE - 1:LINE_BITS + BYTE_BITS] << (LINE_BITS + BYTE_BITS)) + (counter << BYTE_BITS);
        data_o = line_buffer[counter]; 
    end

    always_ff @(posedge clk) begin
        if (we) 
            line_buffer[counter] <= data_i;
    end



endmodule