module dnes.rom.mapper.mapper0;

import dnes.rom.mapper.mapper;

/**
 * Class representing Mapper 0
 */
class Mapper0 : Mapper
{
    /**
     * Mapper 0 does nothing when written to
     */
    override nothrow @safe @nogc void write(ushort addr, ubyte value) {}
}