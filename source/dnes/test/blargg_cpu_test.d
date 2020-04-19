module dnes.test.blargg_cpu_test;

import std.format;

import dnes.cpu;
import dnes.ppu;
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
        while (!exit())
        {
            cpu.tick();
            ppu.tick();
            ppu.tick();
            ppu.tick();
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