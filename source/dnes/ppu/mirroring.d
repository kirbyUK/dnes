module dnes.ppu.mirroring;

import dnes.rom;
import dnes.util;

/**
 * Handles PPU nametable mirroring
 *
 * Params:
 *     addr = The address trying to be read or written to
 *
 * Returns: The real address that will be read or written to
 */
nothrow @safe @nogc ushort nametableMirroring(ushort addr)
in (addr >= 0x2000 && addr < 0x3000)
out (r; r >= 0x2000 && r < 0x3000)
{
    auto ret = addr;

    switch (rom.header.mirroring())
    {
        // Horizontal mirroring
        // | A | A |
        // | B | B |
        case Mirroring.HORIZONTAL:
            if ((addr >= 0x2400) && (addr < 0x2800))
                ret = wrap!ushort(addr - 0x400);
            else if ((addr >= 0x2c00) && (addr < 0x3000))
                ret = wrap!ushort(addr - 0x400);
            break;

        // Vertical mirroring
        // | A | B |
        // | A | B |
        case Mirroring.VERTICAL:
            if ((addr >= 0x2800) && (addr < 0x2c00))
                ret = wrap!ushort(addr - 0x800);
            else if ((addr >= 0x2c00) && (addr < 0x3000))
                ret = wrap!ushort(addr - 0x800);
            break;

        default: break;
    }

    return ret;
}