module dnes.test.nestest;

import std.conv;
import std.format;
import std.regex;
import std.stdio;

import dnes.cpu;
import dnes.ppu;
import dnes.rom;
import dnes.test.itest;

/**
 * ITest implementation for the nestest.nes ROM
 */
class Nestest : ITest
{
public:
    /**
     * Constructor
     *
     * Params:
     *     log = Path to the nestest.log file
     */
    this(string log)
    {
        _instructionReferenceLog = new InstructionLog[0];
        _failureString = "";
        _passed = false;
        _executedInstruction = false;

        // Parse the log file
        auto r = regex(r"([0-9A-F]{4}).+A:([0-9A-F]{2}) X:([0-9A-F]{2}) Y:([0-9A-F]{2}) " ~
                       r"P:([0-9A-F]{2}) SP:([0-9A-F]{2}) CYC:\s*(\d+) SL:\s*(-?\d+)");
        auto file = File(log);
        foreach (line; file.byLine())
        {
            const auto match = matchFirst(line, r);
            if (!match.empty())
            {
                const InstructionLog i = {
                    addr: to!ushort(match[1], 16),
                    a: to!ubyte(match[2], 16),
                    x: to!ubyte(match[3], 16),
                    y: to!ubyte(match[4], 16),
                    p: to!ubyte(match[5], 16),
                    sp: to!ubyte(match[6], 16),
                    cyc: to!int(match[7]),
                    sl: to!int(match[8]),
                };
                _instructionReferenceLog ~= i;
            }
            else
                assert(false, format("Not a match:\n%s", line));
        }
        file.close();
    }

    /**
     * Implentation of run() that runs the test until either an illegal
     * instruction is called (which is considered a pass), or the state of the
     * emulation desyncronises from the log, which is considered a failure
     */
    void run()
    {
        // Initialise the CPU values
        cpu.pc = 0xc000;
        cpu.status = 0x24;
        _cpuState = cpuStateToInstructionLog();

        // Register the signal listener that will determine when the CPU
        // executes a full instruction
        cpu.connect(&this.cpuFinishesInstructionWatcher);

        // Run until the test tries to execute an illegal instruction, which
        // we will consider a pass for now
        int instruction = 0;
        try
        {
            while (_cpuState == _instructionReferenceLog[instruction])
            {
                while (!_executedInstruction)
                {
                    cpu.tick();
                    ppu.tick();
                    ppu.tick();
                    ppu.tick();
                }
                instruction++;
                _executedInstruction = false;
            }

            // If we exit the loop here, the log state and the CPU state have
            // desynchronised, so construct the error string and fail the test
            const auto instr = _instructionReferenceLog[instruction];
            _failureString = format(
                "Desynchronisation at instruction %d\n" ~
                "[LOG]  PC:%04X A:%02X X:%02X Y:%02X P:%02X SP:%02X CYC:%d SL:%d\n" ~
                "[DNES] PC:%04X A:%02X X:%02X Y:%02X P:%02X SP:%02X CYC:%d SL:%d\n",
                instruction,
                instr.addr, instr.a, instr.x, instr.y, instr.p, instr.sp, instr.cyc, instr.sl,
                _cpuState.addr, _cpuState.a, _cpuState.x, _cpuState.y, _cpuState.p, _cpuState.sp,
                _cpuState.cyc, _cpuState.sl
            );
        }
        catch (UnknownInstructionException)
        {
            _passed = true;
        }
    }

    /**
     * Returns: True if the test passed, otherwise false
     */
    nothrow @safe @nogc bool passed() const
    {
        return _passed;
    }

    /**
     * Returns: The test failure string
     */
    nothrow @safe @nogc string failureString() const
    {
        return _failureString;
    }

private:
    /**
     * Returns: The current CPU state as an InstructionLog
     */
    InstructionLog cpuStateToInstructionLog()
    {
        return InstructionLog(
            cpu.pc,
            cpu.acc,
            cpu.x,
            cpu.y,
            cpu.status,
            cpu.sp,
            ppu.cycles,
            ppu.scanline == 261 ? -1 : ppu.scanline
        );
    }

    /**
     * Signal listener to determine when the CPU finishes an instruction
     */
    void cpuFinishesInstructionWatcher(CPU.Event event)
    {
        if (event == CPU.Event.INSTRUCTION)
        {
            _executedInstruction = true;
            _cpuState = cpuStateToInstructionLog();
        }
    }

    /**
     * Representation of one entry from the log
     */
    struct InstructionLog
    {
        ushort addr;
        ubyte a;
        ubyte x;
        ubyte y;
        ubyte p;
        ubyte sp;
        int cyc;
        int sl;
    }
    InstructionLog[] _instructionReferenceLog;
    InstructionLog _cpuState;

    bool _passed;
    string _failureString;
    bool _executedInstruction;
}

unittest
{
    // Arrange
    rom = new ROM("roms/nestest/nestest.nes");
    cpu = new CPU(false);
    ppu = new PPU(true, 241);
    auto test = new Nestest("roms/nestest/nestest.log");

    // Act
    test.run();

    // Assert
    assert(test.passed() == true, test.failureString());
}