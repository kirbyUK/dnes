module dnes.ppu.rendering;

import core.thread;

import dnes.ppu;

/**
 * Executes the PPU rendering loop indefinitely, yielding whenever a clock
 * cycle elapses
 */
void ppuRendering(PPU ppu)
{
    while (true)
    {
        Fiber.yield();
    }
}