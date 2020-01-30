module dnes.rom.rom;

import std.path;
import std.stdio;

import dnes.rom.header;
import dnes.rom.mapper;

/**
 * Class for parsing and manipulating INES ROM files
 */
class ROM
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
        _data = new ubyte[file.size()];
        const auto buf = file.rawRead(_data);
        file.close();

        header = cast(Header*) _data.ptr;
        mapper = createMapper(mappingNumber());
    }

    /**
     * Returns: True if the ROM contains a trainer, false if not
     */
    nothrow @safe @nogc bool containsTrainer() const
    {
        return ((header.control1 & 0x04) > 0);
    }

    /**
     * Returns: The mirroring used by the ROM
     */
    nothrow @safe @nogc Mirroring mirroring() const
    {
        return ((header.control1 & 0x08) > 0) ?
            Mirroring.FOURWAY :
            ((header.control1 & 0x01) > 0) ?
                Mirroring.VERTICAL :
                Mirroring.HORIZONTAL;
    }

    /**
     * Returns: The ROM mapper number
     */
    nothrow @safe @nogc uint mappingNumber() const
    {
        return ((header.control1 >> 4) | (header.control2 & 0x0f));
    }

    /// The ROM's header
    Header* header;

    /// The ROM's mapper
    Mapper mapper;

private:
    const size_t _prgBankLen = 16384;
    const size_t _chrBankLen = 8192;

    /// The raw data from the file
    ubyte[] _data;
}

// Export a global variable
ROM rom = null;