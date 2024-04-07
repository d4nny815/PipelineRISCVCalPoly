// instanciate this module in the top level module

/*
    
    CacheController cache_controller (
        .clk            (),
        .reset          (),
        .re_imem        (),
        .hit_imem       (),
        .re_dmem        (),
        .we_cpu_dmem    (),
        .hit_dmem       (),
        .dirty_dmem     (),
        .full_cl        (),
        .mem_valid_mm   (),
        .clr            (),
        .memValid1      (),
        .memValid2      (),
        .sel_cl         (),
        .we_imem        (),
        .we_dmem        (),
        .we_cl          (),
        .next_cl        (),
        .re_mm          (),
        .we_mm          ()
    );

*/


module CacheController (
    input logic clk,
    input logic reset,
    
    // * INPUTS
    input logic re_imem,
    input logic hit_imem,

    input logic dmem_access,
    input logic hit_dmem,
    input logic dirty_dmem,
    
    input logic full_cl,

    input logic mem_valid_mm,
    
    // * OUTPUTS
    output logic clr,
    output logic memValid1,
    output logic memValid2,
    output logic [1:0] sel_cl,

    output logic we_imem,

    output logic we_dmem,
    
    output logic we_cl,
    output logic next_cl,

    output logic re_mm,
    output logic we_mm  
    );

    typedef enum logic [2:0] {
        INIT,
        CHECK_L1,
        FETCH_IMEM,
        FILL_IMEM,
        WB_DMEM,
        FILL_MM,
        FETCH_DMEM,
        FILL_DMEM
    } state_t;

    state_t state, next_state;


    always_ff @(posedge clk) begin
        if (reset == 1) 
            state <= INIT;
        else
            state <= next_state;
    end



    always_comb begin
        clr = 1'b0; memValid1 = 1'b0; memValid2 = 1'b0; sel_cl = 2'b0; 
        we_imem = 1'b0; we_dmem = 1'b0; we_cl = 1'b0; next_cl = 1'b0; re_mm = 1'b0; we_mm = 1'b0;

        case (state)
            INIT: begin
                clr = 1'b1;
                next_state = CHECK_L1;
            end

            CHECK_L1: begin
                memValid1 = hit_imem & re_imem;
                memValid2 = hit_dmem & dmem_access;

                if (hit_imem && re_imem && ~dmem_access) begin
                    next_state = CHECK_L1;
                end
                else if (!hit_imem && re_imem) begin
                    next_state = FETCH_IMEM;
                end
                else if (hit_dmem && dmem_access) begin
                    next_state = CHECK_L1;
                end
                else if (!hit_dmem && dmem_access && dirty_dmem) begin
                    next_state = WB_DMEM;
                end
                else if (!hit_dmem && dmem_access && !dirty_dmem) begin
                    next_state = FETCH_DMEM;
                end
                else begin
                    // if (~(re_imem || re_dmem || we_cpu_dmem)) $display("CC: Invalid state %x, %x, %x", re_imem, re_dmem, we_cpu_dmem);
                    next_state = CHECK_L1;
                end
            end

            FETCH_IMEM: begin
                we_cl = 1'b1;
                next_cl = mem_valid_mm;
                sel_cl = 2'b00;
                re_mm = 1'b1;
                if (full_cl & mem_valid_mm)
                    next_state = FILL_IMEM;
                else 
                    next_state = FETCH_IMEM;
            end

            FILL_IMEM: begin
                we_imem = 1'b1;
                sel_cl = 2'b00;
                next_cl = 1'b1;
                if (full_cl)
                    next_state = CHECK_L1;
                else
                    next_state = FILL_IMEM;
            end

            WB_DMEM: begin
                we_cl = 1'b1;
                sel_cl = 2'b10;
                next_cl = 1'b1;
                if (full_cl)
                    next_state = FILL_MM;
                else
                    next_state = WB_DMEM;
            end

            FILL_MM: begin
                we_mm = 1'b1;
                next_cl = mem_valid_mm;
                sel_cl = 2'b10;
                if (full_cl & mem_valid_mm)
                    next_state = FETCH_DMEM;
                else
                    next_state = FILL_MM;
            end

            FETCH_DMEM: begin
                we_cl = 1'b1;
                sel_cl = 2'b01;
                next_cl = mem_valid_mm;
                re_mm = 1'b1;
                if (full_cl & mem_valid_mm)
                    next_state = FILL_DMEM;
                else
                    next_state = FETCH_DMEM;
            end

            FILL_DMEM: begin
                we_dmem = 1'b1;
                sel_cl = 2'b01;
                next_cl = 1'b1;
                if (full_cl)
                    next_state = CHECK_L1;
                else
                    next_state = FILL_DMEM;
            end

        default: next_state = INIT;
        endcase
    end


endmodule