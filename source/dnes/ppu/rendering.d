module dnes.ppu.rendering;

import core.thread;

import dnes.cpu;
import dnes.ppu;
import dnes.screen;
import dnes.util;

/**
 * Executes the PPU rendering loop indefinitely, yielding whenever a clock
 * cycle elapses. This function performs the memory accesses and sets the
 * shift registers and latches needed for rendering - the pixel that is drawn
 * every cycle is done by ppuDrawing()
 *
 * <https://wiki.nesdev.com/w/index.php/PPU_rendering>
 */
void ppuRendering()
{
    // Used to control if we are rendering an odd or even frame, which controls
    // if the idle cycle at the beginning of the first scanline is skipped
    // or not
    auto oddFrame = true;

    // At the beginning of this loop, the cycle count should be zero - the
    // beginning of a scanline
    while (true)
    {
        assert(ppu.cycles == 0);

        // Visible scanlines
        if ((ppu.scanline >= 0) && (ppu.scanline <= 239))
        {
            // Cycle 0 is an idle cycle - it is skipped on the first scanline
            // if this is an odd frame
            if ((!oddFrame) && (ppu.scanline == 0))
                Fiber.yield();
            else
                ppu.cycles++;
            oddFrame = !oddFrame;

            // Fills the pipeline for rendering
            callFiber(new Fiber(() => scanline(false)));
        }
        // Idle scanline
        else if (ppu.scanline == 240)
        {
            foreach (i; 0 .. 341)
                Fiber.yield();
        }
        // Vertical blanking lines
        else if ((ppu.scanline >= 241) && (ppu.scanline <= 260))
        {
            // The PPU makes no memory access during these scanlines, and only
            // sets the VBlank flag on cycle 1 of scanline 241
            Fiber.yield();
            if (ppu.scanline == 241)
            {
                cpu.memory[0x2002] = cpu.memory[0x2002] | 0x80;
                if (ppu.nmiOnVblank())
                {
                    cpu.interrupt = CPU.Interrupt.NMI;
                    screen.render();
                }
            }
            Fiber.yield();
            foreach (i; 0 .. 339)
                Fiber.yield();
        }
        // Prerender scanline
        else if (ppu.scanline == 261)
        {
            // Cycle 0 is an idle scanline
            Fiber.yield();

            // The prerender scanline makes all the same memory accesses as the
            // visible scanlines, in order to fill the pipeline for rendering
            callFiber(new Fiber(() => scanline(true)));
        }
    }
}

/**
 * Handles the rendering of the visible scanlines
 */
void scanline(bool prerender)
{
    // Only perform the memory access and v increments if rendering is enabled
    if ((ppu.renderBackground()) || (ppu.renderSprites()))
    {
        // Cycle 1 is the first cycle handled by this function - the idle cycle is
        // dealt with in the parent function. If the scanline is the prerender
        // scanline, then on cycle 1 the VBlank and Sprite 0 hit flags are unset
        if (prerender)
            cpu.memory[0x2002] = cpu.memory[0x2002] & 0x3f;

        // Fetches data for each tile on this scanline, except for the first two,
        // which were fetched on the previous scanline
        assert(ppu.cycles == 1);
        foreach (i; 0 .. 32)
            callFiber(new Fiber(&tileDataFetch));

        // At dot 257, the PPU copies all bits related to horizontal position from
        // t to v. The PPU then fetches tile data for the sprites on the next
        // scanline
        //
        // v: .....F.. ...EDCBA = t: .....F.. ...EDCBA
        assert(ppu.cycles == 257);
        ppu.v = (ppu.v & 0xfbe0) | (ppu.t & 0x041f);
        foreach (i; 0 .. 64)
            Fiber.yield();

        // Increment vertical v - this is meant to happen at cycle 256
        incrementFineYInVramAddr();

        // Fetches the first two tiles of the next scanline
        assert(ppu.cycles == 321);
        foreach (i; 0 .. 2)
            callFiber(new Fiber(&tileDataFetch));

        // Two dummy nametable byte fetches are done here
        assert(ppu.cycles == 337);
        foreach (i; 0 .. 4)
            Fiber.yield();
    }
    else
        // If rendering is disabled, then there is nothing to do
        foreach (i; 0 .. 340)
            Fiber.yield();
}

