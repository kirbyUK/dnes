module dnes.ppu.drawing;

import core.thread;
import std.typecons;

import dnes.ppu.ppu;
import dnes.screen;

/**
 * Implements the part of the PPU render loop that draws a pixel every cycle by
 * reading the values from the shift register that are put there by
 * ppuRendering()
 */
void ppuDrawing()
{
    while (true)
    {
        if ((ppu.scanline >= 0) && (ppu.scanline <= 239) && (ppu.cycles >= 2) && (ppu.cycles <= 257))
        {
            const auto x = ppu.cycles - 2;
            const auto y = ppu.scanline;
            if (ppu.renderBackground())
            {
                // Get the background tile pixel value
                const auto tile = backgroundTile();

                // Get the sprite tile pixel value
                const auto selectedSprite = currentSprite(x);
                const auto sprite = !selectedSprite.isNull ?
                    spriteTile(selectedSprite.get, x) : 0;

                // Determine which to render based on the values
                if ((tile == 0) && (sprite == 0))
                {
                    // If the BG pixel and the sprite pixel are 0, use the
                    // background colour
                    screen.draw(ppu.memory[0x3f00], x, y);
                }
                else if (sprite == 0)
                {
                    // If the sprite pixel is zero, draw the background tile.
                    // The attribute data selects the palette, and the tile
                    // value selects the colour in the palette
                    const auto paletteAddr = backgroundPaletteBase[backgroundPalette()] + (tile - 1);
                    screen.draw(ppu.memory[paletteAddr], x, y);
                }
                else if (tile == 0)
                {
                    // If the background is zero, render the sprite
                    const auto paletteAddr = spritePaletteBase[spritePalette(selectedSprite.get)] + (sprite - 1);
                    screen.draw(ppu.memory[paletteAddr], x, y);
                }
                else
                {
                    // If both the background and sprite are not zero,
                    // determine using the priority field of the sprite
                    const auto spritePriority = !((ppu.spriteAttribute[selectedSprite.get] & 0x20) > 0);
                    if (spritePriority)
                    {
                        const auto paletteAddr = spritePaletteBase[spritePalette(selectedSprite.get)] + (sprite - 1);
                        screen.draw(ppu.memory[paletteAddr], x, y);
                    }
                    else
                    {
                        const auto paletteAddr = backgroundPaletteBase[backgroundPalette()] + (tile - 1);
                        screen.draw(ppu.memory[paletteAddr], x, y);
                    }
                }
            }
            else
                screen.draw(0x3f, x, y);
        }

        if ((isFetchScanline()) &&
            (((ppu.cycles >= 2) && (ppu.cycles <= 257)) || ((ppu.cycles >= 322) && (ppu.cycles <= 337))))
        {
            // Shift the registers for the next value
            ppu.patternData[0] >>= 1;
            ppu.patternData[1] >>= 1;
            ppu.paletteData[0] >>= 1;
            ppu.paletteData[1] >>= 1;
        }

        Fiber.yield();
    }
}

/**
 * Returns: The background tile value for this pixel
 */
nothrow @safe @nogc ubyte backgroundTile()
out (r; r >= 0 && r <= 3)
{
    // Get the low and high background tile bits to form the two-bit tile.
    // Which bits are selected depends on the fine x scroll.
    const ubyte tileLoByte = ppu.patternData[0] & 0x00ff;
    const ubyte tileHiByte = ppu.patternData[1] & 0x00ff;
    const ubyte tileLoBit = (tileLoByte >> ppu.x) & 0x01;
    const ubyte tileHiBit = (tileHiByte >> ppu.x) & 0x01;
    const ubyte tile = (tileHiBit << 1) | tileLoBit;
    return tile;
}

/**
 * Returns: The palette attribute for the current background pixel
 */
nothrow @safe @nogc ubyte backgroundPalette()
out (r; r >= 0 && r <= 3)
{
    // Get the low and high bits of the palette attribute for the tile
    const ubyte attrLoBit = (ppu.paletteData[0] >> ppu.x) & 0x01;
    const ubyte attrHiBit = (ppu.paletteData[1] >> ppu.x) & 0x01;
    const ubyte attr = (attrHiBit << 1) | attrLoBit;
    return attr;
}

/**
 * Params:
 *     renderXPos = The X-coordinate being rendered
 *
 * Returns: The current sprite to render that is in range for this pixel, or
 *          null if there is none
 */
nothrow @safe @nogc Nullable!int currentSprite(int renderXPos)
out (r; r.isNull || (r.get >= 0 && r.get <= 7))
{
    foreach (i; 0 .. 8)
    {
        const auto spriteX = ppu.spriteXPosition[i];
        if ((spriteX != 0xff) && (renderXPos >= spriteX) && (renderXPos < (spriteX + 8)))
            return i.nullable;
    }

    return Nullable!int.init;
}

/**
 * Params:
 *     selectedSprite = The sprite selected for this pixel
 *     renderXPos     = The X-coordinate being rendered
 *
 * Returns: The selected sprite tile value
 */
nothrow @safe @nogc ubyte spriteTile(int selectedSprite, int renderXPos)
in (selectedSprite >= 0 && selectedSprite <= 7)
out (r; r >= 0 && r <= 3)
{
    const auto spriteLoByte = ppu.spritePatternData[selectedSprite][0];
    const auto spriteHiByte = ppu.spritePatternData[selectedSprite][1];
    const auto spriteLoBit = (spriteLoByte >> (renderXPos - ppu.spriteXPosition[selectedSprite])) & 0x01;
    const auto spriteHiBit = (spriteHiByte >> (renderXPos - ppu.spriteXPosition[selectedSprite])) & 0x01;
    const ubyte sprite = (spriteHiBit << 1) | spriteLoBit;
    return sprite;
}

/**
 * Params:
 *     selectedSprite = The sprite selected for this pixel
 *
 * Returns: The palette attribute for the selected sprite
 */
nothrow @safe @nogc ubyte spritePalette(int selectedSprite)
in (selectedSprite >= 0 && selectedSprite <= 7)
out (r; r >= 0 && r <= 3)
{
    return ppu.spriteAttribute[selectedSprite] & 0x03;
}

/**
 * Returns: True if the PPU is on a scanline that performs tile fetches,
 *          false if not
 */
nothrow @safe @nogc bool isFetchScanline()
{
    return ((ppu.scanline >= 0) && ((ppu.scanline <= 239) || (ppu.scanline == 261)));
}

/// Background palette base addresses
immutable ushort[4] backgroundPaletteBase = [ 0x3f01, 0x3f05, 0x3f09, 0x3f0d ];

/// Sprite palette base addresses
immutable ushort[4] spritePaletteBase = [ 0x3f11, 0x3f15, 0x3f19, 0x3f1d ];