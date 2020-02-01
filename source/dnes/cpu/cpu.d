module dnes.cpu.cpu;

import core.thread;
import std.stdio;

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
	this()
	{
		memory = new Memory();
		cycles = 0;
		_dma = false;

		// Initial register states
		pc = 0xC000;
		sp = 0xFD;
		acc = 0;
		x = 0;
		y = 0;
		status = 0x24;

		_instructionsFiber = new Fiber(() => executeInstructions(this));
		_dmaFiber = new Fiber(() => oamdma(this));
	}

	/**
	 * Ticks the CPU along one clock cycle, performing whatever action carries
	 * on from the last clock cycle
	 */
	void tick()
	{
		cycles++;
		writefln("cpu: %d", cycles);

		if (!_dma)
			_instructionsFiber.call();
		else
			_dmaFiber.call();
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

private:
	Fiber _instructionsFiber;
	Fiber _dmaFiber;
	bool _dma;
}

// Export a global variable
CPU cpu = null;