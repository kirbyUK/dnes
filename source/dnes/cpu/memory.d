module dnes.cpu.memory;

import std.typecons;

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
        _readCallbacks = [
            // Reading PPUSTATUS clears the vblank flag and the PPU's internal write toggle
            tuple(0x2002u, 0x2002u): (ushort) { _memory[0x2002] &= 0x7F; ppu.w = false; },

            // Reading PPUADDR increments PPUADDR
            tuple(0x2007u, 0x2007u): (ushort) { },

            // Reading JOY1 gets the next button status
            tuple(0x4016u, 0x4016u): (ushort) { _memory[0x4016] = 0; }
        ];

        _writeCallbacks = [
            // Writes to the mapper are passed to it
            tuple(0x8000u, 0xFFFFu): (ushort addr, ubyte value) { rom.mapper.write(addr, value); }
        ];
    }

    /**
     * Get the byte at the given address, performing any side effects that may
     * occur as a result of the read
     */
    ubyte get8(ushort addr)
    {
        foreach (k, v; _readCallbacks)
        {
            if ((addr >= k[0]) && (addr <= k[1]))
                v(addr);
        }
        return _memory[addr];
    }

    /**
     * Set the byte at the given address, performing any side effects that may
     * occur as a result of the write (e.g. writing to PPU memory)
     */
    void set8(ushort addr, ubyte value)
    {
        foreach (k, v; _writeCallbacks)
        {
            if ((addr >= k[0]) && (addr <= k[1]))
                v(addr, value);
        }
        _memory[addr] = value;
    }

    /**
     * Overload of the index operator that allows for direct access to the
     * memory with no side effects
     */    
    nothrow @safe @nogc const(ubyte) opIndex(size_t index) const
    in (index >= 0 && index < _memorySize)
    {
        return _memory[index];
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
    const size_t _memorySize = 0x10000;
    ubyte[_memorySize] _memory;

    /// List of callbacks to execute when reading certain addresses. Addresses
    /// are given as an inclusive range of values in a tuple.
    nothrow @safe @nogc void delegate(ushort addr)[Tuple!(uint, uint)] _readCallbacks;

    /// List of callbacks to execute when writing to certain addresses.
    /// Addresses are given as an inclusive range of values in a tuple.
    nothrow @safe @nogc void delegate(ushort addr, ubyte value)[Tuple!(uint, uint)] _writeCallbacks;
}