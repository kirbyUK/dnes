module dnes.ppu.ppu;

import core.thread;
import std.stdio;

import dnes.ppu.memory;
import dnes.ppu.rendering;

/**
 * The NES PPU - controls picture rendering
 */
class PPU
{
public:
	/**
	 * Constructor
	 */
	nothrow this()
	{
		memory = new Memory();
		cycles = 0;
		scanline = 0;
		_fiber = new Fiber(() => ppuRendering(this));
	}

	/**
	 * Ticks the PPU along one clock cycle, performing whatever action carries
	 * on from the last clock cycle
	 */
	void tick()
	{
		if (++cycles > 340)
		{
			cycles = 0;
			if (++scanline > 261)
				scanline = 0;
		}
		writefln("ppu: %d", cycles);
		_fiber.call();
	}

	/// The PPU memory
	Memory memory;

	/// The number of clock cycles executed in this scanline. Resets after 340
	uint cycles;

	/// The current scanline being drawn. Resets after 261
	uint scanline;

	/// PPU internal registers
	ushort v; /// Current VRAM address
	ushort t; /// Temporary VRAM address
	ubyte  x; /// Fine X scroll
	bool   w; /// First or second write toggle

private:
	Fiber _fiber;
}

// Export a global variable
PPU ppu = null;