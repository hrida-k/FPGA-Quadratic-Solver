module norm(input clk,
            input reset_n,
            input signed [31:0] data,
            input start,
            output reg signed [31:0] normalized_data,
            output reg signed [5:0] exponent,
            output reg busy,
            output reg done);

    reg state, next_state;
    localparam IDLE         = 1'b0,
               NORMALIZE    = 1'b1;

    
    reg [31:0] magnitude;

    reg signed [5:0] k_reg;


    always @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            state <= IDLE;
        
        else
            state <= next_state;
    end

    always @(*) begin
        case(state)
            IDLE: next_state = start ? NORMALIZE : IDLE;

            NORMALIZE: next_state = ((magnitude < 32'h0004_0000 && magnitude >= 32'h0001_0000) && (~k_reg[0]))  || (magnitude == 0)?  IDLE :  NORMALIZE;

            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            busy <= 1'b0;
            done <= 1'b0;
            k_reg <= 6'sb0;

        end
        else if (state == IDLE && start) begin
            magnitude <= data[31] ? (~data + 1'b1) : data;
            k_reg <= 6'sb0;
            normalized_data <= 32'sb0;
            exponent <= 6'b0;
            busy <= 1'b1;
            done <= 1'b0;
        end
        else begin
            done <= (state == NORMALIZE && next_state == IDLE) ? 1'b1 : 1'b0;
            
            busy <= (next_state != IDLE);
           
            
            if (state == NORMALIZE && next_state == NORMALIZE) begin
                if(magnitude >= 32'h0004_0000) begin
                    magnitude <= magnitude >>> 1;
                    k_reg <= k_reg + 1;
                end
                else if (magnitude < 32'h0001_0000) begin
                    magnitude <= magnitude <<< 1;
                    k_reg <= k_reg - 1;
                end
                else if (k_reg[0] == 1'b1) begin
                    magnitude <= magnitude >>> 1;
                    k_reg <= k_reg + 1;
                end
            end

            else if (next_state == IDLE && state == NORMALIZE) begin
                if (magnitude == 32'b0) begin
                    done <= 1'b1;
                end
                normalized_data <= magnitude;
                exponent <= k_reg;
            end
        end  
    end
endmodule