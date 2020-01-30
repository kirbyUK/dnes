module dnes.rom.mapper.mapper;

import dnes.rom.mapper.mapper0;

/**
 * Interface for ROM mappers, which must implement a function to determine what
 * happens when they are written to
 */
interface Mapper
{
    /// Called when the mapper is written to
    ///
    /// Params:
    ///     addr  = The address that was requested be written to
    ///     value = The value that was requested be written
    nothrow @safe @nogc void write(ushort addr, ubyte value);
}

/**
 * Constructs a new Mapper-implementing object depending on the passed mapper
 * id number
 */
Mapper createMapper(int id)
{
    switch (id)
    {
        case 0: return new Mapper0();
        default: return null;
    }
}