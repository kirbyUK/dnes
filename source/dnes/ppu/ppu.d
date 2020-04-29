module dnes.ppu.ppu;

import core.thread;
import std.format;
import std.signals;

import dnes.cpu;
import dnes.ppu.drawing;
import dnes.ppu.memory;
import dnes.ppu.oam;
import dnes.ppu.rendering;
import dnes.ppu.sprite_evaluation;

/**
 * The NES PPU - controls picture rendering
 */
class PPU
{
public:
    /**
     * Constructor
     *
     * Params:
     *     rendering = True to enable rendering to the screen, false to avoid
     *                 making any writes to the global 'screen' object.
     */
    nothrow this(bool rendering)
    {
        memory = new Memory();
        cycles = 0;
        scanline = 0;
        secondaryOAM = 0xff;
        _rendering = rendering;
        _drawFiber = new Fiber(&ppuDrawing);
        _renderFiber = new Fiber(&ppuRendering);
        _spriteEvaluationFiber = new Fiber(&spriteEvaluation);
    }

    /**
     * Ticks the PPU along one clock cycle, performing whatever action carries
     * on from the last clock cycle
     */
    void tick()
    {
        _renderFiber.call();
        _spriteEvaluationFiber.call();
        if (_rendering)
            _drawFiber.call();

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
            t = (t & 0x80ff) | ((value & 0x3f) << 8);
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
     * Returns: The VRAM increment amount
     */
    nothrow @safe @nogc ushort vramAddressIncrement() const
    {
        return (cpu.memory[ppuCtrl] & 0x04) > 0 ? 32 : 1;
    }

    /**
     * Returns: The base nametable address
     */
    nothrow @safe @nogc ushort baseNametableAddress() const
    {
        final switch (cpu.memory[ppuCtrl] & 0x03)
        {
            case 0: return 0x2000;
            case 1: return 0x2400;
            case 2: return 0x2800;
            case 3: return 0x2c00;
        }
    }

    /**
     * Returns: The base address of the sprite pattern table being used
     */
    nothrow @safe @nogc ushort spritePatternTableAddress() const
    {
        return (cpu.memory[ppuCtrl] & 0x08) > 0 ? 0x1000 : 0x0000;
    }

    /**
     * Returns: The base address of the background pattern table being used
     */
    nothrow @safe @nogc ushort backgroundPatternTableAddress() const
    {
        return (cpu.memory[ppuCtrl] & 0x10) > 0 ? 0x1000 : 0x0000;
    }

    /**
     * Returns: If an NMI should be generated on VBLANK
     */
    nothrow @safe @nogc bool nmiOnVblank() const
    {
        return (cpu.memory[ppuCtrl] & 0x80) > 0;
    }

    /**
     * Returns: If the PPU has background rendering enabled or not
     */
    nothrow @safe @nogc bool renderBackground() const
    {
        return (cpu.memory[ppuMask] & 0x08) > 0;
    }

    /**
     * Returns: If the PPU has sprite rendering enabled or not
     */
    nothrow @safe @nogc bool renderSprites() const
    {
        return (cpu.memory[ppuMask] & 0x10) > 0;
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
    ubyte[2] paletteData;  /// Contains the palette attributes for the lower
                           /// 8 pixels of 16-bit shift register

    /// The PPU OAM memory
    ubyte[256] oam;         /// Primary OAM, 64 sprites
    ubyte[32] secondaryOAM; /// Secondary OAM, 8 sprites

    /// Sprite rendering registers
    ubyte[2][8] spritePatternData; /// High and low pattern bytes for 8 sprites
    ubyte[8] spriteAttribute;      /// Attribute bytes for 8 sprites
    ubyte[8] spriteXPosition;      /// X position bytes for 8 sprites

    /// Enumeration of signal event types
    enum Event
    {
        /// Signal that fires on every frame, regardless of whether rendering
        /// is enabled or not
        FRAME,
    }

    /// Signal mixin - used to send signals to inform external components
    /// about new frames, vblanks, etc.
    mixin Signal!(Event);

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

    bool _rendering;
    Fiber _drawFiber;
    Fiber _renderFiber;
    Fiber _spriteEvaluationFiber;
}

// Export a global variable
PPU ppu = null;