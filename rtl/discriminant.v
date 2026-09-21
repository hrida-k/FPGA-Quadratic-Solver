`include "fp_mul.v"

module discriminant(input clk,
                    input reset_n,
                    input signed [31:0] A,
                    input signed [31:0] B,
                    input signed [31:0] C,
                    input start,

                    output reg signed [31:0] out,
                    output reg is_negative,
                    output reg is_zero,
                    output reg busy,
                    output reg done);

    localparam  IDLE        = 3'b000,
                B2          = 3'b001,
                AC          = 3'b010,
                FOUR_AC     = 3'b011,
                SUBTRACT    = 3'b100,
                DONE        = 3'b101;

    reg [2:0] state, next_state;
    reg signed [31:0] mul_A, mul_B, reg_A, reg_C;

    reg signed [31:0] reg_B2, reg_AC;
    wire mul_overflow ;
    wire mul_start;
    wire signed [31:0] mul_result;
    assign mul_start = (!mul_busy && !mul_done ) &&
                       ((state == B2) ||
                        (state == AC) );
    wire mul_done;
    wire mul_busy;

    mul m1 (    .clk      (clk),
                .reset_n  (reset_n),
                .data_A   (mul_A),
                .data_B   (mul_B),
                .start    (mul_start),
                .result   (mul_result),
                .done     (mul_done),
                .busy     (mul_busy),
                .overflow (mul_overflow) );
    always@(posedge clk or negedge reset_n) begin
        if (!reset_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    always @(*) begin
        case(state)
            IDLE : next_state = start ? B2 : IDLE;
            B2 : next_state = mul_done ? AC : B2;
            AC : next_state = mul_done ? FOUR_AC : AC;
            FOUR_AC : next_state = SUBTRACT;
            SUBTRACT : next_state = DONE;
            DONE : next_state = IDLE;
            default : next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge reset_n) begin
        if((!reset_n) || (state == IDLE && !start)) begin
            busy <= 1'b0;
            done <=1'b0;
            is_negative <= 1'b0;
            is_zero <= 1'b0;
            out <= 32'sb0;
            mul_A <= 32'sb0;
            mul_B <= 32'sb0;
            reg_A <= 32'sb0;
            reg_C <= 32'sb0;
            reg_B2 <= 32'sb0;
            reg_AC <= 32'sb0;

        end
        else if(state == IDLE && start) begin
            mul_A <= B;
            mul_B <= B;
            reg_A <= A;
            reg_C <= C;
            busy <= 1'b1;

        end
        else if(state == B2 && mul_done) begin
            reg_B2 <= mul_result;
            mul_A <= reg_A;
            mul_B <= reg_C;

        end
        else if (state == AC && mul_done) begin
            reg_AC <= mul_result  <<< 2;

        end
        else if (state == SUBTRACT) begin
            out <= (reg_B2 - reg_AC);
        end
        else if (state == DONE) begin
            done <= 1'b1;
            busy <= 1'b0;
            is_zero <= (out == 32'b0);
            is_negative <= out[31];
        end
    end

    

endmodule
