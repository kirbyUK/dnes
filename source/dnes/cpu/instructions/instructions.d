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
        cpu.pc += 1;
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
            (!(cpu.interrupt <= CPU.Interrupt.IRQ) && (cpu.getFlag(CPU.Flag.I))))
        {
            callFiber(new Fiber(&handleInterrupt));
        }
    }
}

/**
 * Log the current instruction being executed, along with the CPU and PPU
 * states
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
    ubyte lo = 0;
    ubyte hi = 0;
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
        case Addressing.ABS: return concat(hi, lo);
        case Addressing.ZRP: return concat(0, lo);
        case Addressing.INX: return (wrap!ushort(concat(hi, lo) + cpu.x));
        case Addressing.INY: return (wrap!ushort(concat(hi, lo) + cpu.y));
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
        case Addressing.REL: return wrap!ushort(cpu.pc + cast(byte)(lo));
        case Addressing.IMM: return concat(0, lo);
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
        (instruction.addressing != Addressing.IMP))
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
            cpu.acc += cpu.getFlag(CPU.Flag.C) ? value + 1 : value;
            cpu.setFlag(CPU.Flag.C, cpu.acc < (accumulatorPrevious + cpu.getFlag(CPU.Flag.C) ? 1 : 0));
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
            if (instruction.addressing != Addressing.IMP)
            {
                cpu.memory.set(address, value);
                Fiber.yield();
            }
            else
                cpu.acc = value;
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
            branchInstruction(address, !cpu.getFlag(CPU.Flag.Z));
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
            cpu.setFlag(CPU.Flag.C, (cpu.acc >= test));
            cpu.setFlag(CPU.Flag.Z, (test == 0));
            cpu.setFlag(CPU.Flag.N, ((test & 0x80) > 0));
            break;

        case Opcode.CPX:  // Compare X Register
            const auto test = cpu.x - value;
            cpu.setFlag(CPU.Flag.C, (cpu.x >= test));
            cpu.setFlag(CPU.Flag.Z, (test == 0));
            cpu.setFlag(CPU.Flag.N, ((test & 0x80) > 0));
            break;

        case Opcode.CPY:  // Compare Y Register
            const auto test = cpu.y - value;
            cpu.setFlag(CPU.Flag.C, (cpu.y >= test));
            cpu.setFlag(CPU.Flag.Z, (test == 0));
            cpu.setFlag(CPU.Flag.N, ((test & 0x80) > 0));
            break;

        case Opcode.JMP:  // Jump
            cpu.pc = address;
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
    const ushort interruptVector = 0xfffe;
    cpu.pc = (cpu.memory.get(interruptVector) << 8) & 0xff00;
    cpu.setFlag(CPU.Flag.I, true);
    Fiber.yield();
    cpu.pc |= cpu.memory.get(interruptVector + 1);
    Fiber.yield();
}

/**
 * Common code for all branching instructions
 *
 * Params:
 *     addr      = The effective address of the instruction
 *     condition = The condition that will cause the branch if true
 */
pragma(inline, true)
void branchInstruction(ushort addr, bool condition)
{
    if (condition)
    {
        // cross page boundary check
        cpu.pc = wrap!ushort(addr + 2);
        Fiber.yield();
    }
}