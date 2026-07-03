# Mini-MIPS-Processor

A custom 32-bit multi-cycle MIPS processor built from scratch in Verilog. This project was developed as part of the CS220 (Computer Organization and Architecture) course at IIT Kanpur under the supervision of Prof. Mainak Chaudhuri.

This project implements a **3-Cycle FSM** datapath (Fetch → Execute → Writeback), moving away from a traditional 5-stage pipeline to avoid control-hazard complexities. It features Register Transfer Level (RTL) control, big-endian sub-word memory access, and a custom I/O handshake mechanism for syscall-driven communication. Four additional FSM states handle `SYS_write` output stalling and `SYS_read` input handshaking, bringing the total state count to **7**.

---

## About My Code

This repository contains the raw Verilog source files that make up the complete processor architecture. Here is a detailed breakdown of each module and its specific role:

- `computer.v` **(Top-Level Architecture)** — The main integration module that brings the processor and memory together. It acts as the system wrapper, handling program loading, memory arbitration, clocking, stalling, and tracking execution cycles (`total_cycles`, `proc_cycles`).

- `Processor.v` **(The Core CPU)** — Houses the 3-cycle control FSM (Fetch, Execute, Write-Back) for standard instruction execution, extended with four additional I/O handling states for syscall stalling and keyboard input handshakes. It manages the main datapath and handles big-endian formatting for partial word loads/stores.

- `ALU.v` **(Arithmetic Logic Unit)** — An entirely combinational block that executes all data manipulation. It handles arithmetic (`add`, `sub`), logic (`and`, `or`, `xor`), shifts (`sll`, `srl`, `sra`), and computes memory addresses and branch targets dynamically in a single cycle.

- `Memory.v` **(Big-Endian Controller)** — The main memory module. It supports full-word reads/writes and precise byte (`lb`/`sb`) and half-word (`lh`/`sh`) memory operations using a specialized `SUBWORD_WRITE_COMMAND` system.

- `RegisterFile.v` **(32×32 Register Array)** — The CPU's working memory, providing two asynchronous reads and one synchronous write per cycle. It features a hardwired `$0` register to prevent uninitialized cascading. Writes are clocked on the **negative edge** to ensure data is available at the start of the next positive-edge cycle.

- `defs.vh` **(Global Definitions)** — A header file defining all MIPS opcodes, function codes, memory commands, and syscall numbers (`SYS_exit`, `SYS_read`, `SYS_write`), making the RTL code highly readable.

---

## Instruction Encoding

Each MIPS instruction is 32 bits long. The processor decodes these standard formats combinationally to extract the appropriate fields.

- **R-Format (Register):** Used for instructions with only register operands (`add`, `sub`, `and`, `or`, `xor`, `nor`, `sll`, `srl`, `sra`, `sllv`, `srlv`, `srav`, `syscall`, `slt`, `sltu`, `jr`, `jalr`).
  - Encoding: `opcode (6) | rs (5) | rt (5) | rd (5) | sh_amt (5) | function (6)`

- **I-Format (Immediate):** Used for instructions with an immediate operand (`addi`, `andi`, `ori`, `xori`, `lw`, `sw`, `lb`, `sb`, `lh`, `sh`, `lbu`, `lhu`, `lui`, `beq`, `bne`, `bltz`, `bgez`, `blez`, `bgtz`, `slti`, `sltiu`).
  - Encoding: `opcode (6) | rs (5) | rt (5) | immediate (16)`

- **J-Format (Jump):** Used for unconditional jumps (`j`, `jal`).
  - Encoding: `opcode (6) | jump_target (26)`

---

## Execution Flow & Architecture

To avoid critical path timing failures, the processor operates as a **3-Cycle FSM** for all standard instructions — a new instruction is fetched only after the previous one has fully completed. Four additional states extend the FSM to handle I/O syscalls, bringing the total to **7 states**.

**State 0 — Fetch & Decode:** The instruction is fetched from `Memory.v` using the PC. The instruction fields (`opcode`, `func`, `shift_amount`, `imm`, `jump_target`, `dest_addr`) are decoded and latched into pipeline registers. Operands (`src1`, `src2`) are asynchronously read from the `RegisterFile.v` in the same cycle.

**State 1 — Execute:** `ALU.v` performs the required arithmetic, logical operation, or branch/jump target computation. If a memory instruction is decoded, the effective byte address is calculated here. Syscall instructions (`syscall`) and their type are dispatched here — `SYS_write` writes to the next I/O register slot, `SYS_read` transitions to the input-wait state, and `SYS_exit` asserts the `halt` signal.

**State 2 — Writeback & PC Update:** The computed result from the ALU, or the data loaded from memory, is written back to the destination register. Branch conditions update the Program Counter (PC) accordingly. The processor then returns to State 0 to fetch the next instruction.

**States 3 & 4 — I/O Output Stall:** When all four `io_reg` slots are filled by consecutive `SYS_write` calls, `io_stall` is asserted and the processor freezes in State 3. It waits for the host environment to acknowledge copying the registers via the `copied_io_regs` flag. State 4 is a brief handshake step to resume cleanly before writing the next output value and returning to State 2.

**States 5 & 6 — Input Handshake:** A `SYS_read` syscall asserts `waiting_for_input` and stalls the FSM in State 5. The host environment responds by placing a 32-bit value on `input_value` and asserting `input_value_valid`. State 6 latches the input data and waits for `input_value_valid` to deassert before performing the register writeback and returning to State 2.

---

## Big-Endian Sub-Word Memory Access

The memory is organized as 256 words of 32 bits each, using a **big-endian** byte ordering where the most significant byte lives at the lowest byte address. To support byte and half-word operations, custom extraction and alignment logic was built into the datapath:

- **Store Operations (`sb`, `sh`):** For sub-word stores, the processor reads the existing 32-bit word from memory using a `SUBWORD_WRITE_COMMAND`. The `Processor.v` then dynamically masks and splices in the new sub-word from the register file based on the 2-bit byte offset, and writes the modified full word back.

- **Load Operations (`lb`, `lbu`, `lh`, `lhu`):** The processor extracts the correct byte or half-word from the fetched 32-bit `load_value`. It automatically applies sign-extension for signed loads (`lb`, `lh`) or zero-extension for unsigned loads (`lbu`, `lhu`) before writing to the destination register.

---

## Key Architectural Features

- **Hardware I/O Stalling:** A circular I/O register array (`io_reg[0:3]`) tracks output values. The processor generates an `io_stall` signal upon the fifth consecutive `SYS_write` syscall, safely freezing execution until the environment acknowledges copying the registers via a `copied_io_regs` flag.

- **Keyboard Input Handshake:** A custom syscall (`SYS_read`, 1003) pauses the FSM and asserts `waiting_for_input`. The environment responds by supplying a 32-bit value alongside an `input_value_valid` flag, smoothly resuming execution.

- **Combinational ALU:** The Arithmetic Logic Unit is entirely combinational — executing shifts, arithmetic, and branch/jump target computations in zero additional clock cycles.

- **Negedge Register Writes:** The `RegisterFile.v` performs writes on the negative clock edge. This ensures that a value written in the Writeback state is stably available at the register file output by the time the next positive edge triggers a new Fetch.

- **Cycle Counters:** The `Computer` module tracks two independent counters: `total_cycles` counts every clock tick since reset, while `proc_cycles` increments only when the processor is actively executing (i.e., `done_storing` is asserted and neither `io_stall` nor `waiting_for_input` is active).