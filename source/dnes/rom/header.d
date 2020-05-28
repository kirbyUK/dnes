module dnes.rom.header;

/**
 * Struct representing the INES header
 */
struct Header
{
    char[4]  signature;   /// Signature - always 'NES<EOF>'
    ubyte    prgRomBanks; /// Number of 16kB PRG-ROM banks
    ubyte    chrRomBanks; /// Number of 8kB CHR_ROM (VROM) banks
    ubyte    control1;    /// ROM control byte 1
    ubyte    control2;    /// ROM control byte 2
    ubyte    prgRamSize;  /// Size of PRG RAM if used
    ubyte[7] unused;

    /**
     * Returns: True if the ROM contains a trainer, false if not
     */
    nothrow @safe @nogc bool containsTrainer() const
    {
        return ((control1 & 0x04) > 0);
    }

    /**
     * Returns: The mirroring used by the ROM
     */
    nothrow @safe @nogc Mirroring mirroring() const
    {
        return ((control1 & 0x08) > 0) ?
            Mirroring.FOURWAY :
            ((control1 & 0x01) > 0) ?
                Mirroring.VERTICAL :
                Mirroring.HORIZONTAL;
    }

    /**
     * Returns: The ROM mapper number
     */
    nothrow @safe @nogc uint mappingNumber() const
    {
        return ((control1 >> 4) | (control2 & 0x0f));
    }
}

/**
 * Enumeration of the types of ROM mapping
 */
enum Mirroring
{
    VERTICAL,
    HORIZONTAL,
    FOURWAY
}