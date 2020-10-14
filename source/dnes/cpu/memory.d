module dnes.cpu.memory;

import std.typecons;

import dnes.controller;
import dnes.cpu;
import dnes.ppu;
import dnes.rom;

/**
 * The main memory of the NES
 */
class Memory
{
public:
    /**
     * Constructor
     */
    nothrow @safe this()
    {
        _preReadCallbacks = [
            // Reading PPUDATA retrieves the value from PPU memory according to
            // the PPU's internal pointer, which is set by writing to PPUADDR.
            // It then increments the address
            tuple(0x2007u, 0x2007u): (ushort addr) { _memory[0x2007] = ppu.ppuDataRead(); },

            // Reading JOY1 gets the next button status
            tuple(0x4016u, 0x4016u): (ushort) { _memory[0x4016] = controller.read(); },

            // Reads to ROM spaced are passed to the ROM to deal with
            tuple(0x4020u, 0xffffu): (ushort addr) { _memory[addr] = rom.cpuRead(addr); }
        ];

        _postReadCallbacks = [
            // Reading PPUSTATUS clears the vblank flag and the PPU's internal write toggle
            tuple(0x2002u, 0x2002u): (ushort) { _memory[0x2002] &= 0x7f; ppu.ppuStatusRead(); },
        ];

        _writeCallbacks = [
            // Writing to PPUCTRL also sets the namespace select in the PPU's
            // temporary VRAM address
            tuple(0x2000u, 0x2000u): (ushort, ubyte value) { ppu.ppuCtrlWrite(value); },

            // Writing to OAMDATA writes to the PPU OAM, and increments OAMADDR
            tuple(0x2004u, 0x2004u): (ushort, ubyte value) { ppu.oamDataWrite(value); },

            // Writes to PPUSCROLL set the X then Y scroll positions
            tuple(0x2005u, 0x2005u): (ushort, ubyte value) { ppu.ppuScrollWrite(value); },

            // Writes to PPUADDR set the address for the data in PPUDATA, in
            // two stages
            tuple(0x2006u, 0x2006u): (ushort, ubyte value) { ppu.ppuAddrWrite(value); },

            // Writes to PPUDATA set the value written to the PPU's internal
            // memory - the address is determined by writes to PPUADDR. It then
            // increments the internal address
            tuple(0x2007u, 0x2007u): (ushort, ubyte value) { ppu.ppuDataWrite(value); },

            // Writes to OAMDMA cause the CPU to enter DMA
            tuple(0x4014u, 0x4014u): (ushort, ubyte) { cpu.dma = true; },

            // Writes to JOY1 cause both controllers to strobe
            tuple(0x4016u, 0x4016u): (ushort, ubyte value) { controller.strobe(value); },

            // Writes to the ROM are passed to it
            tuple(0x4020u, 0xffffu): (ushort addr, ubyte value) { rom.cpuWrite(addr, value); },
        ];
    }

    /**
     * Get the byte at the given address, performing any side effects that may
     * occur as a result of the read
     */
    @safe @nogc ubyte get(ushort addr)
    {
        foreach (k, v; _preReadCallbacks)
        {
            if ((addr >= k[0]) && (addr <= k[1]))
                v(addr);
        }

        const auto ret = _memory[addr];

        foreach (k, v; _postReadCallbacks)
        {
            if ((addr >= k[0]) && (addr <= k[1]))
                v(addr);
        }

        return ret;
    }

    /**
     * Set the byte at the given address, performing any side effects that may
     * occur as a result of the write (e.g. writing to PPU memory)
     */
    @nogc void set(ushort addr, ubyte value)
    {
        foreach (k, v; _writeCallbacks)
        {
            if ((addr >= k[0]) && (addr <= k[1]))
                v(addr, value);
        }
        _memory[addr] = value;
    }

    /**
     * Push the given value to the stack
     */
    @nogc void push(ubyte value)
    {
        set(0x0100 + cpu.sp, value);
        cpu.sp--;
    }

    /**
     * Pop a value from the stack
     */
    @safe @nogc ubyte pop()
    {
        cpu.sp++;
        return get(0x0100 + cpu.sp);
    }

    /**
     * Overload of the index operator that allows for direct access to the
     * memory with no side effects
     */    
    nothrow @safe @nogc ubyte opIndex(size_t index) const
    in (index >= 0 && index < _memorySize)
    {
        return (index < 0x4020) ?_memory[index] : rom.cpuRead(cast (ushort) index);
    }

    /**
     * Overload of the index operator to be used with slices, that allows for
     * direct access to the memory with no side effects
     */
    nothrow @safe @nogc const(ubyte)[] opIndex(size_t[2] index) const
    in (index[0] >= 0 && index[0] <= index[1] && index[1] < _memorySize)
    {
        return _memory[index[0]..index[1]];
    }

    /**
     * Overload of the index assignment operator that allows for direct access
     * with no side effects
     */
    nothrow @safe @nogc void opIndexAssign(ubyte value, size_t index)
    in (index >= 0 && index < _memorySize)
    {
        _memory[index] = value;
    }

    /**
     * Overload of the index assignment operator to be used with slices that
     * allows for direct access with no side effects
     */
    nothrow @safe @nogc void opIndexAssign(ubyte[] value, size_t[2] index)
    in (index[0] >= 0 && index[0] <= index[1] && index[1] < _memorySize)
    {
        _memory[index[0]..index[1]] = value;
    }

    /**
     * Overload of the opSlice operator
     */
    nothrow @safe @nogc size_t[2] opSlice(size_t i, size_t j) const
    in (i <= j)
    {
        return [ i, j ];
    }

private:
    /// The memory of the NES CPU
    immutable size_t _memorySize = 0x10000;
    ubyte[_memorySize] _memory;

    /// List of callbacks to execute when reading certain addresses. Addresses
    /// are given as an inclusive range of values in a tuple.
    immutable @safe @nogc void delegate(ushort addr)[Tuple!(uint, uint)] _preReadCallbacks;
    immutable @safe @nogc void delegate(ushort addr)[Tuple!(uint, uint)] _postReadCallbacks;

    /// List of callbacks to execute when writing to certain addresses.
    /// Addresses are given as an inclusive range of values in a tuple.
    immutable @nogc void delegate(ushort addr, ubyte value)[Tuple!(uint, uint)] _writeCallbacks;
}