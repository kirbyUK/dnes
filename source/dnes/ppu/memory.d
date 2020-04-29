module dnes.ppu.memory;

import std.typecons;

import dnes.rom;

/**
 * The PPU memory
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
            // The pattern tables are stored in the ROM
            tuple(0x0000u, 0x1FFFu): (ushort addr) { _memory[addr] = rom.ppuRead(addr); },
        ];

        _writeCallbacks = [
            // $3F10 is a mirror of $3F00
            tuple(0x3f10u, 0x3f10u): (ushort, ubyte value) { _memory[0x3f00] = value; },

            // $3F14 is a mirror of $3F04
            tuple(0x3f14u, 0x3f14u): (ushort, ubyte value) { _memory[0x3f04] = value; },

            // $3F18 is a mirror of $3F08
            tuple(0x3f18u, 0x3f18u): (ushort, ubyte value) { _memory[0x3f08] = value; },

            // $3F1C is a mirror of $3F0C
            tuple(0x3f1cu, 0x3f1cu): (ushort, ubyte value) { _memory[0x3f0c] = value; },
        ];
    }

    /**
     * Get the byte at the given address, performing any side effects that may
     * occur as a result of the read
     */
    @safe @nogc ubyte get(ushort addr)
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
    /// The memory of the NES PPU
    immutable size_t _memorySize = 0x4000;
    ubyte[_memorySize] _memory;

    /// List of callbacks to execute when reading certain addresses. Addresses
    /// are given as an inclusive range of values in a tuple.
    immutable nothrow @safe @nogc void delegate(ushort addr)[Tuple!(uint, uint)] _readCallbacks;

    /// List of callbacks to execute when writing to certain addresses.
    /// Addresses are given as an inclusive range of values in a tuple.
    immutable nothrow @nogc void delegate(ushort addr, ubyte value)[Tuple!(uint, uint)] _writeCallbacks;
}