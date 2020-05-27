module dnes.ppu.sprite_evaluation;

import core.thread;

import dnes.cpu;
import dnes.ppu.ppu;
import dnes.util;

/**
 * Continously performs the sprite evaluation, which determines which sprites
 * will get drawn on the next scanline
 *
 * <https://wiki.nesdev.com/w/index.php/PPU_sprite_evaluation>
 */
void spriteEvaluation()
{
    while (true)
    {
        // Sprite evaluation occurs if background or sprite rendering is
        // enabled, on all visible scanlines
        if ((ppu.scanline >= 0) && (ppu.scanline <= 239) &&
            ((ppu.renderBackground()) || (ppu.renderSprites())))
        {
            // Skip the first idle cycle to if required to keep synchronised
            // with odd frames, which skip the first cycle of scanline 0
            if (ppu.cycles < 1)
                Fiber.yield();
            assert(ppu.cycles == 1);

            // Cycles 1-64 - initialise secondary OAM to $FF
            initialiseSecondaryOAM();
            assert(ppu.cycles == 65);

            // Cycles 65-256 - sprite evaluation
            populateSecondaryOAM();
            assert(ppu.cycles == 257);

            // Cycles 257-320 - OAMADDR is reset to zero
            resetOAMAddr();
            assert(ppu.cycles == 321);

            // The remainder of the work is done by the rendering - the rest
            // of the sprite evaluation is useless reads of secondary OAM while
            // we wait for the PPU to grab it
            foreach (_; 0 .. 20)
                Fiber.yield();
        }
        else
        {
            assert((ppu.cycles == 0) || (ppu.cycles == 1));
            foreach (_; 0 .. (341 - ppu.cycles))
                Fiber.yield();
        }
    }
}

/**
 * Performs the initialisation of secondary OAM that occurs from cycles 1-64
 */
void initialiseSecondaryOAM()
{
    foreach (i; 0 .. 32)
    {
        ppu.secondaryOAM[i] = 0xff;
        Fiber.yield();
        Fiber.yield();
    }
}

/**
 * Performs the main sprite evaluation that occurs from cycles 65-256
 */
void populateSecondaryOAM()
{
    auto n = cpu.memory[0x2003];
    auto m = 0;
    auto spritesFound = 0;
    while (ppu.cycles < 257)
    {
        if ((n < 64) && (spritesFound < 8))
        {
            // Read a sprite's Y-coordinate and copy it into the next open slot in
            // secondary OAM
            const auto spriteY = ppu.oam[n * 4];
            Fiber.yield();
            if (spritesFound < 8)
                ppu.secondaryOAM[spritesFound * 4] = spriteY;
            Fiber.yield();

            // If the Y-coordinate is in range, copy the rest of the bytes to
            // secondary OAM - we have found a sprite
            if ((spritesFound < 8) && (isYCoordinateInRange(spriteY)))
            {
                foreach (i; 1 .. 4)
                {
                    const auto oamValue = ppu.oam[(n * 4) + i];
                    Fiber.yield();
                    ppu.secondaryOAM[(spritesFound * 4) + i] = oamValue;
                    Fiber.yield();
                }
                ppu.spriteNumber[spritesFound] = n;
                spritesFound++;
            }

            // Increment n
            n++;
        }
        else if ((n < 64) && (spritesFound >= 8))
        {
            // Evaluate OAM[n][m] as a Y-coordinate
            if (isYCoordinateInRange(ppu.oam[(n * 4) + m]))
            {
                // If it is in range, set the sprite overflow flag (bit 5 of PPUSTATUS)
                cpu.memory[0x2002] = cpu.memory[0x2002] | 0x20;

                // Read the next three entries of OAM, incrementing m after
                // each, and n if m overflows
                foreach (_; 0 .. 3)
                {
                    m = (m + 1) < 3 ? m + 1 : 0;
                    n = m == 0 ? wrap!ubyte(n + 1) : n;
                }
            }
            else
            {
                // If it is not in range, increment n AND m
                m = (m + 1) < 3 ? m + 1 : 0;
                n = m == 0 ? wrap!ubyte(n + 2) : wrap!ubyte(n + 1);
            }
        }
        else
            Fiber.yield();
    }
}

/**
 * Resets OAMADDR to zero for 64 cycles
 */
void resetOAMAddr()
{
    foreach (_; 0 .. 64)
    {
        cpu.memory[0x2003] = 0x00;
        Fiber.yield();
    }
}

/**
 * Determines if the given sprite y-coordinate is in range of the current
 * scanline, and can therefore be included in secondary OAM
 *
 * Params:
 *     spriteY = The sprite y-coordinate to evaluate
 *
 * Returns: True if the coordinate is in range, otherwise false
 */
nothrow @safe @nogc bool isYCoordinateInRange(int spriteY)
{
    return ((ppu.scanline >= spriteY) && (ppu.scanline < (spriteY + 8)));
}