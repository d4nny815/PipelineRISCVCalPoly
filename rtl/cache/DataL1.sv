/*
    instatiate this module

    DataL1 #(
        .WORD_SIZE      (32),
        .ADDR_SIZE      (32),
        .LINES_PER_SET  (32),
        .WORDS_PER_LINE (8)
    ) data_mem (
        .clk            (),
        .reset          (),
        .we             (),
        .we_cache       (),
        .sign           (),
        .size           (),
        .addr           (),
        .data           (),
        .aout           (),
        .dout           (),
        .hit            (),
        .dirty          ()
    );
*/


module DataL1 #(
    parameter WORD_SIZE = 32,
    parameter ADDR_SIZE = 32,
    parameter LINES_PER_SET = 32,
    parameter WORDS_PER_LINE = 8
    ) (
    input logic clk,
    input logic reset,
    input logic we,
    input logic we_cache,
    input logic sign,
    input logic [1:0] size,
    input logic [ADDR_SIZE - 1:0] addr,
    input logic [WORD_SIZE - 1:0] data,
    output logic [ADDR_SIZE - 1:0] aout,
    output logic [WORD_SIZE - 1:0] dout,
    output logic hit,
    output logic dirty
    );

    localparam BYTE_SIZE = 8;
    localparam BYTE_OFFSET_BITS = 2;
    localparam SET_LINE_BITS = $clog2(LINES_PER_SET);
    localparam WORD_OFFSET_BITS = $clog2(WORDS_PER_LINE);
    localparam TAG_BITS = ADDR_SIZE - SET_LINE_BITS - WORD_OFFSET_BITS - BYTE_OFFSET_BITS;
    localparam SET_SIZE = WORDS_PER_LINE * WORD_SIZE;

    logic [SET_SIZE - 1:0] set0 [LINES_PER_SET - 1:0];
    logic [SET_SIZE - 1:0] set1 [LINES_PER_SET - 1:0];
    logic [TAG_BITS - 1:0] tag0 [LINES_PER_SET - 1:0];
    logic [TAG_BITS - 1:0] tag1 [LINES_PER_SET - 1:0];
    logic [LINES_PER_SET - 1:0] dirty0, dirty1;
    logic [LINES_PER_SET - 1:0] valid0, valid1;
    logic [LINES_PER_SET - 1:0] lru_bits;   // * if 0, set1 is LRU, if 1, set0 is LRU

    logic [WORD_SIZE * WORDS_PER_LINE - 1:0] line_buffer;
    logic [WORD_SIZE - 1:0] word_buffer;
    logic [WORD_OFFSET_BITS - 1:0] word_offset;
    logic [SET_LINE_BITS - 1:0] set_index;
    logic [TAG_BITS:0] tag;
    logic [BYTE_OFFSET_BITS - 1:0] byte_offset;
    logic hit0, hit1;

    always_comb begin
        byte_offset = addr[BYTE_OFFSET_BITS - 1:0];
        word_offset = addr[WORD_OFFSET_BITS + BYTE_OFFSET_BITS - 1:BYTE_OFFSET_BITS];
        set_index = addr[SET_LINE_BITS + WORD_OFFSET_BITS + BYTE_OFFSET_BITS - 1:WORD_OFFSET_BITS + BYTE_OFFSET_BITS];
        tag = addr[ADDR_SIZE - 1:SET_LINE_BITS + WORD_OFFSET_BITS + BYTE_OFFSET_BITS];
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
            line_buffer = lru_bits[set_index] ? set1[set_index] : set0[set_index];
        end

        dirty = lru_bits[set_index] ? dirty1[set_index] : dirty0[set_index];
        hit = hit0 ^ hit1;
        word_buffer = line_buffer[WORD_SIZE * (word_offset + 1) - 1 -: WORD_SIZE];

        aout = lru_bits[set_index] ? {tag1[set_index], set_index} << (WORD_OFFSET_BITS + BYTE_OFFSET_BITS) : {tag0[set_index], set_index} << (WORD_OFFSET_BITS + BYTE_OFFSET_BITS);
    end

    always_comb begin
        case({sign, size, byte_offset})
            5'b00011: dout = {{24{word_buffer[31]}},word_buffer[31:24]};    // signed byte
            5'b00010: dout = {{24{word_buffer[23]}},word_buffer[23:16]};
            5'b00001: dout = {{24{word_buffer[15]}},word_buffer[15:8]};
            5'b00000: dout = {{24{word_buffer[7]}},word_buffer[7:0]};
                                    
            5'b00110: dout = {{16{word_buffer[31]}},word_buffer[31:16]};    // signed half
            5'b00101: dout = {{16{word_buffer[23]}},word_buffer[23:8]};
            5'b00100: dout = {{16{word_buffer[15]}},word_buffer[15:0]};
            
            5'b01000: dout = word_buffer;                   // word
               
            5'b10011: dout = {24'd0,word_buffer[31:24]};    // unsigned byte
            5'b10010: dout = {24'd0,word_buffer[23:16]};
            5'b10001: dout = {24'd0,word_buffer[15:8]};
            5'b10000: dout = {24'd0,word_buffer[7:0]};
               
            5'b10110: dout = {16'd0,word_buffer[31:16]};    // unsigned half
            5'b10101: dout = {16'd0,word_buffer[23:8]};
            5'b10100: dout = {16'd0,word_buffer[15:0]};
            
            default:  dout = word_buffer;     // unsupported size, byte offset combination 
        endcase
    end
    

    // sync write
    always_ff @( negedge clk ) begin
        if (reset) begin
            for (int i = 0; i < LINES_PER_SET; i++) begin
                valid0[i] <= 0;
                valid1[i] <= 0;
                lru_bits[i] <= 0;
                dirty0[i] <= 0;
                dirty1[i] <= 0;
            end
        end
        else begin
            if (we_cache) begin // write from cache line adapter
                if (lru_bits[set_index] == 0) begin // set1 is LRU
                    set0[set_index][WORD_SIZE * word_offset +: WORD_SIZE] <= data;
                    if (word_offset == 2 ** WORD_OFFSET_BITS - 1) begin  // last word in line
                        valid0[set_index] <= 1;
                        tag0[set_index] <= tag;
                        dirty0[set_index] <= 0;
                    end
                end
                else begin   // set0 is LRU
                    set1[set_index][WORD_SIZE * word_offset +: WORD_SIZE] <= data;
                    if (word_offset == 2 ** WORD_OFFSET_BITS - 1) begin  // last word in line
                        valid1[set_index] <= 1;
                        tag1[set_index] <= tag;
                        dirty1[set_index] <= 0;
                    end
                end
            end

            else if (we) begin // write from CPU
                if (hit0) begin
                    case (size)
                        2'b00: set0[set_index][WORD_SIZE * word_offset + (BYTE_SIZE * byte_offset) +: WORD_SIZE / 4] <= data[WORD_SIZE / 2 - 1:0]; // byte
                        2'b01: set0[set_index][WORD_SIZE * word_offset + (BYTE_SIZE * byte_offset) +: WORD_SIZE / 2] <= data[WORD_SIZE / 2 - 1:0]; // half word
                        2'b10: set0[set_index][WORD_SIZE * word_offset +: WORD_SIZE] <= data; // word
                    endcase
                    dirty0[set_index] <= 1;
                end
                else if (hit1) begin
                    case (size)
                        2'b00: set1[set_index][WORD_SIZE * word_offset + (BYTE_SIZE * byte_offset) +: WORD_SIZE / 4] <= data[WORD_SIZE / 4 - 1:0]; // byte
                        2'b01: set1[set_index][WORD_SIZE * word_offset + (BYTE_SIZE * byte_offset) +: WORD_SIZE / 2] <= data[WORD_SIZE / 2 - 1:0]; // half word
                        2'b10: set1[set_index][WORD_SIZE * word_offset +: WORD_SIZE] <= data; // word
                    endcase
                    dirty1[set_index] <= 1;
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