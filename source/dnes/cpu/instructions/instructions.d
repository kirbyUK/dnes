module dnes.cpu.instructions.instructions;

import core.thread;
import std.stdio;

import dnes.cpu.cpu;
import dnes.cpu.instructions.instruction;
import dnes.ppu.ppu;
import dnes.util;

/**
 * Execute a single instruction per loop interation indefinitely, yielding
 * whenever a clock cycle elapses
 */
void executeInstructions(CPU cpu, bool logging)
{
    while (true)
    {
        // Get the opcode
        const auto instruction = new Instruction(cpu.memory.get(cpu.pc));
        if (logging)
            logInstruction(instruction);
        Fiber.yield();

        // Calculate the effective address
        ushort address = 0;
        callFiber(new Fiber((){ address = calculateAddress(instruction); }));

        // Get the value the instruction will work with
        ubyte value = 0;
        callFiber(new Fiber((){ value = addressValue(instruction, address); }));

        // Execute the instruction
        callFiber(new Fiber(() => executeInstruction(instruction, address, value)));

        // Check for any queued interrupts and perform the necessary actions
        // if there are any. The BRK and IRQ interrupts are maskable, so do not
        // execute if the interrupt disable flag is set.
        if ((cpu.interrupt != CPU.Interrupt.NONE) &&
            (!(cpu.interrupt <= CPU.Interrupt.IRQ && cpu.getFlag(CPU.Flag.I))))
        {
            callFiber(new Fiber(&handleInterrupt));
            cpu.resetInterrupt();
        }
    }
}

/**
 * Log the current instruction being executed, along with the CPU and PPU
 * states
 *
 * Params:
 *     instruction = The instruction to log
 */
void logInstruction(const Instruction instruction)
{
    writefln(
        "%04X %02X %02X %02X  %s %40s %s",
        cpu.pc,
        cpu.memory[cpu.pc],
        cpu.memory[cpu.pc + 1],
        cpu.memory[cpu.pc + 2],
        instruction.opcode,
        cpu.toString(),
        ppu.toString()
    );
}

/**
 * Determine if an updated address crosses a page boundary
 *
 * Params:
 *     oldAddress = The previous address
 *     newAddress = The newer address
 *
 * Returns: True if moving from the old to new address crosses a page boundary
 */
pure nothrow @safe @nogc bool crossesPageBoundary(ushort oldAddress, ushort newAddress)
{
    return (oldAddress & 0xff00) != (newAddress & 0xff00);
}

/**
 * Calculate the effective address the instruction is targeting, taking into
 * account the addressing mode.
 * Timings: <http://nesdev.com/6502_cpu.txt>
 *
 * Params:
 *     instruction = The instruction to calculate with
 *
 * Returns: The calculated address to target
 */
