module dnes.cpu.cpu;

import core.thread;
import std.format;

import dnes.cpu.dma;
import dnes.cpu.instructions;
import dnes.cpu.memory;

/**
 * The NES CPU - controls instruction execution, main memory, etc.
 */
class CPU
{
public:
    /**
     * Constructor
     */
    this(bool logging)
    {
        memory = new Memory();
        cycles = 0;
        _dma = false;
        _interrupt = Interrupt.NONE;

        // Initial register states
        pc = 0xC000;
        sp = 0xFD;
        acc = 0;
        x = 0;
        y = 0;
        status = 0x24;

        _instructionsFiber = new Fiber(() => executeInstructions(this, logging));
        _dmaFiber = new Fiber(() => oamdma(this));
    }

    /**
     * Ticks the CPU along one clock cycle, performing whatever action carries
     * on from the last clock cycle
     */
    void tick()
    {
        cycles++;

        if (!_dma)
            _instructionsFiber.call();
        else
            _dmaFiber.call();
    }

    /**
     * Check if the given flag is set
     *
     * Params:
     *     flag = The flag to test for
     *
     * Returns: True if the flag is set, false if not
     */
    nothrow @safe @nogc bool getFlag(Flag flag) const
    {
        return (status & flag) > 0;
    }

    /**
     * Sets the given flag on or off
     *
     * Params:
     *     flag = The flag to set
     *     b    = The position to set it to
     */
    nothrow @safe @nogc void setFlag(Flag flag, bool b)
    {
        if (b)
            status |= flag;
        else
            status &= ~flag;
    }

    /**
     * Returns: The CPU state as a string
     */
    override @safe string toString() const
    {
        return format(
            "A:%02X X:%02X Y:%02X P:%02X SP:%02X",
            acc, x, y, status, sp
        );
    }

    /**
     * Returns: The currently queued interrupt
     */
    @property nothrow @safe @nogc Interrupt interrupt() const
    {
        return _interrupt;
    }

    /**
     * Property to set an interrupt - will be ignored if a higher priority
     * interrupt is already queued
     */
    @property nothrow @safe @nogc void interrupt(Interrupt i)
    {
        if (i > _interrupt)
            _interrupt = i;
    }

    /**
     * Returns: If the CPU is performing DMA or not
     */
    @property nothrow @safe @nogc bool dma() const
    {
        return _dma;
    }

    /**
     * Property to set the DMA field - setting it to true enables DMA to begin
     * on the next CPU tick
     */
    @property nothrow @nogc void dma(bool value)
    {
        _dma = value;
        if (_dma)
            _dmaFiber.reset();
    }

    /// The CPU memory
    Memory memory;

    /// The number of clock cycles executed
    uint cycles;

    /// Registers
    ushort pc;     /// Program counter
    ubyte  sp;     /// Stack pointer
    ubyte  acc;    /// Accumulator
    ubyte  x;      /// Index register X
    ubyte  y;      /// Index register Y
    ubyte  status; /// Processor status flags

    /// Enumeration of each CPU flag
    enum Flag
    {
        C = 1 << 0, // Carry
        Z = 1 << 1, // Zero
        I = 1 << 2, // Interrupt disable
        D = 1 << 3, // Decimal mode
        B = 1 << 4, // Break
        V = 1 << 6, // Overflow
        N = 1 << 7, // Negative
    }

    /// Enumeration of interrupt types
    enum Interrupt
    {
        NONE  = 0,
        BRK   = 1,
        IRQ   = 2,
        NMI   = 3,
        RESET = 4,
    }

private:
    Fiber _instructionsFiber;
    Fiber _dmaFiber;
    bool _dma;
    Interrupt _interrupt;
}

// Export a global variable
CPU cpu = null;