module dnes.test.tests;

import std.format;

import dnes.cpu;
import dnes.ppu;
import dnes.rom;
import dnes.test.blargg_cpu_test;

/// 01-basics.nes
unittest
{
    // Arrange
    rom = new ROM("roms/instr_test-v5/rom_singles/01-basics.nes");
    cpu = new CPU(false);
    ppu = new PPU(false);
    auto test = new BlarggCPUTest();

    // Act
    test.run();

    // Assert
    assert(test.errorCode() == 0x00, test.errorText());
}

/// 02-implied.nes
unittest
{
    // Arrange
    rom = new ROM("roms/instr_test-v5/rom_singles/02-implied.nes");
    cpu = new CPU(false);
    ppu = new PPU(false);
    auto test = new BlarggCPUTest();

    // Act
    test.run();

    // Assert
    assert(test.errorCode() == 0x00, test.errorText());
}

/// 03-immediate.nes
unittest
{
    // Arrange
    rom = new ROM("roms/instr_test-v5/rom_singles/03-immediate.nes");
    cpu = new CPU(false);
    ppu = new PPU(false);
    auto test = new BlarggCPUTest();

    // Act
    test.run();

    // Assert
    assert(test.errorCode() == 0x00, test.errorText());
}

/// 04-zero_page.nes
unittest
{
    // Arrange
    rom = new ROM("roms/instr_test-v5/rom_singles/04-zero_page.nes");
    cpu = new CPU(false);
    ppu = new PPU(false);
    auto test = new BlarggCPUTest();

    // Act
    test.run();

    // Assert
    assert(test.errorCode() == 0x00, test.errorText());
}

/// 05-zp_xy.nes
unittest
{
    // Arrange
    rom = new ROM("roms/instr_test-v5/rom_singles/05-zp_xy.nes");
    cpu = new CPU(false);
    ppu = new PPU(false);
    auto test = new BlarggCPUTest();

    // Act
    test.run();

    // Assert
    assert(test.errorCode() == 0x00, test.errorText());
}

/// 06-absolute.nes
unittest
{
    // Arrange
    rom = new ROM("roms/instr_test-v5/rom_singles/06-absolute.nes");
    cpu = new CPU(false);
    ppu = new PPU(false);
    auto test = new BlarggCPUTest();

    // Act
    test.run();

    // Assert
    assert(test.errorCode() == 0x00, test.errorText());
}

/// 07-abs_xy.nes
unittest
{
    // Arrange
    rom = new ROM("roms/instr_test-v5/rom_singles/07-abs_xy.nes");
    cpu = new CPU(false);
    ppu = new PPU(false);
    auto test = new BlarggCPUTest();

    // Act
    test.run();

    // Assert
    assert(test.errorCode() == 0x00, test.errorText());
}

/// 08-ind_x.nes
unittest
{
    // Arrange
    rom = new ROM("roms/instr_test-v5/rom_singles/08-ind_x.nes");
    cpu = new CPU(false);
    ppu = new PPU(false);
    auto test = new BlarggCPUTest();

    // Act
    test.run();

    // Assert
    assert(test.errorCode() == 0x00, test.errorText());
}

/// 09-ind_y.nes
unittest
{
    // Arrange
    rom = new ROM("roms/instr_test-v5/rom_singles/09-ind_y.nes");
    cpu = new CPU(false);
    ppu = new PPU(false);
    auto test = new BlarggCPUTest();

    // Act
    test.run();

    // Assert
    assert(test.errorCode() == 0x00, test.errorText());
}

/// 10-branches.nes
unittest
{
    // Arrange
    rom = new ROM("roms/instr_test-v5/rom_singles/10-branches.nes");
    cpu = new CPU(false);
    ppu = new PPU(false);
    auto test = new BlarggCPUTest();

    // Act
    test.run();

    // Assert
    assert(test.errorCode() == 0x00, test.errorText());
}

/// 11-stack.nes
unittest
{
    // Arrange
    rom = new ROM("roms/instr_test-v5/rom_singles/11-stack.nes");
    cpu = new CPU(false);
    ppu = new PPU(false);
    auto test = new BlarggCPUTest();

    // Act
    test.run();

    // Assert
    assert(test.errorCode() == 0x00, test.errorText());
}

/// 12-jmp_jsr.nes
unittest
{
    // Arrange
    rom = new ROM("roms/instr_test-v5/rom_singles/12-jmp_jsr.nes");
    cpu = new CPU(false);
    ppu = new PPU(false);
    auto test = new BlarggCPUTest();

    // Act
    test.run();

    // Assert
    assert(test.errorCode() == 0x00, test.errorText());
}

/// 13-rts.nes
unittest
{
    // Arrange
    rom = new ROM("roms/instr_test-v5/rom_singles/13-rts.nes");
    cpu = new CPU(false);
    ppu = new PPU(false);
    auto test = new BlarggCPUTest();

    // Act
    test.run();

    // Assert
    assert(test.errorCode() == 0x00, test.errorText());
}

/// 14-rti.nes
unittest
{
    // Arrange
    rom = new ROM("roms/instr_test-v5/rom_singles/14-rti.nes");
    cpu = new CPU(false);
    ppu = new PPU(false);
    auto test = new BlarggCPUTest();

    // Act
    test.run();

    // Assert
    assert(test.errorCode() == 0x00, test.errorText());
}

/// 15-brk.nes
unittest
{
    // Arrange
    rom = new ROM("roms/instr_test-v5/rom_singles/15-brk.nes");
    cpu = new CPU(false);
    ppu = new PPU(false);
    auto test = new BlarggCPUTest();

    // Act
    test.run();

    // Assert
    assert(test.errorCode() == 0x00, test.errorText());
}

/// 16-special.nes
unittest
{
    // Arrange
    rom = new ROM("roms/instr_test-v5/rom_singles/16-special.nes");
    cpu = new CPU(false);
    ppu = new PPU(false);
    auto test = new BlarggCPUTest();

    // Act
    test.run();

    // Assert
    assert(test.errorCode() == 0x00, test.errorText());
}

/**
 * Stub main function
 */
int main(string[] args) { return 0; }