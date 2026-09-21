`include "fp_mul.v"
 
module sqrt_module(
                    input clk,
                    input reset_n,
                    input signed [31:0] m,
                    input signed [5:0] E,
                    input start,
                    output reg done,
                    output reg busy,
                    output reg overflow,
                    output reg signed [31:0] result);

    localparam IDLE=4'b0000,
            LOAD=4'b0001,
            MUL1=4'b0010,
            MUL2=4'b0011,
            MUL3=4'b0100,
            UPDATE_Y=4'b0101,
            SQRT_MUL=4'b0110,
            RESCALE=4'b0111,
            DONE=4'b1000;

    reg [3:0] state,next_state;
    reg [2:0] iteration_count;

    reg signed [31:0] y;
    reg signed [31:0] y_squared;
    reg signed [31:0] my_squared;
    reg signed [31:0] correction;
    reg signed [31:0] sqrt_m;
    reg signed [63:0] scaled_temp;

    wire mul_done;
    wire mul_busy;
    wire mul_overflow;
    wire mul_start;
    wire signed [31:0] mul_A;
    wire signed [31:0] mul_B;
    wire signed [31:0] mul_result;

    assign mul_start =
        !mul_busy && !mul_done &&
        ((state==MUL1) ||
            (state==MUL2) ||
            (state==MUL3) ||
            (state==SQRT_MUL));

    assign mul_A =
        (state==MUL1) ? y :
        (state==MUL2) ? m :
        (state==MUL3) ? correction :
        (state==SQRT_MUL) ? m :
        32'sd0;

    assign mul_B =
        (state==MUL1) ? y :
        (state==MUL2) ? y_squared :
        (state==MUL3) ? y :
        (state==SQRT_MUL) ? y :
        32'sd0;

    mul m1(
            .clk(clk),
            .reset_n(reset_n),
            .data_A(mul_A),
            .data_B(mul_B),
            .start(mul_start),
            .result(mul_result),
            .done(mul_done),
            .busy(mul_busy),
            .overflow(mul_overflow));


    always @(posedge clk or negedge reset_n) begin
        if(!reset_n)
            state<=IDLE;
        else
            state<=next_state;
    end

    always @(*) begin
        next_state=state;

        case(state)
            IDLE:
                next_state=start ? LOAD : IDLE;

            LOAD:
                next_state=MUL1;

            MUL1:
                next_state=mul_done ? MUL2 : MUL1;

            MUL2:
                next_state=mul_done ? MUL3 : MUL2;

            MUL3:
                next_state=mul_done ? UPDATE_Y : MUL3;

            UPDATE_Y:
                next_state=(iteration_count==3'd4) ? SQRT_MUL : MUL1;

            SQRT_MUL:
                next_state=mul_done ? RESCALE : SQRT_MUL;

            RESCALE:
                next_state=DONE;

            DONE:
                next_state=IDLE;

            default:
                next_state=IDLE;
        endcase
    end

    always @(posedge clk or negedge reset_n) begin
        if(!reset_n) begin
            y<=32'sd0;
            y_squared<=32'sd0;
            my_squared<=32'sd0;
            correction<=32'sd0;
            sqrt_m<=32'sd0;
            scaled_temp<=64'sd0;
            iteration_count<=3'd0;
            busy<=1'b0;
            done<=1'b0;
            overflow<=1'b0;
            result<=32'sd0;
        end
        else begin
            done<=1'b0;

            if(state==LOAD) begin
                if(m<32'sh0001_8000)
                    y<=32'sd65536;
                else if(m<32'sh0002_0000)
                    y<=32'sd57983;
                else if(m<32'sh0003_0000)
                    y<=32'sd46341;
                else
                    y<=32'sd37837;

                y_squared<=32'sd0;
                my_squared<=32'sd0;
                correction<=32'sd0;
                sqrt_m<=32'sd0;
                scaled_temp<=64'sd0;
                iteration_count<=3'd0;

                busy<=1'b1;
                overflow<=1'b0;
            end

            else if(state==MUL1 && mul_done) begin
                y_squared<=mul_result;
            end

            else if(state==MUL2 && mul_done) begin
                my_squared<=mul_result;
                correction<=32'sd98304-(mul_result>>>1);
            end

            else if(state==MUL3 && mul_done) begin
                y<=mul_result;
                iteration_count<=iteration_count+3'd1;
            end

            else if(state==SQRT_MUL && mul_done) begin
                sqrt_m<=mul_result;
            end

            else if(state==RESCALE) begin
                if(E>0)
                    scaled_temp<={{32{sqrt_m[31]}},sqrt_m} <<< (E>>>1);
                else if(E<0)
                    scaled_temp<={{32{sqrt_m[31]}},sqrt_m} >>> ((-E)>>>1);
                else
                    scaled_temp<={{32{sqrt_m[31]}},sqrt_m};
            end

            else if(state==DONE) begin
                overflow<=(scaled_temp[63:32]!={32{scaled_temp[31]}});
                result<=scaled_temp[31:0];
                busy<=1'b0;
                done<=1'b1;
            end

            else if(state==IDLE) begin
                busy<=1'b0;
            end
        end
    end
endmodule