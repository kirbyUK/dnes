module dnes.ppu.drawing;

import core.thread;

import dnes.ppu.ppu;

/**
 * Implements the part of the PPU render loop that draws a pixel every cycle by
 * reading the values from the shift register that are put there by
 * ppuRendering()
 */
void ppuDrawing()
{
    while (true)
    {
        Fiber.yield();
    }
}