/**
 * Performs a single iteration of the sequence of fetching bytes for the
 * background tiles which occurs repeatedly during cycles 1-256 and 321-336 on
 * visibile scanlines. One execution takes 8 cycles, and increments hori(v) at
 * the end.
 */
void tileDataFetch()
{
    // Fetch the nametable byte
    const auto tileAddress = 0x2000 | (ppu.v & 0x0fff);
    const auto nametableByte = ppu.memory.get(tileAddress);
    Fiber.yield();
    Fiber.yield();

    // Fetch the attribute table byte
    const auto attributeAddr = 0x23c0 | (ppu.v & 0x0c00) | ((ppu.v >> 4) & 0x38) | ((ppu.v >> 2) & 0x07);
    const auto attributeTableByte = ppu.memory.get(attributeAddr);
    Fiber.yield();
    Fiber.yield();

    // Fetch the two pattern table bytes, using the value from the
    // nametable to select which pattern is selected
    const auto patternTableAddr = wrap!ushort(
        ppu.spritePatternTableAddress() + (nametableByte * 16) + (ppu.scanline % 8)
    );
    const auto patternTableTileLo = ppu.memory.get(patternTableAddr);
    Fiber.yield();
    Fiber.yield();

    const auto patternTableTileHi = ppu.memory.get(wrap!ushort(patternTableAddr + 8));
    Fiber.yield();
    Fiber.yield();

    // Reload the shift registers
    //
    // Pattern table bytes are read left-to-right, so pixel zero is the most
    // significant bit. This is in contrast to how the program would normally
    // read the value, where the least significant bit comes first. Therefore,
    // we need to flip the nametable bytes.
    ppu.patternData[0] = (ppu.patternData[0] & 0x00ff) | (flip(patternTableTileLo) << 8);
    ppu.patternData[1] = (ppu.patternData[1] & 0x00ff) | (flip(patternTableTileHi) << 8);
    ppu.paletteData[0] = ppu.paletteData[1];
    ppu.paletteData[1] = attributeTableByte;

    // Increment horizontal v
    ppu.v += ppu.vramAddressIncrement();
}

/**
 * Increments the fine y portion of the VRAM address (v), handling wrapping
 * around nametables
 *
 * <https://wiki.nesdev.com/w/index.php/PPU_scrolling#Y_increment>
 */
/*
void incrementFineYInVramAddr()
{
    if ((ppu.v & 0x7000) != 0x7000)
        ppu.v += 0x1000;
    else
    {
        ppu.v &= ~0x7000;
        auto y = (ppu.v & 0x03E0) >> 5;
        if (y == 29)
        {
            y = 0;
            ppu.v ^= 0x0800;
        }
        else if (y == 31)
            y = 0;
        else
            y += 1;
        ppu.v = wrap!ushort((ppu.v & ~0x03E0) | (y << 5));
    }
}
*/

/**
 * Increment the fine y portion of the VRAM address, wrapping around to coarse
 * y.
 */
void incrementFineYInVramAddr()
{
    const ubyte fineY = (ppu.v & 0xe000) >> 13;
    ppu.v = (ppu.v & 0x1fff) | (((fineY + 1) % 8) << 13);

    // The coarse y is naturally incremented during the rendering loop
    // incorrectly, so reset it unless the fine y is going to wrap
    if (fineY != 0)
    {
        ubyte coarseY = (ppu.v & 0x3e0) >> 5;
        coarseY = wrap!ubyte(coarseY - 1);
        ppu.v = (ppu.v & 0xfc1f) | (coarseY << 5);
    }
}