module dnes.ppu.ppu;

import core.thread;
import std.format;

import dnes.cpu;
import dnes.ppu.memory;
import dnes.ppu.oam;
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
        scanline = 241;
        _fiber = new Fiber(() => ppuRendering(this));
    }

    /**
     * Ticks the PPU along one clock cycle, performing whatever action carries
     * on from the last clock cycle
     */
    void tick()
    {
        _fiber.call();

        if (++cycles > 340)
        {
            cycles = 0;
            if (++scanline > 261)
                scanline = 0;
        }
    }

    /**
     * Called when an instruction writes to PPUSCROLL ($2005)
     *
     * Params:
     *     value = The value written to PPUSCROLL
     */
    nothrow @safe @nogc void ppuScrollWrite(ubyte value)
    {
        if (!w)
        {
            // First write (w = 0)
            // t: ........ ...HGFED = d: HGFED...
			// x:               CBA = d: .....CBA
			// w:                   = 1
            t = (t & 0xffe0) | (value >> 3);
            x = value & 0x0007;
            w = true;
        }
        else
        {
            // Second write (w = 1)
            // t: .CBA..HG FED..... = d: HGFEDCBA
			// w:                   = 0
            t = (t & 0x8FFF) | ((value & 0x03) << 12);
			t = (t & 0xFCFF) | ((value & 0xC0) << 2);
			t = (t & 0xFF1F) | ((value & 0x38) << 2);
            w = false;
        }
    }

    /**
     * Called when an instruction writes to PPUADDR ($2006)
     *
     * Params:
     *     value = The value written to PPUADDR
     */
    nothrow @safe @nogc void ppuAddrWrite(ubyte value)
    {
        if (!w)
        {
            // First write (w = 0)
            // t: ..FEDCBA ........ = d: ..FEDCBA
            // t: .X...... ........ = 0
            // w:                   = 1
            t = (t & 0xbf00) | ((value & 0x3f) << 8);
            w = true;
        }
        else
        {
            // t: ....... HGFEDCBA = d: HGFEDCBA
            // v                   = t
            // w:                  = 0
            t = (t & 0xff00) | value;
            v = t;
            w = false;
        }
    }

    /**
     * Returns: The VRAM increment amount. Determined by bit 2 of PPUCTRL
     */
    nothrow @safe @nogc ushort vramAddressIncrement() const
    {
        return (cpu.memory[ppuCtrl] & 0x04) > 0 ? 32 : 1;
    }

    /**
     * Returns: The base address of the sprite pattern table being used.
     *          Determined by bit 4 of PPUCTRL
     */
    nothrow @safe @nogc ushort spritePatternTableAddress() const
    {
        return (cpu.memory[ppuCtrl] & 0x08) > 0 ? 0x1000 : 0x0000;
    }

    /**
     * Returns: The PPU state as a string
     */
    override @safe string toString() const
    {
        return format("CYC: %3s SL:%d", cycles, scanline);
    }

    /// The PPU memory
    Memory memory;

    /// The PPU OAM memory
    OAM oam;

    /// The number of clock cycles executed in this scanline. Resets after 340
    uint cycles;

    /// The current scanline being drawn. Resets after 261
    uint scanline;

    /// PPU internal registers
    ushort v; /// Current VRAM address
    ushort t; /// Temporary VRAM address
    ubyte  x; /// Fine X scroll
    bool   w; /// First or second write toggle

    /// Background rendering registers
    ushort[2] patternData; /// Contains the pattern table data for two tiles
    ubyte[8] paletteData;  /// Contains the palette attributes for the lower
                           /// 8 pixels of 16-bit shift register

private:
    // PPU register constants
    const ushort ppuCtrl   = 0x2000;
    const ushort ppuMask   = 0x2001;
    const ushort ppuStatus = 0x2002;
    const ushort oamAddr   = 0x2003;
    const ushort oamData   = 0x2004;
    const ushort ppuScroll = 0x2005;
    const ushort ppuAddr   = 0x2006;
    const ushort ppuData   = 0x2007;

    Fiber _fiber;
}

// Export a global variable
PPU ppu = null;