ushort calculateAddress(const Instruction instruction)
{
    // Read the additional byte(s) needed for the instruction
    const auto oldPc = cpu.pc;
    ubyte lo = 0;
    ubyte hi = 0;
    cpu.pc += 1;
    switch (instruction.addressing)
    {
        case Addressing.IMP:
            // Accumulator and implied addressing read the next instruction
            // byte, then throw it away (without incrementing the PC)
            Fiber.yield();
            break;
        case Addressing.ZRP:
        case Addressing.ZRX:
        case Addressing.ZRY:
        case Addressing.IDX:
        case Addressing.IDY:
        case Addressing.IMM:
        case Addressing.REL:
            lo = cpu.memory.get(cpu.pc);
            cpu.pc += 1;
            Fiber.yield();
            break;
        case Addressing.ABS:
        case Addressing.INX:
        case Addressing.INY:
        case Addressing.IND:
            lo = cpu.memory.get(cpu.pc);
            cpu.pc += 1;
            Fiber.yield();
            hi = cpu.memory.get(cpu.pc);
            cpu.pc += 1;
            Fiber.yield();
            break;
        
        default: break;
    }

    // From the instruction bytes and addressing mode, calculate the effective
    // address that will be used by the instruction
    switch (instruction.addressing)
    {
        case Addressing.ABS:
            return concat(hi, lo);
        case Addressing.ZRP:
            return concat(0, lo);
        case Addressing.INX:
            return (wrap!ushort(concat(hi, lo) + cpu.x));
        case Addressing.INY:
            return (wrap!ushort(concat(hi, lo) + cpu.y));
        case Addressing.ZRX:
            const auto addrLo = cpu.memory.get(concat(0, lo));
            Fiber.yield();
            return wrap!ushort(addrLo + cpu.x);
        case Addressing.ZRY:
            const auto addrLo = cpu.memory.get(concat(0, lo));
            Fiber.yield();
            return wrap!ushort(addrLo + cpu.y);
        case Addressing.IND:
            // In indirect addressing, the address to use is stored in $HHLL.
            // However, there is a bug where indirect addressing does not
            // increment the high part of the address if the lower wraps around
            // <http://forums.nesdev.com/viewtopic.php?t=5388>
            const auto addrLo = cpu.memory.get(concat(hi, lo));
            Fiber.yield();
            const auto addrHi = cpu.memory.get(wrap!ushort(concat(hi, wrap!ubyte(lo + 1))));
            Fiber.yield();
            return concat(addrHi, addrLo);
        case Addressing.IDY:
            auto addrLo = cpu.memory.get(concat(0, lo));
            Fiber.yield();
            const auto addrHi = cpu.memory.get(wrap!ubyte(lo + 1));
            addrLo += cpu.y;
            Fiber.yield();
            return concat(addrHi, addrLo);
        case Addressing.IDX:
            auto pointer = cpu.memory.get(concat(0, lo));
            pointer += cpu.x;
            Fiber.yield();
            const auto addrLo = cpu.memory.get(pointer);
            Fiber.yield();
            const auto addrHi = cpu.memory.get(wrap!ushort(pointer + 1));
            Fiber.yield();
            return concat(addrHi, addrLo);
        case Addressing.REL:
            return wrap!ushort(oldPc + cast(byte)(lo));
        case Addressing.IMM:
            return concat(0, lo);
        default: return 0;
    }
}

/**
 * Get the value for the instruction to operate on
 *
 * Params:
 *     instruction = The instruction being executed
 *     address     = The effective address of the instruction
 *
 * Returns: The value from the address of the instruction, or the instruction
 *          itself
 */
ubyte addressValue(const Instruction instruction, ushort address)
{
    // An additional cycle is needed to read the value from the address.
    // However, this is not needed by write-only instructions, and for
    // instructions with immediate addressing, the value is in the
    // instruction (and therefore already fetched) Likewise, instructions
    // with implied addressing do not need to access any further memory.
    ubyte value = 0;
    if ((instruction.addressing != Addressing.IMM) &&
        (instruction.addressing != Addressing.IMP) &&
        (instruction.addressing != Addressing.REL))
    {
        switch (instruction.opcode)
        {
            case Opcode.STA:
            case Opcode.STX:
            case Opcode.STY:
                break;
            default:
                value = cpu.memory.get(address);
                Fiber.yield();
                break;
        }
    }
    else if (instruction.addressing == Addressing.IMM)
        value = address & 0x00ff;

    // Check for page boundary crossings, and add an extra cycle if so:
    if ((instruction.addressing == Addressing.INX) ||
        (instruction.addressing == Addressing.INY) ||
        (instruction.addressing == Addressing.IDY))
    {
        // Page boundary crossings in this context are only applicable to
        // read instructions - ones that do not affect memory
        switch (instruction.opcode)
        {
            case Opcode.ADC:
            case Opcode.AND:
            case Opcode.BIT:
            case Opcode.CMP:
            case Opcode.EOR:
            case Opcode.LDA:
            case Opcode.LDX:
            case Opcode.LDY:
            case Opcode.ORA:
            case Opcode.SBC:
                if (crossesPageBoundary(cpu.pc, address))
                    Fiber.yield();
                break;
            default: break;
        }
    }

    return value;
}

/**
 * Executes the given instruction, using the calculated effective address and
 * the value stored in that address, if any
 *
 * Params:
 *     instruction = The instruction to execute
 *     address     = The effective address
 *     value       = The value pulled from the address or instruction
 */
