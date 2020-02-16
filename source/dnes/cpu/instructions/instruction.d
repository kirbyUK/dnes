module dnes.cpu.instructions.instruction;

import std.exception;
import std.format;

/**
 * Class representing a single instruction.
 * Splits an instruction into a bitfield of its components for decoding, see
 * <http://nparker.llx.com/a2/opcodes.html>
 */
class Instruction
{
public:
    /**
     * Constructor
     *
     * Params:
     *     n = The byte of the instruction's opcode
     *
     * Throws: UnknownInstructionException when passed a byte that does not
     *         correspond to an instruction
     */
    pure @safe this(ubyte n)
    {
        _opcode = instructionOpcode(n);
        _addressing = addressingMode(n);
    }

    /**
     * Returns: The opcode of the instruction
     */
    @property pure nothrow @safe @nogc Opcode opcode() const
    {
        return _opcode;
    }

    /**
     * Returns: The addressing mode used by the instruction
     */
    @property pure nothrow @safe @nogc Addressing addressing() const
    {
        return _addressing;
    }

private:
    /// The opcode of the instruction
    immutable Opcode _opcode;

    /// The addressing mode used by the instruction
    immutable Addressing _addressing;
}

/**
 * Exception thrown when a byte that does not correspond to an instruction is
 * passed in
 */
class UnknownInstructionException : Exception
{
    /**
     * Constructor
     *
     * Params:
     *     opcode = The failing opcode
     */
    pure @safe this(ubyte opcode)
    {
        super(format("Unknown instruction: 0x%02X", opcode), __FILE__, __LINE__);
    }
}

/// Emumeration of instruction types
enum Opcode
{
    ADC, AND, ASL, BCC, BCS, BEQ, BIT, BMI, BNE, BPL, BRK, BVC, BVS, CLC, CLD,
    CLI, CLV, CMP, CPX, CPY, DEC, DEX, DEY, EOR, INC, INX, INY, JMP, JMP_ABS,
    JSR, JSR_ABS,  LDA, LDX, LDY, LSR, NOP, ORA, PHA, PHP, PLA, PLP, ROL, ROR,
    RTI, RTS, SBC, SEC, SED, SEI, STA, STX, STY, TAX, TAY, TSX, TXA, TXS, TYA,
}

/// Enumeration of addressing modes
enum Addressing
{
    ABS, // Absolute         - OPC $HHLL
    ZRP, // Zero Page        - OPC $LL
    INX, // Indexed X        - OPC $HHLL, X
    INY, // Indexed Y        - OPC $HHLL, Y
    ZRX, // Zero Page X      - OPC $LL, X
    ZRY, // Zero Page Y      - OPC $LL, Y
    IND, // Indirect         - OPC ($HHLL)
    IDY, // Indirect Indexed - OPC ($LL), Y
    IDX, // Indexed Indirect - OPC ($BB, X)
    IMM, // Immediate        - OPC #$BB
    IMP, // Implied          - OPC
    REL, // Relative         - OPC $BB
}

/**
 * Returns: The opcode of an instruction
 */
pure @safe Opcode instructionOpcode(ubyte n)
{
    const ubyte c = n & 0b00000011;
    const ubyte b = (n & 0b00011100) >> 2;
    const ubyte a = (n & 0b11100000) >> 5;

    switch (c)
    {
        case 0:
            switch (a)
            {
                case 1: return Opcode.BIT;
                case 2: return Opcode.JMP;
                case 3: return Opcode.JMP_ABS;
                case 4: return Opcode.STY;
                case 5: return Opcode.LDY;
                case 6: return Opcode.CPY;
                case 7: return Opcode.CPX;
                default: break;
            }
            break;
        case 1:
            final switch (a)
            {
                case 0: return Opcode.ORA;
                case 1: return Opcode.AND;
                case 2: return Opcode.EOR;
                case 3: return Opcode.ADC;
                case 4: return Opcode.STA;
                case 5: return Opcode.LDA;
                case 6: return Opcode.CMP;
                case 7: return Opcode.SBC;
            }
        case 2:
            final switch (a)
            {
                case 0: return Opcode.ASL;
                case 1: return Opcode.ROL;
                case 2: return Opcode.LSR;
                case 3: return Opcode.ROR;
                case 4: return Opcode.STX;
                case 5: return Opcode.LDX;
                case 6: return Opcode.DEC;
                case 7: return Opcode.INC;
            }
        default: break;
    }

    // If we did not find an instruction, then it could be a branch
    if ((b == 0b100) && (c == 0b00))
    {
        final switch (a)
        {
            case 0: return Opcode.BPL;
            case 1: return Opcode.BMI;
            case 2: return Opcode.BVC;
            case 3: return Opcode.BVS;
            case 4: return Opcode.BCC;
            case 5: return Opcode.BCS;
            case 6: return Opcode.BNE;
            case 7: return Opcode.BEQ;
        }
    }

    // Finally, the only other options we have a the miscellanous one-byte
    // instructions
    switch (n)
    {
        case 0x00: return Opcode.BRK;
        case 0x08: return Opcode.PHP;
        case 0x18: return Opcode.CLC;
        case 0x20: return Opcode.JSR_ABS;
        case 0x28: return Opcode.PLP;
        case 0x38: return Opcode.SEC;
        case 0x40: return Opcode.RTI;
        case 0x48: return Opcode.PHA;
        case 0x58: return Opcode.CLI;
        case 0x60: return Opcode.RTS;
        case 0x68: return Opcode.PLA;
        case 0x78: return Opcode.SEI;
        case 0x88: return Opcode.DEY;
        case 0x8A: return Opcode.TXA;
        case 0x98: return Opcode.TYA;
        case 0x9A: return Opcode.TXS;
        case 0xA8: return Opcode.TAY;
        case 0xAA: return Opcode.TAX;
        case 0xB8: return Opcode.CLV;
        case 0xBA: return Opcode.TSX;
        case 0xC8: return Opcode.INY;
        case 0xCA: return Opcode.DEX;
        case 0xD8: return Opcode.CLD;
        case 0xE8: return Opcode.INX;
        case 0xEA: return Opcode.NOP;
        case 0xF8: return Opcode.SED;
        default: break;
    }

    // If we've exhausted all options, then it is an unknown opcode
    throw new UnknownInstructionException(n);
}

/**
 * Returns: The addressing mode of an instruction
 */
pure nothrow @safe @nogc Addressing addressingMode(ubyte n)
{
    const ubyte c = n & 0b00000011;
    const ubyte b = (n & 0b00011100) >> 2;

    switch (c)
    {
        case 0:
            switch (b)
            {
                case 0: return Addressing.IMM;
                case 1: return Addressing.ZRP;
                case 3: return Addressing.ABS;
                case 5: return Addressing.ZRX;
                case 7: return Addressing.INX;
                default: break;
            }
            break;
        case 1:
            final switch (b)
            {
                case 0: return Addressing.IDX;
                case 1: return Addressing.ZRP;
                case 2: return Addressing.IMM;
                case 3: return Addressing.ABS;
                case 4: return Addressing.IDY;
                case 5: return Addressing.ZRX;
                case 6: return Addressing.INX;
                case 7: return Addressing.INY;
            }
        case 2:
            switch (b)
            {
                case 0: return Addressing.IMM;
                case 1: return Addressing.ZRP;
                case 2: return Addressing.IMP;
                case 3: return Addressing.ABS;
                case 5: return Addressing.ZRX;
                case 7: return Addressing.INX;
                default: break;
            }
            break;
        default: break;
    }

    return Addressing.IMP;
}