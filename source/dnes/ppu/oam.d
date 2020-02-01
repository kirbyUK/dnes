module dnes.ppu.oam;

/**
 * Struct representing an individual sprite contained in OAM memory
 */
struct Sprite
{
    ubyte y;     /// Y co-ordinate of the top of the sprite
    ubyte index; /// Tile index number
    ubyte attr;  /// Attributes
    ubyte x;     /// X co-ordinate of the left of the sprite

    /**
     * Returns: The palette number used by the sprite
     */
    nothrow @safe @nogc ubyte palette() const
    out (r; r >= 0 && r <= 3)
    {
        return attr & 0x03;
    }

    /**
     * Returns: If the sprite has priority of not
     */
    nothrow @safe @nogc bool priority() const
    {
        return !((attr & 0x20) >> 5);
    }

    /**
     * Returns: If the sprite should be flipped horizontally
     */
    nothrow @safe @nogc bool flipHorizontal() const
    {
        return !((attr & 0x40) >> 6);
    }

    /**
     * Returns: If the sprite should be flipped vertically
     */
    nothrow @safe @nogc bool flipVertical() const
    {
        return !((attr & 0x80) >> 7);
    }
}

/**
 * Represents the PPU's OAM memory
 */
union OAM
{
    /// A view of OAM memory as a list of Sprites
    Sprite[64] sprites;

    /// The raw bytes of the OAM memory
    ubyte[256] raw;
}