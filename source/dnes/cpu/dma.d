module dnes.cpu.dma;

import core.thread;

import dnes.cpu.cpu;
import dnes.ppu;

/**
 * Implements CPU DMA, where the CPU transfers a chunk of memory to PPU OAM
 * memory instead of normal execution
 */
void oamdma(CPU cpu)
{
    // Dummy CPU cycle, plus another if it is an odd CPU cycle
    Fiber.yield();
    if ((cpu.cycles % 2) != 0)
        Fiber.yield();

    // DMA transfers 256 bytes from $XX00-$XXFF to the PPU's internal OAM,
    // where $XX is the contents of the OAMDMA (0x4014) PPU register
    const ushort addr = cpu.memory[0x4014] << 8;
    foreach (i; 0 .. 256)
    {
        const auto data = cpu.memory[addr | i];
        Fiber.yield();
        ppu.oam[i] = data;
        Fiber.yield();
    }

    cpu.dma = false;
}