void executeInstruction(const Instruction instruction, ushort address, ubyte value)
{
    const auto accumulatorPrevious = cpu.acc;
    switch (instruction.opcode)
    {
        case Opcode.ADC:  // Add with carry
            const ushort sum = cpu.acc + value + (cpu.getFlag(CPU.Flag.C) ? 1 : 0);
            cpu.acc = sum & 0x00ff;
            cpu.setFlag(CPU.Flag.C, sum > 0xff);
            cpu.setFlag(CPU.Flag.Z, cpu.acc == 0);
            cpu.setFlag(CPU.Flag.V, ((~(accumulatorPrevious ^ value)) & (accumulatorPrevious ^ cpu.acc) & 0x80) > 0);
            cpu.setFlag(CPU.Flag.N, (cpu.acc & 0x80) > 0);
            break;

        case Opcode.AND:  // Logical AND
            cpu.acc &= value;
            cpu.setFlag(CPU.Flag.Z, cpu.acc == 0);
            cpu.setFlag(CPU.Flag.N, (cpu.acc & 0x80) > 0);
            break;

        case Opcode.ASL:  // Arithmetic shift left
            const auto previousValueSignBit = (value & 0x80) >> 7;
            value <<= 1;
            writeInstruction(instruction, address, value);
            cpu.setFlag(CPU.Flag.C, previousValueSignBit > 0);
            cpu.setFlag(CPU.Flag.Z, value == 0);
            cpu.setFlag(CPU.Flag.N, (value & 0x80) > 0);
            break;

        case Opcode.BCC:  // Branch if Carry Clear
            branchInstruction(address, !cpu.getFlag(CPU.Flag.C));
            break;

        case Opcode.BCS:  // Branch if Carry Set
            branchInstruction(address, cpu.getFlag(CPU.Flag.C));
            break;

        case Opcode.BEQ:  // Branch if Equal
            branchInstruction(address, cpu.getFlag(CPU.Flag.Z));
            break;

        case Opcode.BIT:  // Bit Test
            const ubyte test = cpu.acc & value;
            cpu.setFlag(CPU.Flag.Z, cpu.acc == 0);
            cpu.setFlag(CPU.Flag.V, (value & 0x40) > 0);
            cpu.setFlag(CPU.Flag.N, (value & 0x80) > 0);
            break;

        case Opcode.BMI:  // Branch if Minus
            branchInstruction(address, cpu.getFlag(CPU.Flag.N));
            break;

        case Opcode.BNE:  // Branch if Not Equal
            branchInstruction(address, !cpu.getFlag(CPU.Flag.Z));
            break;

        case Opcode.BPL:  // Branch if Positive
            branchInstruction(address, !cpu.getFlag(CPU.Flag.N));
            break;

        case Opcode.BRK:  // Force Interrupt
            cpu.interrupt = CPU.Interrupt.BRK;
            break;

        case Opcode.BVC:  // Branch if Overflow Clear
            branchInstruction(address, !cpu.getFlag(CPU.Flag.V));
            break;

        case Opcode.BVS:  // Branch if Overflow Set
            branchInstruction(address, cpu.getFlag(CPU.Flag.V));
            break;

        case Opcode.CLC:  // Clear Carry Flag
            cpu.setFlag(CPU.Flag.C, false);
            break;

        case Opcode.CLD:  // Clear Decimal Mode
            cpu.setFlag(CPU.Flag.D, false);
            break;

        case Opcode.CLI:  // Clear Interrupt Disable
            cpu.setFlag(CPU.Flag.I, false);
            break;

        case Opcode.CLV:  // Clear Overflow Flag
            cpu.setFlag(CPU.Flag.V, false);
            break;

        case Opcode.CMP:  // Compare
            const auto test = cpu.acc - value;
            cpu.setFlag(CPU.Flag.C, cpu.acc >= value);
            cpu.setFlag(CPU.Flag.Z, test == 0);
            cpu.setFlag(CPU.Flag.N, (test & 0x80) > 0);
            break;

        case Opcode.CPX:  // Compare X Register
            const auto test = cpu.x - value;
            cpu.setFlag(CPU.Flag.C, cpu.x >= value);
            cpu.setFlag(CPU.Flag.Z, test == 0);
            cpu.setFlag(CPU.Flag.N, (test & 0x80) > 0);
            break;

        case Opcode.CPY:  // Compare Y Register
            const auto test = cpu.y - value;
            cpu.setFlag(CPU.Flag.C, cpu.y >= value);
            cpu.setFlag(CPU.Flag.Z, test == 0);
            cpu.setFlag(CPU.Flag.N, (test & 0x80) > 0);
            break;

        case Opcode.DEC:  // Decrement Memory
            const ubyte newValue = cast(ubyte)(value - 1);
            Fiber.yield();
            cpu.memory.set(address, newValue);
            Fiber.yield();
            cpu.setFlag(CPU.Flag.Z, newValue == 0);
            cpu.setFlag(CPU.Flag.N, (newValue & 0x80) > 0);
            break;

        case Opcode.DEX:  // Decrement X Register
            cpu.x--;
            cpu.setFlag(CPU.Flag.Z, cpu.x == 0);
            cpu.setFlag(CPU.Flag.N, (cpu.x & 0x80) > 0);
            break;

        case Opcode.DEY:  // Decrement Y Register
            cpu.y--;
            cpu.setFlag(CPU.Flag.Z, cpu.y == 0);
            cpu.setFlag(CPU.Flag.N, (cpu.y & 0x80) > 0);
            break;

        case Opcode.EOR:  // Exclusive OR
            cpu.acc ^= value;
            cpu.setFlag(CPU.Flag.Z, cpu.acc == 0);
            cpu.setFlag(CPU.Flag.N, (cpu.acc & 0x80) > 0);
            break;

        case Opcode.INC:  // Increment Memory    
            const auto prevValue = cpu.memory.get(address);
            const auto newValue = wrap!ubyte(prevValue + 1);
            Fiber.yield();
            cpu.memory.set(address, newValue);
            Fiber.yield();
            cpu.setFlag(CPU.Flag.Z, newValue == 0);
            cpu.setFlag(CPU.Flag.N, (newValue & 0x80) > 0);
            break;

        case Opcode.INX:  // Increment X Register
            cpu.x++;
            cpu.setFlag(CPU.Flag.Z, cpu.x == 0);
            cpu.setFlag(CPU.Flag.N, (cpu.x & 0x80) > 0);
            break;

        case Opcode.INY:  // Increment Y Register
            cpu.y++;
            cpu.setFlag(CPU.Flag.Z, cpu.y == 0);
            cpu.setFlag(CPU.Flag.N, (cpu.y & 0x80) > 0);
            break;   

        case Opcode.JMP:  // Jump
            cpu.pc = address;
            break;

        case Opcode.JSR:  // Jump to Subroutine
            Fiber.yield();
            const auto pc = wrap!ushort(cpu.pc - 1);
            const auto pcHi = (pc & 0xff00) >> 8;
            cpu.memory.push(pcHi);
            Fiber.yield();
            const auto pcLo = pc & 0x00ff;
            cpu.memory.push(pcLo);
            Fiber.yield();
            cpu.pc = address;
            break;

        case Opcode.LDA:  // Load Accumulator
            cpu.acc = value;
            cpu.setFlag(CPU.Flag.Z, cpu.acc == 0);
            cpu.setFlag(CPU.Flag.N, (cpu.acc & 0x80) > 0);
            break;

        case Opcode.LDX:  // Load X Register
            cpu.x = value;
            cpu.setFlag(CPU.Flag.Z, cpu.x == 0);
            cpu.setFlag(CPU.Flag.N, (cpu.x & 0x80) > 0);
            break;

        case Opcode.LDY:  // Load Y Register
            cpu.y = value;
            cpu.setFlag(CPU.Flag.Z, cpu.y == 0);
            cpu.setFlag(CPU.Flag.N, (cpu.y & 0x80) > 0);
            break;

        case Opcode.LSR:  // Arithmetic shift right
            const auto previousValueLowBit = value & 0x01;
            value >>= 1;
            writeInstruction(instruction, address, value);
            cpu.setFlag(CPU.Flag.C, previousValueLowBit > 0);
            cpu.setFlag(CPU.Flag.Z, value == 0);
            cpu.setFlag(CPU.Flag.N, (value & 0x80) > 0);
            break;

        case Opcode.ORA:  // Logical Inclusive OR
            cpu.acc |= value;
            cpu.setFlag(CPU.Flag.Z, cpu.acc == 0);
            cpu.setFlag(CPU.Flag.N, (cpu.acc & 0x80) > 0);
            break;

        case Opcode.PHA:  // Push Accumulator
            cpu.memory.push(cpu.acc);
            Fiber.yield();
            break;

        case Opcode.PHP:  // Push Processor Status
            cpu.memory.push(cpu.status | 0x30);
            Fiber.yield();
            break;

        case Opcode.PLA:  // Pull Accumulator
            cpu.acc = cpu.memory.pop();
            Fiber.yield();
            Fiber.yield();
            cpu.setFlag(CPU.Flag.Z, cpu.acc == 0);
            cpu.setFlag(CPU.Flag.B, false);
            cpu.setFlag(CPU.Flag.N, (cpu.acc & 0x80) > 0);
            break;

        case Opcode.PLP:  // Pull Processor Status
            cpu.status = cpu.memory.pop();
            Fiber.yield();
            Fiber.yield();
            cpu.setFlag(CPU.Flag.B, false);
            break;

        case Opcode.ROL:  // Rotate Left
            const auto oldHighBit = (value & 0x80) >> 7;
            const auto rotated = ((value << 1) | cpu.getFlag(CPU.Flag.C) ? 1 : 0);
            writeInstruction(instruction, address, value);
            cpu.setFlag(CPU.Flag.C, oldHighBit > 0);
            cpu.setFlag(CPU.Flag.Z, rotated == 0);
            cpu.setFlag(CPU.Flag.N, (rotated & 0x80) > 0);
            break;

        case Opcode.ROR:  // Rotate Right
            const auto oldLowBit = value & 0x01;
            const auto rotated = ((value >> 1) | cpu.getFlag(CPU.Flag.C) ? 0x80 : 0);
            writeInstruction(instruction, address, value);
            cpu.setFlag(CPU.Flag.C, oldLowBit > 0);
            cpu.setFlag(CPU.Flag.Z, rotated == 0);
            cpu.setFlag(CPU.Flag.N, (rotated & 0x80) > 0);
            break;

        case Opcode.RTI:  // Return from Interrupt
            cpu.status = cpu.memory.pop();
            Fiber.yield();
            const auto pcLo = cpu.memory.pop();
            Fiber.yield();
            const auto pcHi = cpu.memory.pop();
            Fiber.yield();
            cpu.pc = concat(pcHi, pcLo);
            break;

        case Opcode.RTS:  // Return from Subroutine
            Fiber.yield();
            const auto pcLo = cpu.memory.pop();
            Fiber.yield();
            const auto pcHi = cpu.memory.pop();
            Fiber.yield();
            cpu.pc = concat(pcHi, pcLo);
            Fiber.yield();
            cpu.pc += 1;
            break;

        case Opcode.SBC:  // Subtract with Carry
            const ushort sum = cpu.acc + ~value + (cpu.getFlag(CPU.Flag.C) ? 1 : 0);
            cpu.acc = sum & 0x00ff;
            cpu.setFlag(CPU.Flag.C, sum > 0xff);
            cpu.setFlag(CPU.Flag.Z, cpu.acc == 0);
            cpu.setFlag(CPU.Flag.V, ((~(accumulatorPrevious ^ value)) & (accumulatorPrevious ^ cpu.acc) & 0x80) > 0);
            cpu.setFlag(CPU.Flag.N, (cpu.acc & 0x80) > 0);
            break;

        case Opcode.SEC:  // Set Carry Flag
            cpu.setFlag(CPU.Flag.C, true);
            break;

        case Opcode.SED:  // Set Decimal Flag
            cpu.setFlag(CPU.Flag.D, true);
            break;

        case Opcode.SEI:  // Set Interrupt Disable
            cpu.setFlag(CPU.Flag.I, true);
            break;

        case Opcode.STA:  // Store Accumulator
            cpu.memory.set(address, cpu.acc);
            Fiber.yield();
            break;

        case Opcode.STX:  // Store X Register
            cpu.memory.set(address, cpu.x);
            Fiber.yield();
            break;

        case Opcode.STY:  // Store Y Register
            cpu.memory.set(address, cpu.y);
            Fiber.yield();
            break;

        case Opcode.TAX:  // Transfer Accumulator to X
            cpu.x = cpu.acc;
            cpu.setFlag(CPU.Flag.Z, cpu.x == 0);
            cpu.setFlag(CPU.Flag.N, (cpu.x & 0x80) > 0);
            break;

        case Opcode.TAY:  // Transfer Accumulator to Y
            cpu.y = cpu.acc;
            cpu.setFlag(CPU.Flag.Z, cpu.y == 0);
            cpu.setFlag(CPU.Flag.N, (cpu.y & 0x80) > 0);
            break;

        case Opcode.TSX:  // Transfer Stack Pointer to X
            cpu.x = cpu.sp;
            cpu.setFlag(CPU.Flag.Z, cpu.x == 0);
            cpu.setFlag(CPU.Flag.N, (cpu.x & 0x80) > 0);
            break;

        case Opcode.TXA:  // Transfer X to Accumulator
            cpu.acc = cpu.x;
            cpu.setFlag(CPU.Flag.Z, cpu.acc == 0);
            cpu.setFlag(CPU.Flag.N, (cpu.acc & 0x80) > 0);
            break;

        case Opcode.TXS:  // Transfer X to Stack Pointer
            cpu.sp = cpu.x;
            break;

        case Opcode.TYA:  // Transfer Y to Accumulator
            cpu.acc = cpu.y;
            cpu.setFlag(CPU.Flag.Z, cpu.acc == 0);
            cpu.setFlag(CPU.Flag.N, (cpu.acc & 0x80) > 0);
            break;       

        default: break;
    }
}

