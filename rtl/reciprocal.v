`include "fp_mul.v"

module reciprocal(
                    input clk,
                    input reset_n,
                    input negative_sign,
                    input signed [31:0] m,
                    input signed [5:0] E,
                    input start,
                    output reg done,
                    output reg busy,
                    output reg overflow,
                    output reg signed [31:0] result );

    localparam IDLE = 3'b000,
            LOAD = 3'b001,
            MUL1 = 3'b010,
            MUL2 = 3'b011,
            UPDATE_Y = 3'b100,
            RESCALE = 3'b101,
            DONE = 3'b110;

    wire mul_done;
    wire mul_busy;
    wire mul_overflow;
    wire mul_start;

    wire signed [31:0] mul_A;
    wire signed [31:0] mul_B;
    wire signed [31:0] mul_result;

    reg [2:0] state;
    reg [2:0] next_state;

    reg [2:0] iteration_count;
    reg signed [31:0] y;
    reg signed [63:0] scaled_temp;

    wire signed [63:0] final_scaled;

    assign final_scaled = negative_sign ? -scaled_temp : scaled_temp;

    assign mul_start = (next_state == MUL1) || (next_state == MUL2);

    assign mul_A = (next_state == MUL1) ? m :
                (next_state == MUL2) ? (32'sd131072 - mul_result) : 32'sd0;

    assign mul_B = y;

    mul m1 (
            .clk(clk),
            .reset_n(reset_n),
            .data_A(mul_A),
            .data_B(mul_B),
            .start(mul_start),
            .result(mul_result),
            .done(mul_done),
            .busy(mul_busy),
            .overflow(mul_overflow) );

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    always @(*) begin
        case (state)
            IDLE: begin
                next_state = start ? LOAD : IDLE;
            end

            LOAD: begin
                next_state = MUL1;
            end

            MUL1: begin
                if (mul_done)
                    next_state = MUL2;
                else
                    next_state = MUL1;
            end

            MUL2: begin
                if (!mul_done)
                    next_state = MUL2;
                else if (iteration_count == 2)
                    next_state = RESCALE;
                else
                    next_state = UPDATE_Y;
            end

            UPDATE_Y: begin
                next_state = MUL1;
            end

            RESCALE: begin
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
            y <= 32'sd0;
            iteration_count <= 2'd0;
            scaled_temp <= 64'sd0;
            busy <= 1'b0;
            done <= 1'b0;
            overflow <= 1'b0;
            result <= 32'sd0;
        end
        else if (state == DONE) begin
            overflow <= (final_scaled[63:32] != {32{final_scaled[31]}});
            result <= final_scaled[31:0];
            busy <= 1'b0;
            done <= 1'b1;
        end
        else if (next_state == IDLE) begin
            busy <= 1'b0;
            done <= 1'b0;
        end
        else if ((next_state == LOAD) && start) begin
            y <= ({m[17], m[15]} == 2'b00) ? 32'd52429 :
                ({m[17], m[15]} == 2'b01) ? 32'd37747 :
                ({m[17], m[16]} == 2'b10) ? 32'd26214 :
                ({m[17], m[16]} == 2'b11) ? 32'd18724 :
                32'sd0;

            iteration_count <= 2'd0;
            busy <= 1'b1;
            done <= 1'b0;
            overflow <= 1'b0;
        end
        else if ((state == MUL1) && mul_done) begin
        end
        else if ((state == MUL2) && mul_done) begin
            iteration_count <= iteration_count + 1'b1;

            if (iteration_count != 6)
                y <= mul_result;
        end
        else if (state == RESCALE) begin
            if (E > 0) begin
                scaled_temp <= {{32{y[31]}}, y} >>> E;
            end
            else if (E < 0) begin
                scaled_temp <= {{32{y[31]}}, y} <<< (-E);
            end
            else begin
                scaled_temp <= {{32{y[31]}}, y};
            end
        end
    end
endmodule