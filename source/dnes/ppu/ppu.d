module dnes.ppu.ppu;

import core.thread;
import std.format;
import std.signals;

import dnes.cpu;
import dnes.ppu.drawing;
import dnes.ppu.memory;
import dnes.ppu.rendering;
import dnes.ppu.sprite_evaluation;
import dnes.util;

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
     *     unitTest = True to disable rendering to the screen and avoid
     *                making any writes to the global 'screen' object.
     *     scanline = The initial scanline value.
     */
    nothrow this(bool unitTest = false, uint scanline = 0)
    {
        memory = new Memory();
        secondaryOAM = 0xff;
        _cycles = 0;
        _scanline = scanline;
        _unitTestMode = unitTest;
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
        if (!_unitTestMode)
            _drawFiber.call();

        if (++_cycles > 340)
        {
            _cycles = 0;
            if (++_scanline > 261)
                _scanline = 0;
        }
    }

    /**
     * Called when an instruction writes to PPUCTRL ($2000).
     *
     * Writing to PPUCTRL also sets the namespace select in the temporary VRAM
     * address.
     *
     * Params:
     *     value = The value written to PPUCTRL
     */
    nothrow @safe @nogc void ppuCtrlWrite(ubyte value)
    {
        t = (t & 0xf3ff) | ((value & 0x03) << 10);
    }

    /**
     * Called when an instruction reads PPUSTATUS ($2002).
     *
     * Reading PPUSTATUS clears the vblank flag, and resets the internal PPU
     * write toggle.
     */
    nothrow @safe @nogc void ppuStatusRead()
    {
        // Clearing the vblank flag is handled by the CPU memory, since the
        // value of the register is held there. This function only resets the
        // write toggle
        w = false;
    }

    /**
     * Called when an instruction writes to OAMDATA ($2004).
     *
     * Writes the passed value to the PPU OAM, at the address determined by the
     * address in OAMADDR. Increments the value in OAMADDR after writing.
     *
     * Nesdev describes glitchy behaviour when writing to this register during
     * rendering. This function takes the recommended approach of ignoring
     * writes during rendering.
     *
     * Params:
     *     value = The value written to OAMDATA
     */
    nothrow @safe @nogc void oamDataWrite(ubyte value)
    {
        // Writes are ignored during rendering
        if (!(ppu.renderBackground() && ppu.renderSprites()) ||
             (cpu.memory[ppuStatus] & 0x80) == 0)
        {
            oam[cpu.memory[oamAddr]] = value;
            cpu.memory[oamAddr] = wrap!ubyte(cpu.memory[oamAddr] + 1);
        }
    }

    /**
     * Called when an instruction writes to PPUSCROLL ($2005).
     *
     * To fully update the scroll takes two writes. The first write updates the
     * X scroll positions, the second updates the Y scroll positions.
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
            t = (t & 0x8FFF) | ((value & 0x07) << 12);
            t = (t & 0xFC1F) | ((value & 0xF8) << 2);
            w = false;
        }
    }

    /**
     * Called when an instruction writes to PPUADDR ($2006).
     *
     * To full update the address takes two writes - the high byte is set with
     * the first write, the lower with the second. Only writes to the real PPU
     * address on the second write.
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
     * Called when an instruction reads PPUDATA ($2007).
     *
     * Retrieves the value at the PPU address, which is set by writing to
     * PPUADDR. Implements the read buffer - the first read puts the value in
     * the buffer, a second read is needed to retrieve it.
     *
     * Increments the PPU address on each read by either 1 or 32, the amount is
     * decided by bit 2 of PPUCTRL.
     *
     * Returns: The value in the PPU data read buffer.
     */
    @safe @nogc ubyte ppuDataRead()
    {
        const auto value = _ppuDataReadBuffer;
        _ppuDataReadBuffer = memory.get(v);
        v += vramAddressIncrement();
        return value;
    }

    /**
     * Called when an instruction writes to PPUDATA ($2007).
     *
     * Writing to PPUDATA sets the value at the current PPU address, which can
     * be set by writing to PPUADDR.
     *
     * Increments the PPU address on each write by either 1 or 32, the amount is
     * decided by bit 2 of PPUCTRL.
     *
     * Params:
     *     value = The value written to PPUDATA.
     */
    @nogc void ppuDataWrite(ubyte value)
    {
        memory.set(ppu.v, value);
        v += vramAddressIncrement();
    }

    /**
     * Returns: The VRAM increment amount
     */
    nothrow @safe @nogc ushort vramAddressIncrement() const
    {
        return (cpu.memory[ppuCtrl] & 0x04) > 0 ? 32 : 1;
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

    /**
     * Returns: The number of clock cycles executed in this scanline. Resets after 340
     */
    @property nothrow @safe @nogc uint cycles() const
    {
        return _cycles;
    }

    /**
     * Returns: The current scanline being drawn. Resets after 261
     */
    @property nothrow @safe @nogc uint scanline() const
    {
        return _scanline;
    }

    /// The PPU OAM memory
    ubyte[256] oam; /// Primary OAM, 64 sprites

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

package:
    /**
     * Skips a cycle - used on the first scanline of each odd frame
     */
    nothrow @safe @nogc void skipCycle()
    {
        _cycles++;
    }

    /// The PPU memory
    Memory memory;

    /// PPU internal registers
    ushort v; /// Current VRAM address
    ushort t; /// Temporary VRAM address
    ubyte  x; /// Fine X scroll
    bool   w; /// First or second write toggle
    invariant (x <= 7);

    /// Background rendering registers
    ushort[2] patternData; /// Contains the pattern table data for two tiles
    ubyte[2][2] paletteData;  /// Contains the palette attributes for the lower
                              /// 8 pixels of 16-bit shift register

    /// Sprite rendering registers
    ubyte[2][8] spritePatternData; /// High and low pattern bytes for 8 sprites
    ubyte[8] spriteAttribute;      /// Attribute bytes for 8 sprites
    ubyte[8] spriteXPosition;      /// X position bytes for 8 sprites
    ubyte[8] spriteNumber;         /// The primary OAM number of each selected sprite

    /// OAM
    ubyte[32] secondaryOAM; /// Secondary OAM, 8 sprites

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

    /// The number of clock cycles executed in this scanline. Resets after 340
    uint _cycles;
    invariant (_cycles <= 340);

    /// The current scanline being drawn. Resets after 261
    uint _scanline;
    invariant (_scanline <= 261);

    /// The read buffer when reading from PPUDATA ($2007)
    ubyte _ppuDataReadBuffer;

    bool _unitTestMode;
    Fiber _drawFiber;
    Fiber _renderFiber;
    Fiber _spriteEvaluationFiber;
}

// Export a global variable
PPU ppu = null;