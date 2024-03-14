
 module OTTER_Wrapper(   
    input clk,              // 100 MHz clock
    input [4:0] buttons,  
    input [15:0] switches,   
    output logic [15:0] leds,
    output logic [7:0] segs,   
    output logic [3:0] an    
    ); 
         
    //- INPUT PORT IDS ---------------------------------------------------------
    localparam BUTTONS_PORT_ADDR      = 32'h11008004;  // 0x11008004
    localparam SWITCHES_PORT_ADDR     = 32'h11000004;  // 0x11000004  
                  
    //- OUTPUT PORT IDS --------------------------------------------------------
    localparam LEDS_PORT_ADDR         = 32'h1100C000;  // 0x1100C000 
    localparam SEGS_PORT_ADDR         = 32'h1100C004;  // 0x1100C004
    localparam ANODES_PORT_ADDR       = 32'h1100C008;  // 0x1100C008
     
    //- Signals for connecting OTTER_MCU to OTTER_wrapper 
    logic s_interrupt;  
    logic s_reset; 
    logic reset;
//    logic CLK_50MHz;           
    logic CLK_50MHz = 0;           
    logic [31:0] IOBUS_out; 
    logic [31:0] IOBUS_in;   
    logic [31:0] IOBUS_addr;  
    logic IOBUS_wr;   
        
    //- register for dev board output devices ---------------------------------
    logic [7:0]  r_segs;   //  register for segments (cathodes)
    logic [15:0] r_leds;   //  register for LEDs
    logic [3:0]  r_an;     //  register for display enables (anodes)
   
    
    assign s_interrupt = buttons[3];  // for btn(4) connecting to interrupt. Bottom button
    assign s_reset = buttons[4];      // for btn(3) connecting to reset

    //- Instantiate RISC-V OTTER MCU 
    OTTER_MCU my_otter(
        .CLK        (CLK_50MHz),
        .INTR       (1'b0),
        .RESET      (s_reset | reset), 
        .IOBUS_IN   (IOBUS_in),  
        .IOBUS_OUT  (IOBUS_out),  
        .IOBUS_ADDR (IOBUS_addr),
        .IOBUS_WR   (IOBUS_wr)
    );

    always_ff @(posedge clk) 
        CLK_50MHz <= ~CLK_50MHz;
      
   
    //- Drive dev board output devices with registers 
    always_ff @ (posedge clk) begin
        if (IOBUS_wr == 1) begin 
            case(IOBUS_addr)
                LEDS_PORT_ADDR:   r_leds <= IOBUS_out[15:0];    
                SEGS_PORT_ADDR:   r_segs <= IOBUS_out[7:0];
                ANODES_PORT_ADDR: r_an   <= IOBUS_out[3:0];
            endcase
         end 
     end
     
     
    //- MUX to route input devices to I/O Bus
    //- IOBUS_addr is the select signal to the MUX
    always_comb begin
        IOBUS_in = 32'b0; 
        case(IOBUS_addr) 
            BUTTONS_PORT_ADDR:      IOBUS_in[4:0] = buttons;
            SWITCHES_PORT_ADDR:     IOBUS_in[15:0] = switches;
            default:                IOBUS_in = 32'b0;
        endcase
    end
    
    //- assign registered outputs to actual outputs 
    assign leds = r_leds;  
    assign segs = r_segs; 
    assign an = r_an;   
    
    typedef enum logic [1:0] {
        INIT,
        STARTUP,
        RUNNING
    } state_t;

    state_t PS, NS;
    
    always_ff @(posedge clk) begin
        if (s_reset) begin
            PS <= INIT;
        end 
        else begin
            PS <= NS;
        end
    end


    always_comb begin
        reset = 1'b0;
        case(PS)
            INIT: begin
                reset = 1'b1;
                NS = STARTUP; 
            end
            
            STARTUP: begin
                reset = 1'b1;
                NS = RUNNING;
            end

            RUNNING: begin
                reset = 1'b0;
                NS = RUNNING;
            end
        default: NS = INIT;
        endcase
    end

endmodule