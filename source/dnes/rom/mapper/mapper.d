module dnes.rom.mapper.mapper;

import dnes.rom.header;
import dnes.rom.mapper.mapper0;

/**
 * Interface for ROM mappers, which must implement a function to determine what
 * happens when they are written to
 */
interface Mapper
{
    /**
     * Called when a read to the mapper is made
     *
     * Params:
     *     addr = The address being read
     *
     * Returns: The data at the address
     */
    nothrow @safe @nogc ubyte read(ushort addr) const;

    /**
     * Called when the mapper is written to
     *
     * Params:
     *     addr  = The address that was requested be written to
     *     value = The value that was requested be written
     */
    nothrow @safe @nogc void write(ushort addr, ubyte value);
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
        default: return null;
    }
}