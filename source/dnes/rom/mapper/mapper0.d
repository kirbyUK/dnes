module dnes.rom.mapper.mapper0;

import dnes.rom.header;
import dnes.rom.mapper.mapper;

import std.stdio;

/**
 * Class representing Mapper 0 (NROM)
 * <https://wiki.nesdev.com/w/index.php/NROM>
 */
class Mapper0 : Mapper
{
public:
    /**
     * Constructor
     *
     * Params:
     *     header = The header of the ROM file
     *     data   = The data of the ROM, minus the header
     */
    this(const Header* header, ubyte[] data)
    {
        // Populate the PRG-ROM banks
        if (header.prgRomBanks > 0)
        {
            const size_t offset1 = prgBankSize * (header.prgRomBanks - 1);
            const size_t offset2 = prgBankSize * header.prgRomBanks;
            _prgBank1 = data[0..offset1];
            _prgBank2 = data[offset1..offset2];
        }

        // Populate the CHR-ROM banks, if any
        if (header.chrRomBanks > 0)
        {
            const size_t offset = prgBankSize * header.prgRomBanks;
            _chrBank = data[offset..(offset + chrBankSize)];
        }
    }

    /**
     * Reads memory from Mapper 0
     *
     * Params:
     *     addr = The address the CPU requested
     *
     * Returns: Memory from the ROM, pulled from a bank based on the address
     *          given. Reads from the save game area ($4020-$7FFF) return zero
     */
    override nothrow @safe @nogc ubyte read(ushort addr) const
    {
        if ((addr >= chrBankOffset) && (addr < prgBank1Offset))
            return _chrBank[addr - chrBankOffset];
        else if ((addr >= prgBank1Offset) && (addr < prgBank2Offset))
            return _prgBank1[addr - prgBank1Offset];
        else if (addr >= prgBank2Offset)
            return _prgBank2[addr - prgBank2Offset];
        else
            return 0;
    }

    /**
     * Mapper 0 does nothing when written to
     */
    override nothrow @safe @nogc void write(ushort addr, ubyte value)
    {
    }

private:
    // The size of each type of bank
    const ushort chrBankSize = 0x2000;
    const ushort prgBankSize = 0x4000;

    // The offsets that each bank begins at
    const ushort chrBankOffset  = 0x6000;
    const ushort prgBank1Offset = 0x8000;
    const ushort prgBank2Offset = 0xC000;

    // The slices containing the data for each bank
    ubyte[] _chrBank;
    ubyte[] _prgBank1;
    ubyte[] _prgBank2;
}