module dnes.cpu.instructions;

import core.thread;
import std.stdio;

import dnes.cpu;

/// Enumeration of each CPU flag
enum Flags
{
    C = 1 << 0, // Carry
    Z = 1 << 1, // Zero
    I = 1 << 2, // Interrupt disable
    D = 1 << 3, // Decimal mode
    B = 1 << 4, // Break
    V = 1 << 5, // Overflow
    N = 1 << 6, // Negative
}

/**
 * Execute a single instruction per loop interation indefinitely, yielding
 * whenever a clock cycle elapses
 */
void executeInstructions(CPU cpu)
{
    while (true)
    {
        // Get the opcode
        const auto opcode = cpu.memory.get8(cpu.pc);
        writefln("got opcode: %02X", opcode);
        Fiber.yield();
    }
}