/**
 * Called if there is a queued interrupt - performs the necessary memory reads
 * and writes and sets the PC to the interrupt vector.
 * <https://wiki.nesdev.com/w/index.php/CPU_interrupts>
 */
void handleInterrupt()
{
    const auto isBRK = (cpu.interrupt == CPU.Interrupt.BRK);

    // The first two ticks read the opcode and the next instruction
    // byte from memory. BRK interrupts increment the PC each time,
    // others do not. These values are not used, so we don't actually
    // need to read the memory
    cpu.pc += (isBRK) ? 1 : 0;
    Fiber.yield();
    cpu.pc += (isBRK) ? 1 : 0;
    Fiber.yield();

    // The next two cycles push the PC to the stack. In a RESET, the
    // writes are not actually performed, but sp is decremented as if
    // they were
    if (cpu.interrupt != CPU.Interrupt.RESET)
    {
        cpu.memory.push((cpu.pc & 0xff00) >> 8);
        Fiber.yield();
        cpu.memory.push(cpu.pc & 0x00ff);
        Fiber.yield();
    }
    else
    {
        cpu.sp--;
        Fiber.yield();
    }

    // Next the CPU flags are pushed to the stack. The B flag is set to
    // true if this is a BRK, false if not. Again, in a RESET the
    // write is fake
    cpu.setFlag(CPU.Flag.B, isBRK);
    if (cpu.interrupt != CPU.Interrupt.RESET)
    {
        cpu.memory.push(cpu.sp);
        Fiber.yield();
    }
    else
    {
        cpu.sp--;
        Fiber.yield();
    }

    // The final two cycles fetch the new address from the interrupt
    // vector and set it to the PC
    const ushort[CPU.Interrupt] interruptVectors = [
        CPU.Interrupt.NMI:   0xfffa,
        CPU.Interrupt.RESET: 0xfffc,
        CPU.Interrupt.IRQ:   0xfffe,
        CPU.Interrupt.BRK:   0xfffe,
    ];
    const auto interruptVector = interruptVectors[cpu.interrupt];
    cpu.pc = 0x0000 | cpu.memory.get(interruptVector);
    cpu.setFlag(CPU.Flag.I, true);
    Fiber.yield();
    cpu.pc |= cpu.memory.get(wrap!ushort((interruptVector + 1))) << 8;
    Fiber.yield();
}

/**
 * Common code for all instructions that could write to a memory address or
 * the accumulator, depending on the addressing mode
 *
 * Params:
 *     instruction = The instruction being executed
 *     address     = The address determined from the instruction
 *     value       = The value to write
 */
void writeInstruction(const Instruction instruction, ushort address, ubyte value)
{
    if (instruction.addressing != Addressing.IMP)
    {
        cpu.memory.set(address, value);
        Fiber.yield();
    }
    else
        cpu.acc = value;
}

/**
 * Common code for all branching instructions
 *
 * Params:
 *     addr      = The effective address of the instruction
 *     condition = The condition that will cause the branch if true
 */
void branchInstruction(ushort addr, bool condition)
{
    if (condition)
    {
        const auto branchedAddress = wrap!ushort(addr + 2);
        if (crossesPageBoundary(cpu.pc, branchedAddress))
            Fiber.yield();
        cpu.pc = branchedAddress;
        Fiber.yield();
    }
}