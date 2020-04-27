module dnes.ppu.sprite_evaluation;

import core.thread;

import dnes.ppu.ppu;

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
            foreach (i; 0 .. 32)
            {
                ppu.secondaryOAM[i] = 0xff;
                Fiber.yield();
                Fiber.yield();
            }
            assert(ppu.cycles == 65);
            foreach (_; 0 .. 276)
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