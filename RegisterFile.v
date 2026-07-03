module RegisterFile(
    input clk,
    input write_enable, 
    input [4:0] read_addr1, 
    input [4:0] read_addr2,
    input [4:0] write_addr, 
    input [31:0] write_data,
    output [31:0] read_data1, 
    output [31:0] read_data2    
);
    reg [31:0] regfile [0:31];
    // Enforce that reading register $0 always returns 32 bits of 0
    assign read_data1 = (read_addr1 == 5'b0) ? 32'b0 : regfile[read_addr1];
    assign read_data2 = (read_addr2 == 5'b0) ? 32'b0 : regfile[read_addr2];

    always @ (negedge clk) begin
        if (write_enable && (write_addr != 0)) begin
            // Filled in write to regfile[write_addr]
            regfile[write_addr] <= write_data;
        end
    end
endmodule

// Format for Reg (32 bits): opcode(6) | register source [rs] (5) | register target [rt] (5) | rd (5) | shift amount [shift amt] (5) | function (6)
// Format for Imm (32 bits): opcode(6) | register source [rs] (5) | register dest [rd] (5) | Immediate (16)