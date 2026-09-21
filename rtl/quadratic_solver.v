`include "fp_mul.v"
`include "discriminant.v"
`include "reciprocal.v"
`include "sq_root.v"
`include "normalization.v"

module engine (
    input wire clk,
    input wire reset_n,
    input wire signed [31:0] A,
    input wire signed [31:0] B,
    input wire signed [31:0] C,
    input wire start,
    output reg signed [31:0] root1_real,
    output reg signed [31:0] root2_real,
    output reg signed [31:0] root1_complex,
    output reg signed [31:0] root2_complex,
    output reg complex,
    output reg busy,
    output reg done,
    output reg invalid
);

    localparam [4:0]
        IDLE           = 5'd0,
        LOAD           = 5'd1,
        START_DISCRIM  = 5'd2,
        WAIT_DISCRIM   = 5'd3,
        START_D_NORM   = 5'd4,
        WAIT_D_NORM    = 5'd5,
        START_SQRT     = 5'd6,
        WAIT_SQRT      = 5'd7,
        START_DEN_NORM = 5'd8,
        WAIT_DEN_NORM  = 5'd9,
        START_RECI     = 5'd10,
        WAIT_RECI      = 5'd11,
        START_MUL1     = 5'd12,
        WAIT_MUL1      = 5'd13,
        START_MUL2     = 5'd14,
        WAIT_MUL2      = 5'd15,
        DONE            = 5'd16;

    reg [4:0] state, next_state;
    reg signed [31:0] A_reg, B_reg, C_reg;
    reg d_negative_reg, d_zero_reg;

    reg D_start;
    wire D_done, D_busy, D_is_negative, D_is_zero;
    wire signed [31:0] D_result;
    reg signed [31:0] test_D_reg;

    reg N_start;
    reg signed [31:0] norm_data;
    wire N_done, N_busy;
    wire signed [31:0] N_m;
    wire signed [5:0] N_exp;

    reg SR_start;
    reg signed [31:0] SR_m;
    reg signed [5:0] SR_exp;
    wire SR_done, SR_busy, SR_overflow;
    wire signed [31:0] SR_result;

    reg R_start;
    reg signed [31:0] R_m;
    reg signed [5:0] R_exp;
    wire R_done, R_busy;
    wire signed [31:0] R_result;
    wire signed [31:0] denominator;
    wire R_negative;

    reg mul_start;
    reg signed [31:0] mul_A, mul_B;
    wire mul_done, mul_busy, mul_overflow;
    wire signed [31:0] mul_result;

    assign denominator = A_reg <<< 1;
    assign R_negative = denominator[31];

    discriminant d1 (
        .clk(clk),
        .reset_n(reset_n),
        .A(A_reg),
        .B(B_reg),
        .C(C_reg),
        .start(D_start),
        .out(D_result),
        .done(D_done),
        .busy(D_busy),
        .is_negative(D_is_negative),
        .is_zero(D_is_zero)
    );

    norm n1 (
        .clk(clk),
        .reset_n(reset_n),
        .data(norm_data),
        .start(N_start),
        .normalized_data(N_m),
        .exponent(N_exp),
        .busy(N_busy),
        .done(N_done)
    );

    sqrt_module s1 (
        .clk(clk),
        .reset_n(reset_n),
        .m(SR_m),
        .E(SR_exp),
        .start(SR_start),
        .result(SR_result),
        .done(SR_done),
        .busy(SR_busy),
        .overflow(SR_overflow)
    );

    reciprocal r1 (
        .clk(clk),
        .reset_n(reset_n),
        .negative_sign(R_negative),
        .m(R_m),
        .E(R_exp),
        .start(R_start),
        .result(R_result),
        .done(R_done),
        .busy(R_busy)
    );

    mul m1 (
        .clk(clk),
        .reset_n(reset_n),
        .data_A(mul_A),
        .data_B(mul_B),
        .start(mul_start),
        .result(mul_result),
        .done(mul_done),
        .busy(mul_busy),
        .overflow(mul_overflow)
    );

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    always @(*) begin
        next_state = state;

        D_start = 1'b0;
        N_start = 1'b0;
        SR_start = 1'b0;
        R_start = 1'b0;
        mul_start = 1'b0;

        norm_data = 32'sd0;
        mul_A = 32'sd0;
        mul_B = 32'sd0;

        case (state)
            IDLE: begin
                if (start)
                    next_state = LOAD;
            end

            LOAD: begin
                if (A_reg == 32'sd0)
                    next_state = DONE;
                else
                    next_state = START_DISCRIM;
            end

            START_DISCRIM: begin
                D_start = 1'b1;
                next_state = WAIT_DISCRIM;
            end

            WAIT_DISCRIM: begin
                if (D_done) begin
                    if (D_is_zero)
                        next_state = START_DEN_NORM;
                    else
                        next_state = START_D_NORM;
                end
            end

            START_D_NORM: begin
                norm_data = test_D_reg;
                N_start = 1'b1;
                next_state = WAIT_D_NORM;
            end

            WAIT_D_NORM: begin
                if (N_done)
                    next_state = START_SQRT;
            end

            START_SQRT: begin
                SR_start = 1'b1;
                next_state = WAIT_SQRT;
            end

            WAIT_SQRT: begin
                if (SR_done)
                    next_state = START_DEN_NORM;
            end

            START_DEN_NORM: begin
                norm_data = denominator;
                N_start = 1'b1;
                next_state = WAIT_DEN_NORM;
            end

            WAIT_DEN_NORM: begin
                if (N_done)
                    next_state = START_RECI;
            end

            START_RECI: begin
                R_start = 1'b1;
                next_state = WAIT_RECI;
            end

            WAIT_RECI: begin
                if (R_done)
                    next_state = START_MUL1;
            end

            START_MUL1: begin
                if (d_zero_reg || d_negative_reg)
                    mul_A = -B_reg;
                else
                    mul_A = (-B_reg) + SR_result;

                mul_B = R_result;
                mul_start = 1'b1;
                next_state = WAIT_MUL1;
            end

            WAIT_MUL1: begin
                if (mul_done) begin
                    if (d_zero_reg)
                        next_state = DONE;
                    else
                        next_state = START_MUL2;
                end
            end

            START_MUL2: begin
                if (d_negative_reg)
                    mul_A = SR_result;
                else
                    mul_A = (-B_reg) - SR_result;

                mul_B = R_result;
                mul_start = 1'b1;
                next_state = WAIT_MUL2;
            end

            WAIT_MUL2: begin
                if (mul_done)
                    next_state = DONE;
            end

            DONE: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            A_reg <= 32'sd0;
            B_reg <= 32'sd0;
            C_reg <= 32'sd0;
            SR_m <= 32'sd0;
            SR_exp <= 6'sd0;
            R_m <= 32'sd0;
            R_exp <= 6'sd0;
            d_negative_reg <= 1'b0;
            d_zero_reg <= 1'b0;
            root1_real <= 32'sd0;
            root2_real <= 32'sd0;
            root1_complex <= 32'sd0;
            root2_complex <= 32'sd0;
            complex <= 1'b0;
            busy <= 1'b0;
            done <= 1'b0;
            invalid <= 1'b0;
        end
        else begin
            done <= 1'b0;

            if (state == IDLE && start) begin
                A_reg <= A;
                B_reg <= B;
                C_reg <= C;
                root1_real <= 32'sd0;
                root2_real <= 32'sd0;
                root1_complex <= 32'sd0;
                root2_complex <= 32'sd0;
                complex <= 1'b0;
                busy <= 1'b1;
                
                 if (A == 32'sd0)
                    invalid <= 1'b1;
                else
                    invalid <= 1'b0;
            end

            else if (state == WAIT_DISCRIM && D_done) begin
                d_negative_reg <= D_is_negative;
                d_zero_reg <= D_is_zero;
                complex <= D_is_negative;
                test_D_reg <= D_result;
            end

            else if (state == WAIT_D_NORM && N_done) begin
                SR_m <= N_m;
                SR_exp <= N_exp;
            end

            else if (state == WAIT_DEN_NORM && N_done) begin
                R_m <= N_m;
                R_exp <= N_exp;
            end

            else if (state == WAIT_MUL1 && mul_done) begin
                if (d_zero_reg) begin
                    root1_real <= mul_result;
                    root2_real <= mul_result;
                end
                else if (d_negative_reg) begin
                    root1_real <= mul_result;
                    root2_real <= mul_result;
                end
                else begin
                    root1_real <= mul_result;
                end
            end

            else if (state == WAIT_MUL2 && mul_done) begin
                if (d_negative_reg) begin
                    root1_complex <= mul_result;
                    root2_complex <= -mul_result;
                end
                else begin
                    root2_real <= mul_result;
                end
            end

            else if (state == DONE) begin
                busy <= 1'b0;
                done <= 1'b1;
            end
        end
    end

endmodule
