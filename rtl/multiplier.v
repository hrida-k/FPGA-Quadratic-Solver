`ifndef FP_MUL_V
`define FP_MUL_V

module mul(input clk,
           input reset_n,
           input start,
           input signed [31:0] data_A,
           input signed [31:0] data_B,
           
           output reg signed [31:0] result,
           output reg busy,
           output reg done,
           output reg overflow);

    reg signed [63:0] product;
    reg signed [31:0] a;
    reg signed [31:0] b;
    localparam IDLE = 2'b00, CALCULATE = 2'b01, COMPLETE = 2'b10;
    reg [1:0] state, next_state;

    always @(posedge clk or negedge reset_n) begin
        if(!reset_n) 
            state <= IDLE;
        else 
            state <= next_state;
    end

    always @(*) begin
        case(state)
            IDLE: next_state = (start && !busy) ? CALCULATE : IDLE;

            CALCULATE : next_state = COMPLETE;

            COMPLETE : next_state = IDLE;

            default : next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge reset_n) begin
        if(!reset_n) begin
            product <= 64'b0;
            a <= 32'b0;
            b <= 32'b0;
            // Driving outputs to ZERO
            busy <= 1'b0;
            done <= 1'b0;
            overflow <= 1'b0;
            result <= 32'b0;
        end
        else begin
            busy <= (next_state != IDLE); 

            a <= (next_state == CALCULATE) ? data_A : a;
            b <= (next_state == CALCULATE) ? data_B : b;
            product <= (state == CALCULATE) ? (a * b) : product;

            result <= (state == COMPLETE) ? product[47:16] : result;
            done <= (state == COMPLETE);

            overflow <= (state == COMPLETE) ? (product[63:48] != {16{product[47]}}) : overflow;

        end
    end
endmodule

`endif