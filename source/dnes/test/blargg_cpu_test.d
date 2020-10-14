module dnes.test.blargg_cpu_test;

import std.format;

import dnes.cpu;
import dnes.ppu;
import dnes.rom;
import dnes.test.itest;

/**
 * ITest implementation for the blargg CPU test (individual ROMs)
 */
class BlarggCPUTest : ITest
{
public:
    /**
     * Constructor
     */
    nothrow @safe @nogc this()
    {
        _testStarted = false;
        _testFinished = false;
        _errorText = "";
    }

    /**
     * Runs the test ROM until completion
     */
    void run()
    {
        try
        {
            while (!exit())
            {
                cpu.tick();
                ppu.tick();
                ppu.tick();
                ppu.tick();
            }
        }
        catch (UnknownInstructionException)
        {
            cpu.memory.set(0x6000, 0x00);
        }

        int i = 0;
        while (cpu.memory[0x6004 + i] != 0)
        {
            _errorText ~= cast(char)cpu.memory[0x6004 + i];
            i++;
        }
    }

    /**
     * Returns: The error code given by the test
     */
    nothrow @safe @nogc ubyte errorCode() const
    {
        return cpu.memory[0x6000];
    }

    /**
     * Returns: The error string given by the test ROM
     */
    string errorText() const
    {
        return format("errorCode: $%02X\nerror string:\n%s", errorCode(), _errorText);
    }

private:
    bool _testStarted;
    bool _testFinished;
    string _errorText;

    /**
     * Returns: If the test has finished or not
     */
    bool exit()
    {
        // The value at $6000 determines the running state of the test, where
        // $80 means it is still running. This function uses a small state
        // machine to progress from the running to finished state, since the
        // value in $6000 is $00 on initialisation
        if (!_testStarted)
        {
            if (cpu.memory[0x6000] == 0x80)
                _testStarted = true;
        }
        else
        {
            if (cpu.memory[0x6000] != 0x80)
                _testFinished = true;
        }

        return _testFinished;
    }
}

// ----------------------------------------------------------------------------
// BEGIN TESTS
// ----------------------------------------------------------------------------

/// 01-basics.nes
unittest
{
    // Arrange
    rom = new ROM("roms/instr_test-v5/rom_singles/01-basics.nes");
    cpu = new CPU(false);
    ppu = new PPU(true);
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
    ppu = new PPU(true);
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
    ppu = new PPU(true);
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
    ppu = new PPU(true);
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
    ppu = new PPU(true);
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
    ppu = new PPU(true);
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
    ppu = new PPU(true);
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
    ppu = new PPU(true);
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
    ppu = new PPU(true);
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
    ppu = new PPU(true);
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
    ppu = new PPU(true);
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
    ppu = new PPU(true);
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
    ppu = new PPU(true);
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
    ppu = new PPU(true);
    auto test = new BlarggCPUTest();

    // Act
    test.run();

    // Assert
    assert(test.errorCode() == 0x00, test.errorText());
}

/// 15-brk.nes
/*
unittest
{
    // Arrange
    rom = new ROM("roms/instr_test-v5/rom_singles/15-brk.nes");
    cpu = new CPU(false);
    ppu = new PPU(true);
    auto test = new BlarggCPUTest();

    // Act
    test.run();

    // Assert
    assert(test.errorCode() == 0x00, test.errorText());
}
*/

/// 16-special.nes
unittest
{
    // Arrange
    rom = new ROM("roms/instr_test-v5/rom_singles/16-special.nes");
    cpu = new CPU(false);
    ppu = new PPU(true);
    auto test = new BlarggCPUTest();

    // Act
    test.run();

    // Assert
    assert(test.errorCode() == 0x00, test.errorText());
}
