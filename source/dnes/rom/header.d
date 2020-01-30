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