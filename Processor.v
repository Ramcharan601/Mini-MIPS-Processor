`include "defs.vh"
`include "RegisterFile.v"
`include "ALU.v"

module Processor(
    input clk, 
    input reset, 
    input [31:0] ins, 
    input copied_io_regs, 
    input [31:0] input_value, 
    input input_value_valid,
    input [31:0] load_value,
    output reg [7:0] pc,
    output [31:0] io_reg1, 
    output [31:0] io_reg2,
    output [31:0] io_reg3, 
    output [31:0] io_reg4,
    output reg io_stall,
    output halt,
    output [31:0] io_regs_index_out,
    output reg waiting_for_input,  
    output [7:0] data_addr, 
    output data_addr_valid, 
    output [1:0] data_mem_command,
    output [31:0] store_value
);

    wire [5:0] opcode = ins[31:26];
    wire [4:0] src1_addr = ins[25:21];
    wire [4:0] src2_addr = ins[20:16];
    wire [4:0] dest_addr = (opcode == `OP_JAL) ? 5'd31 : ((opcode == `OP_REG) ? ins[15:11] : ins[20:16]);
    wire [4:0] shift_amount = ins[10:6];
    wire [5:0] func = ins[5:0];
    wire [15:0] imm = ins[15:0];
    wire [25:0] jump_target = ins[25:0];
    wire [4:0] rt = ins[20:16];

    wire [31:0] src1, src2, dest_data;
    wire dest_data_valid, alu_branch_taken;
    wire [7:0] alu_branch_target;

    reg [31:0] io_reg [0:3];
    reg [2:0] io_reg_index;
    reg fetched;
    reg [2:0] state;

    reg [5:0] reg_opcode, reg_func;
    reg [31:0] reg_src1, reg_src2;
    reg [4:0] reg_shift_amount, reg_dest_addr, reg_rt;
    reg [15:0] reg_imm;
    reg [25:0] reg_jump_target;

    reg reg_write_enable;
    reg [4:0] reg_write_addr;
    reg [31:0] reg_write_data;
    reg reg_branch_taken;
    reg [7:0] reg_branch_target;

    assign io_reg1 = io_reg[0];
    assign io_reg2 = io_reg[1];
    assign io_reg3 = io_reg[2];
    assign io_reg4 = io_reg[3];
    assign io_regs_index_out = {29'b0, io_reg_index};

    RegisterFile rf (clk, reg_write_enable, src1_addr, src2_addr, reg_write_addr, reg_write_data, src1, src2);

    ALU alu (
        .src1(reg_src1), .src2(reg_src2), .imm(reg_imm), .shift_amount(reg_shift_amount),
        .opcode(reg_opcode), .func(reg_func), .pc(pc), .jump_target(reg_jump_target), .rt(reg_rt),
        .dest(dest_data), .dest_valid(dest_data_valid), .branch_target(alu_branch_target), .branch_taken(alu_branch_taken)
    );

    wire is_load = (reg_opcode == `OP_LW || reg_opcode == `OP_LB || reg_opcode == `OP_LBU || reg_opcode == `OP_LH || reg_opcode == `OP_LHU);
    wire is_store = (reg_opcode == `OP_SW || reg_opcode == `OP_SB || reg_opcode == `OP_SH);

    assign data_addr = dest_data[9:2]; // Convert byte to word address
    assign data_addr_valid = (state == 3'b001) && (is_load || is_store);
    assign data_mem_command = is_load ? `READ_COMMAND : (reg_opcode == `OP_SW) ? `WRITE_COMMAND : (is_store) ? `SUBWORD_WRITE_COMMAND : `READ_COMMAND;

    // Load Formatting (Big Endian)
    wire [1:0] byte_off = dest_data[1:0];
    reg [31:0] f_load;
    always @(*) begin
        f_load = load_value;
        if (reg_opcode == `OP_LB) begin
            case(byte_off)
                2'b00: f_load = {{24{load_value[31]}}, load_value[31:24]};
                2'b01: f_load = {{24{load_value[23]}}, load_value[23:16]};
                2'b10: f_load = {{24{load_value[15]}}, load_value[15:8]};
                2'b11: f_load = {{24{load_value[7]}}, load_value[7:0]};
            endcase
        end else if (reg_opcode == `OP_LBU) begin
            case(byte_off)
                2'b00: f_load = {24'b0, load_value[31:24]};
                2'b01: f_load = {24'b0, load_value[23:16]};
                2'b10: f_load = {24'b0, load_value[15:8]};
                2'b11: f_load = {24'b0, load_value[7:0]};
            endcase
        end else if (reg_opcode == `OP_LH) begin
            case(byte_off[1])
                1'b0: f_load = {{16{load_value[31]}}, load_value[31:16]};
                1'b1: f_load = {{16{load_value[15]}}, load_value[15:0]};
            endcase
        end else if (reg_opcode == `OP_LHU) begin
            case(byte_off[1])
                1'b0: f_load = {16'b0, load_value[31:16]};
                1'b1: f_load = {16'b0, load_value[15:0]};
            endcase
        end
    end

    // Store Formatting (Big Endian)
    reg [31:0] f_store;
    always @(*) begin
        f_store = reg_src2;
        if (reg_opcode == `OP_SB) begin
            case(byte_off)
                2'b00: f_store = {reg_src2[7:0], load_value[23:0]};
                2'b01: f_store = {load_value[31:24], reg_src2[7:0], load_value[15:0]};
                2'b10: f_store = {load_value[31:16], reg_src2[7:0], load_value[7:0]};
                2'b11: f_store = {load_value[31:8], reg_src2[7:0]};
            endcase
        end else if (reg_opcode == `OP_SH) begin
            case(byte_off[1])
                1'b0: f_store = {reg_src2[15:0], load_value[15:0]};
                1'b1: f_store = {load_value[31:16], reg_src2[15:0]};
            endcase
        end
    end
    assign store_value = f_store;

    assign halt = (reset | ~fetched) ? 1'b0 : (((opcode == `OP_REG) && (func == `FUNC_SYSCALL) && (src1 == `SYS_exit)) ? 1'b1 : 1'b0);

    always @(posedge clk) begin
        if (reset) begin
            pc <= 8'b0; io_reg_index <= 3'b0; fetched <= 1'b0; state <= 3'b000; io_stall <= 1'b0; waiting_for_input <= 1'b0;
            reg_write_enable <= 1'b0; reg_write_addr <= 5'b0; reg_write_data <= 32'b0; reg_branch_taken <= 1'b0; reg_branch_target <= 8'b0;
            io_reg[0] <= 32'b0; io_reg[1] <= 32'b0; io_reg[2] <= 32'b0; io_reg[3] <= 32'b0;
        end
        else begin
            if (state == 3'b000) begin
                reg_opcode <= opcode; reg_func <= func; reg_src1 <= src1; reg_src2 <= src2;
                reg_shift_amount <= shift_amount; reg_dest_addr <= dest_addr; reg_imm <= imm;
                reg_jump_target <= jump_target; reg_rt <= rt;
                fetched <= 1'b1;
                if (!halt) state <= 3'b001;
            end
            else if (state == 3'b001) begin
                reg_branch_taken <= alu_branch_taken;
                reg_branch_target <= alu_branch_target;

                if ((reg_opcode == `OP_REG) && (reg_func == `FUNC_SYSCALL) && (reg_src1 == `SYS_read)) begin
                    waiting_for_input <= 1'b1;
                    state <= 3'b101;
                end
                else if ((reg_opcode == `OP_REG) && (reg_func == `FUNC_SYSCALL) && (reg_src1 == `SYS_write)) begin
                    if (io_reg_index == 3'd4) begin io_stall <= 1'b1; state <= 3'b011; end
                    else begin io_reg[io_reg_index[1:0]] <= reg_src2; io_reg_index <= io_reg_index + 1; state <= 3'b010; end
                end
                else if (is_load) begin
                    reg_write_enable <= 1'b1; reg_write_addr <= reg_dest_addr; reg_write_data <= f_load; state <= 3'b010;
                end
                else if (is_store) begin
                    state <= 3'b010;
                end
                else begin
                    reg_write_enable <= dest_data_valid; reg_write_addr <= reg_dest_addr; reg_write_data <= dest_data; state <= 3'b010;
                end
            end
            else if (state == 3'b010) begin
                if (!halt) pc <= reg_branch_taken ? reg_branch_target : (pc + 1);
                reg_write_enable <= 1'b0; state <= 3'b000;
            end
            else if (state == 3'b011) begin
                if (copied_io_regs) begin io_stall <= 1'b0; io_reg_index <= 3'b0; state <= 3'b100; end
            end
            else if (state == 3'b100) begin
                if (!copied_io_regs) begin io_reg[0] <= reg_src2; io_reg_index <= 3'b001; state <= 3'b010; end
            end
            else if (state == 3'b101) begin
                if (input_value_valid) begin waiting_for_input <= 1'b0; reg_write_data <= input_value; state <= 3'b110; end
            end
            else if (state == 3'b110) begin
                if (!input_value_valid) begin reg_write_enable <= 1'b1; reg_write_addr <= reg_dest_addr; state <= 3'b010; end
            end
        end
    end
endmodule