module dnes.cpu.instructions.instructions;

import core.thread;
import std.stdio;

import dnes.cpu.cpu;
import dnes.cpu.instructions.instruction;
import dnes.util;

/**
 * Execute a single instruction per loop interation indefinitely, yielding
 * whenever a clock cycle elapses
 */
void executeInstructions(CPU cpu)
{
    while (true)
    {
        // Get the opcode
        const auto instruction = new Instruction(cpu.memory.get(cpu.pc));
        cpu.pc += 1;
        Fiber.yield();

        // Calculate the address - this is wrapped in a Fiber, as the
        // addressing mode may need to make further memory accesses.
        // Timings: <http://nesdev.com/6502_cpu.txt>
        ushort address = 0;
        auto f = new Fiber((){ address = calculateAddress(cpu, instruction); });
        while (f.state != Fiber.State.TERM)
        {
            f.call();
            Fiber.yield();
        }

        // An additional cycle is needed to read the value from the address.
        // However, this is not needed by write-only instructions, and for
        // instructions with immediate addressing, the value is in the
        // instruction (and therefore already fetched), so this cycle is not
        // needed. Likewise, instructions with implied addressing do not need
        // to access any further memory.
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

        // Execute the instruction
        const auto accumulatorPrevious = cpu.acc;
        CPU.Flag[] flagsToUpdate = [];
        switch (instruction.opcode)
        {
            case Opcode.ADC:  // Add with carry
                cpu.acc += cpu.getFlag(CPU.Flag.C) ? value + 1 : value;
                flagsToUpdate = [ CPU.Flag.C, CPU.Flag.Z, CPU.Flag.V, CPU.Flag.N ];
                break;

            case Opcode.AND:  // Logical AND
                cpu.acc &= value;
                flagsToUpdate = [ CPU.Flag.Z, CPU.Flag.N ];
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
                // something something flags
                break;

            default: break;
        }

        // Set the CPU flags
        foreach (flag; flagsToUpdate)
        {
            switch (flag)
            {
                case CPU.Flag.C:
                    cpu.setFlag(flag, cpu.acc < (accumulatorPrevious + cpu.getFlag(CPU.Flag.C) ? 1 : 0));
                    break;
                case CPU.Flag.Z:
                    cpu.setFlag(flag, cpu.acc == 0);
                    break;
                case CPU.Flag.V:
                    cpu.setFlag(flag, ((~(accumulatorPrevious ^ value)) & (accumulatorPrevious ^ cpu.acc) & 0x80) > 0);
                    break;
                case CPU.Flag.N:
                    cpu.setFlag(flag, (cpu.acc & 0x80) > 0);
                    break;
                default: break;
            }
        }

        // Check for any queued interrupts and update the program counter for
        // the next instruction if so
    }
}

/**
 * Calculate the effective address the instruction is targeting, taking into
 * account the addressing mode
 *
 * Params:
 *     cpu         = The CPU object
 *     instruction = The instruction to calculate with
 *
 * Returns: The calculated address to target
 */
ushort calculateAddress(CPU cpu, const Instruction instruction)
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