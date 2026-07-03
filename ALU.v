`include "defs.vh"
module ALU (
    input [31:0] src1, 
    input [31:0] src2, 
    input [15:0] imm, 
    input [4:0] shift_amount,
    input [5:0] opcode, 
    input [5:0] func, 
    input [7:0] pc,
    input [25:0] jump_target, 
    input [4:0] rt,
    output [31:0] dest, 
    output dest_valid,
    output reg [7:0] branch_target, 
    output reg branch_taken
);
    reg [31:0] result;
    reg result_valid;
    assign dest = result;
    assign dest_valid = result_valid;
    always @(*) begin
        result = 32'b0; result_valid = 1'b0; branch_taken = 1'b0;
        branch_target = 8'b0;
        case (opcode)
            `OP_REG: begin
                case (func)
                    `FUNC_SLL: begin 
                        result = src2 << shift_amount; 
                        result_valid = 1'b1; 
                    end
                    `FUNC_SRL: begin 
                        result = src2 >> shift_amount; 
                        result_valid = 1'b1; 
                    end
                    `FUNC_SRA: begin 
                        result = $signed(src2) >>> shift_amount; 
                        result_valid = 1'b1; 
                    end
                    `FUNC_SLLV: begin 
                        result = src2 << src1[4:0]; 
                        result_valid = 1'b1; 
                    end
                    `FUNC_SRLV: begin 
                        result = src2 >> src1[4:0]; 
                        result_valid = 1'b1; 
                    end
                    `FUNC_SRAV: begin 
                        result = $signed(src2) >>> src1[4:0]; 
                        result_valid = 1'b1; 
                    end
                    `FUNC_ADD: begin 
                        result = src1 + src2; 
                        result_valid = 1'b1; 
                    end
                    `FUNC_SUB: begin 
                        result = src1 - src2; 
                        result_valid = 1'b1; 
                    end
                    `FUNC_AND: begin 
                        result = src1 & src2; 
                        result_valid = 1'b1; 
                    end
                    `FUNC_OR:  begin 
                        result = src1 | src2; 
                        result_valid = 1'b1; 
                    end
                    `FUNC_XOR: begin 
                        result = src1 ^ src2; 
                        result_valid = 1'b1; 
                    end
                    `FUNC_NOR: begin 
                        result = ~(src1 | src2); 
                        result_valid = 1'b1; 
                    end
                    `FUNC_JR:  begin 
                        branch_taken = 1'b1; 
                        branch_target = src1[7:0]; 
                    end
                    `FUNC_JALR: begin 
                        branch_taken = 1'b1; 
                        branch_target = src1[7:0]; 
                        result = {24'b0, pc + 8'd1}; 
                        result_valid = 1'b1; 
                    end
                    `FUNC_SLT: begin 
                        result = ($signed(src1) < $signed(src2)) ? 32'd1 : 32'd0; 
                        result_valid = 1'b1; 
                    end
                    `FUNC_SLTU: begin 
                        result = (src1 < src2) ? 32'd1 : 32'd0; 
                        result_valid = 1'b1; 
                    end
                endcase
            end
            `OP_ADDI: begin 
                result = src1 + {{16{imm[15]}}, imm}; 
                result_valid = 1'b1; 
            end
            `OP_ANDI: begin 
                result = src1 & {16'b0, imm}; 
                result_valid = 1'b1; 
            end
            `OP_ORI:  begin 
                result = src1 | {16'b0, imm}; 
                result_valid = 1'b1; 
            end
            `OP_XORI: begin 
                result = src1 ^ {16'b0, imm}; 
                result_valid = 1'b1; 
            end
            `OP_SLTI: begin 
                result = ($signed(src1) < $signed({{16{imm[15]}}, imm})) ? 32'd1 : 32'd0; 
                result_valid = 1'b1; 
            end
            `OP_SLTIU: begin 
                result = (src1 < {{16{imm[15]}}, imm}) ? 32'd1 : 32'd0; 
                result_valid = 1'b1; 
            end
            `OP_LUI:  begin 
                result = {imm, 16'b0}; 
                result_valid = 1'b1; 
            end
            `OP_LW, `OP_LB, `OP_LBU, `OP_LH, `OP_LHU: begin 
                result = src1 + {{16{imm[15]}}, imm}; 
                result_valid = 1'b1; 
            end
            `OP_SW, `OP_SB, `OP_SH: begin 
                result = src1 + {{16{imm[15]}}, imm}; 
                result_valid = 1'b0; 
            end
            `OP_BLTZ_BGEZ: begin
                branch_target = pc + imm[7:0] + 1;
                if (rt == 1) branch_taken = ($signed(src1) >= 0) ? 1'b1 : 1'b0;
                else branch_taken = ($signed(src1) < 0) ? 1'b1 : 1'b0;
            end
            `OP_BEQ: begin 
                branch_target = pc + imm[7:0] + 1; 
                branch_taken = (src1 == src2) ? 1'b1 : 1'b0; 
            end
            `OP_BNE: begin 
                branch_target = pc + imm[7:0] + 1; 
                branch_taken = (src1 != src2) ? 1'b1 : 1'b0; 
            end
            `OP_BLEZ: begin 
                branch_target = pc + imm[7:0] + 1; 
                branch_taken = ($signed(src1) <= 0) ? 1'b1 : 1'b0; 
            end
            `OP_BGTZ: begin 
                branch_target = pc + imm[7:0] + 1; 
                branch_taken = ($signed(src1) > 0) ? 1'b1 : 1'b0; 
            end
            `OP_J: begin 
                branch_taken = 1'b1; 
                branch_target = jump_target[7:0]; 
            end
            `OP_JAL: begin 
                branch_taken = 1'b1; 
                branch_target = jump_target[7:0]; 
                result = {24'b0, pc + 8'd1}; 
                result_valid = 1'b1; 
            end
        endcase
    end
endmodule