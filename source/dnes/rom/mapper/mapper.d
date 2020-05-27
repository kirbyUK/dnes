module dnes.rom.mapper.mapper;

import std.exception;
import std.format;

import dnes.rom.header;
import dnes.rom.mapper.mapper0;

/**
 * Interface for ROM mappers, which must implement a function to determine what
 * happens when they are written to
 */
interface Mapper
{
    /**
     * Called when a read to the mapper is made by the CPU
     *
     * Params:
     *     addr = The address being read
     *
     * Returns: The data at the address in PRG-ROM
     */
    nothrow @safe @nogc ubyte cpuRead(ushort addr) const;

    /**
     * Called when the mapper is written to by the CPU
     *
     * Params:
     *     addr  = The address that was requested be written to
     *     value = The value that was requested be written
     */
    nothrow @safe @nogc void cpuWrite(ushort addr, ubyte value);

    /**
     * Called when a read to the mapper is made by the PPU
     *
     * Params:
     *     addr  = The address being read
     *
     * Returns: The data at the address in CHR-ROM
     */
    nothrow @safe @nogc ubyte ppuRead(ushort addr) const;

    /**
     * Called when the mapper is written to by the PPU
     *
     * Params:
     *     addr  = The address that was requested be written to
     *     value = The value that was requested be written
     */
    nothrow @safe @nogc void ppuWrite(ushort addr, ubyte value);
}

/**
 * Exception thrown when a ROM presents an unknown mapper value
 */
class MapperException : Exception
{
    /**
     * Constructor
     *
     * Params:
     *     mapper = The failing mapper number
     */
    @safe this(int mapper)
    {
        super(format("Unknown mapper number: %d", mapper), __FILE__, __LINE__);
    }
}

/**
 * Constructs a new Mapper-implementing object depending on the passed mapper
 * id number
 *
 * Params:
 *     id     = The mapper number to create
 *     header = The header of the ROM file
 *     data   = The data of the ROM, minus the header
 *
 * Returns: The constructed Mapper object
 */
Mapper createMapper(int id, const Header* header, ubyte[] data)
{
    switch (id)
    {
        case 0: return new Mapper0(header, data);
        default: throw new MapperException(id);
    }
}