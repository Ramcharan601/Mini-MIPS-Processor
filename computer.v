`include "defs.vh"
`include "Memory.v"
`include "Processor.v"

module Computer(
    input reset, 
    input [7:0] ins_addr, 
    input [31:0] ins,
    input clk, 
    input done_storing, 
    input copied_io_regs,
    input [31:0] input_value,
    input input_value_valid,
    output reg done,
    output [31:0] out_reg1, 
    output [31:0] out_reg2,
    output [31:0] out_reg3, 
    output [31:0] out_reg4,
    output [31:0] total_cycles, 
    output [31:0] proc_cycles,
    output io_stall,  
    output [31:0] io_regs_index_out,
    output waiting_for_input
);

    wire [7:0] pc, data_addr;
    wire data_addr_valid;
    wire [1:0] data_mem_command;
    wire [31:0] store_value, mem_word_out;
    reg [31:0] counter_total, counter_proc;
    wire halt;

    wire is_data = (data_addr_valid);
    wire [7:0] mem_addr = done_storing ? (is_data ? data_addr : pc) : ins_addr;
    wire [1:0] mem_cmd = done_storing ? (is_data ? data_mem_command : `READ_COMMAND) : `WRITE_COMMAND;
    wire [31:0] mem_in = done_storing ? store_value : ins;

    Memory mem(~reset, clk, mem_cmd, mem_addr, mem_in, mem_word_out);

    Processor proc(
        .clk(clk), 
        .halt(halt), 
        .reset(~done_storing), 
        .pc(pc), 
        .ins(mem_word_out), 
        .io_reg1(out_reg1), 
        .io_reg2(out_reg2), 
        .io_reg3(out_reg3), 
        .io_reg4(out_reg4),
        .io_stall(io_stall), 
        .copied_io_regs(copied_io_regs), 
        .io_regs_index_out(io_regs_index_out), 
        .waiting_for_input(waiting_for_input), 
        .input_value(input_value), 
        .input_value_valid(input_value_valid),
        .data_addr(data_addr), 
        .data_addr_valid(data_addr_valid), 
        .data_mem_command(data_mem_command), 
        .store_value(store_value), 
        .load_value(mem_word_out)
    );

    assign total_cycles = counter_total;
    assign proc_cycles = counter_proc;

    always @(posedge clk) begin
        if (reset) begin counter_total <= 32'b0; counter_proc <= 32'b0; done <= 1'b0; end
        else begin
            done <= halt; counter_total <= counter_total + 1;
            if (done_storing && !halt && !io_stall && !waiting_for_input) counter_proc <= counter_proc + 1;
        end
    end
endmodule