module dnes.cpu.cpu;

import core.thread;
import std.stdio;

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
		_fiber = new Fiber(() => executeInstructions(this));

		// Initial register states
		pc = 0xC000;
		sp = 0xFD;
		acc = 0;
		x = 0;
		y = 0;
		status = 0x24;
	}

	/**
	 * Ticks the CPU along one clock cycle, performing whatever action carries
	 * on from the last clock cycle
	 */
	void tick()
	{
		cycles++;
		writefln("cpu: %d", cycles);
		_fiber.call();
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
	Fiber _fiber;
}

// Export a global variable
CPU cpu = null;