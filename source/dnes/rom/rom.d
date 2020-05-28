module dnes.rom.rom;

import std.path;
import std.stdio;

import dnes.rom.header;
import dnes.rom.mapper;

/**
 * Class for parsing and manipulating INES ROM files
 */
final class ROM
{
public:
    /**
     * Constructor
     * Params:
     *     path = The path to the ROM file to open
     */
    this(string path)
    {
        // Read the file
        auto file = File(path, "rb");
        auto _data = new ubyte[file.size()];
        const auto buf = file.rawRead(_data);
        file.close();

        header = cast(Header*) _data.ptr;
        mapper = createMapper(header, _data[Header.sizeof..$]);
    }

    /**
     * Handler for reads to the ROM's mapped address space by the CPU
     *
     * Params:
     *     addr = The address being read
     *
     * Returns: The value at the address, as determined by the mapper
     */
    nothrow @safe @nogc ubyte cpuRead(ushort addr) const
    {
        return mapper.cpuRead(addr);
    }

    /**
     * Handler for writes to the ROM's mapped address space by the CPU
     *
     * Params:
     *     addr  = The address being written to
     *     value = The value being written
     */
    nothrow @safe @nogc void cpuWrite(ushort addr, ubyte value)
    {
        mapper.cpuWrite(addr, value);
    }

    /**
     * Handler for reads to the ROM's mapped address space by the PPU
     *
     * Params:
     *     addr = The address being read
     *
     * Returns: The value at the address, as determined by the mapper
     */
    nothrow @safe @nogc ubyte ppuRead(ushort addr) const
    {
        return mapper.ppuRead(addr);
    }

    /**
     * Handler for writes to the ROM's mapped address space by the PPU
     *
     * Params:
     *     addr  = The address being written to
     *     value = The value being written
     */
    nothrow @safe @nogc void ppuWrite(ushort addr, ubyte value)
    {
        mapper.ppuWrite(addr, value);
    }

    /// The ROM's header
    Header* header;

private:
    /// The raw data from the file
    ubyte[] _data;

    /// The ROM's mapper
    Mapper mapper;
}

// Export a global variable
ROM rom = null;