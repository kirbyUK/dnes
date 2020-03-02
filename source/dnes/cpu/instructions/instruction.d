module dnes.cpu.instructions.instruction;

import std.exception;
import std.format;
import std.typecons;

/**
 * Class representing a single instruction.
 */
class Instruction
{
public:
    /**
     * Constructor
     *
     * Params:
     *     n = The opcode of the instruction
     *
     * Throws: UnknownInstructionException if an unknown opcode is passed
     */
    pure @safe this(ubyte n)
    {
        const auto pair = instructions[n];
        if (pair.isNull)
            throw new UnknownInstructionException(n);

        opcode = pair[0];
        addressing = pair[1];
    }

    /// The opcode of the instruction
    immutable Opcode opcode;

    /// The addressing mode used by the instruction
    immutable Addressing addressing;
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
    CLI, CLV, CMP, CPX, CPY, DEC, DEX, DEY, EOR, INC, INX, INY, JMP, JSR, LDA,
    LDX, LDY, LSR, NOP, ORA, PHA, PHP, PLA, PLP, ROL, ROR, RTI, RTS, SBC, SEC,
    SED, SEI, STA, STX, STY, TAX, TAY, TSX, TXA, TXS, TYA,
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

/// Alias for a nullable tuple of the opcode and addressing mode. Needs to be
/// nullable so that we can have 'gaps' in the big table (represented as a
/// default-initialised InstructionPair)
alias InstructionPair = Nullable!(Tuple!(Opcode, Addressing));

/// Table of opcodes to instructions
immutable InstructionPair[256] instructions = [
    tuple(Opcode.BRK, Addressing.IMP), // $00
    tuple(Opcode.ORA, Addressing.IDX), // $01
    InstructionPair.init,              // $02
    InstructionPair.init,              // $03
    InstructionPair.init,              // $04
    tuple(Opcode.ORA, Addressing.ZRP), // $05
    tuple(Opcode.ASL, Addressing.ZRP), // $06
    InstructionPair.init,              // $07
    tuple(Opcode.PHP, Addressing.IMP), // $08
    tuple(Opcode.ORA, Addressing.IMM), // $09
    tuple(Opcode.ASL, Addressing.IMP), // $0A
    InstructionPair.init,              // $0B
    InstructionPair.init,              // $0C
    tuple(Opcode.ORA, Addressing.ABS), // $0D
    tuple(Opcode.ASL, Addressing.ABS), // $0E
    InstructionPair.init,              // $0F
    tuple(Opcode.BPL, Addressing.REL), // $10
    tuple(Opcode.ORA, Addressing.IDY), // $11
    InstructionPair.init,              // $12
    InstructionPair.init,              // $13
    InstructionPair.init,              // $14
    tuple(Opcode.ORA, Addressing.ZRX), // $15
    tuple(Opcode.ASL, Addressing.ZRX), // $16
    InstructionPair.init,              // $17
    tuple(Opcode.CLC, Addressing.IMP), // $18
    tuple(Opcode.ORA, Addressing.INY), // $19
    tuple(Opcode.NOP, Addressing.IMP), // $1A
    InstructionPair.init,              // $1B
    InstructionPair.init,              // $1C
    tuple(Opcode.ORA, Addressing.INX), // $1D
    tuple(Opcode.ASL, Addressing.INX), // $1E
    InstructionPair.init,              // $1F
    tuple(Opcode.JSR, Addressing.ABS), // $20
    tuple(Opcode.AND, Addressing.IDX), // $21
    InstructionPair.init,              // $22
    InstructionPair.init,              // $23
    tuple(Opcode.BIT, Addressing.ZRP), // $24
    tuple(Opcode.AND, Addressing.ZRP), // $25
    tuple(Opcode.ROL, Addressing.ZRP), // $26
    InstructionPair.init,              // $27
    tuple(Opcode.PLP, Addressing.IMP), // $28
    tuple(Opcode.AND, Addressing.IMM), // $29
    tuple(Opcode.ROL, Addressing.IMP), // $2A
    InstructionPair.init,              // $2B
    tuple(Opcode.BIT, Addressing.ABS), // $2C
    tuple(Opcode.AND, Addressing.ABS), // $2D
    tuple(Opcode.ROL, Addressing.ABS), // $2E
    InstructionPair.init,              // $2F
    tuple(Opcode.BMI, Addressing.REL), // $30
    tuple(Opcode.AND, Addressing.IDY), // $31
    InstructionPair.init,              // $32
    InstructionPair.init,              // $33
    InstructionPair.init,              // $34
    tuple(Opcode.AND, Addressing.ZRX), // $35
    tuple(Opcode.ROL, Addressing.ZRX), // $36
    InstructionPair.init,              // $37
    tuple(Opcode.SEC, Addressing.IMP), // $38
    tuple(Opcode.AND, Addressing.INY), // $39
    tuple(Opcode.NOP, Addressing.IMP), // $3A
    InstructionPair.init,              // $3B
    InstructionPair.init,              // $3C
    tuple(Opcode.AND, Addressing.INX), // $3D
    tuple(Opcode.ROL, Addressing.INX), // $3E
    InstructionPair.init,              // $3F
    tuple(Opcode.RTI, Addressing.IMP), // $40
    tuple(Opcode.EOR, Addressing.IDX), // $41
    InstructionPair.init,              // $42
    InstructionPair.init,              // $43
    InstructionPair.init,              // $44
    tuple(Opcode.EOR, Addressing.ZRP), // $45
    tuple(Opcode.LSR, Addressing.ZRP), // $46
    InstructionPair.init,              // $47
    tuple(Opcode.PHA, Addressing.IMP), // $48
    tuple(Opcode.EOR, Addressing.IMM), // $49
    tuple(Opcode.LSR, Addressing.IMP), // $4A
    InstructionPair.init,              // $4B
    tuple(Opcode.JMP, Addressing.ABS), // $4C
    tuple(Opcode.EOR, Addressing.ABS), // $4D
    tuple(Opcode.LSR, Addressing.ABS), // $4E
    InstructionPair.init,              // $4F
    tuple(Opcode.BVC, Addressing.REL), // $50
    tuple(Opcode.EOR, Addressing.IDY), // $51
    InstructionPair.init,              // $52
    InstructionPair.init,              // $53
    InstructionPair.init,              // $54
    tuple(Opcode.EOR, Addressing.ZRX), // $55
    tuple(Opcode.LSR, Addressing.ZRX), // $56
    InstructionPair.init,              // $57
    tuple(Opcode.CLI, Addressing.IMP), // $58
    tuple(Opcode.EOR, Addressing.INY), // $59
    tuple(Opcode.NOP, Addressing.IMP), // $5A
    InstructionPair.init,              // $5B
    InstructionPair.init,              // $5C
    tuple(Opcode.EOR, Addressing.INX), // $5D
    tuple(Opcode.LSR, Addressing.INX), // $5E
    InstructionPair.init,              // $5F
    tuple(Opcode.RTS, Addressing.IMP), // $60
    tuple(Opcode.ADC, Addressing.IDX), // $61
    InstructionPair.init,              // $62
    InstructionPair.init,              // $63
    InstructionPair.init,              // $64
    tuple(Opcode.ADC, Addressing.ZRP), // $65
    tuple(Opcode.ROR, Addressing.ZRP), // $66
    InstructionPair.init,              // $67
    tuple(Opcode.PLA, Addressing.IMP), // $68
    tuple(Opcode.ADC, Addressing.IMM), // $69
    tuple(Opcode.ROR, Addressing.IMP), // $6A
    InstructionPair.init,              // $6B
    tuple(Opcode.JMP, Addressing.IND), // $6C
    tuple(Opcode.ADC, Addressing.ABS), // $6D
    tuple(Opcode.ROR, Addressing.ABS), // $6E
    InstructionPair.init,              // $6F
    tuple(Opcode.BVS, Addressing.REL), // $70
    tuple(Opcode.ADC, Addressing.IDY), // $71
    InstructionPair.init,              // $72
    InstructionPair.init,              // $73
    InstructionPair.init,              // $74
    tuple(Opcode.ADC, Addressing.ZRX), // $75
    tuple(Opcode.ROR, Addressing.ZRX), // $76
    InstructionPair.init,              // $77
    tuple(Opcode.SEI, Addressing.IMP), // $78
    tuple(Opcode.ADC, Addressing.INY), // $79
    tuple(Opcode.NOP, Addressing.IMP), // $7A
    InstructionPair.init,              // $7B
    InstructionPair.init,              // $7C
    tuple(Opcode.ADC, Addressing.INX), // $7D
    tuple(Opcode.ROR, Addressing.INX), // $7E
    InstructionPair.init,              // $7F
    InstructionPair.init,              // $80
    tuple(Opcode.STA, Addressing.IDX), // $81
    InstructionPair.init,              // $82
    InstructionPair.init,              // $83
    tuple(Opcode.STY, Addressing.ZRP), // $84
    tuple(Opcode.STA, Addressing.ZRP), // $85
    tuple(Opcode.STX, Addressing.ZRP), // $86
    InstructionPair.init,              // $87
    tuple(Opcode.DEY, Addressing.IMP), // $88
    InstructionPair.init,              // $89
    tuple(Opcode.TXA, Addressing.IMP), // $8A
    InstructionPair.init,              // $8B
    tuple(Opcode.STY, Addressing.ABS), // $8C
    tuple(Opcode.STA, Addressing.ABS), // $8D
    tuple(Opcode.STX, Addressing.ABS), // $8E
    InstructionPair.init,              // $8F
    tuple(Opcode.BCC, Addressing.REL), // $90
    tuple(Opcode.STA, Addressing.IDY), // $91
    InstructionPair.init,              // $92
    InstructionPair.init,              // $93
    tuple(Opcode.STY, Addressing.ZRX), // $94
    tuple(Opcode.STA, Addressing.ZRX), // $95
    tuple(Opcode.STX, Addressing.ZRY), // $96
    InstructionPair.init,              // $97
    tuple(Opcode.TYA, Addressing.IMP), // $98
    tuple(Opcode.STA, Addressing.INY), // $99
    tuple(Opcode.TXS, Addressing.IMP), // $9A
    InstructionPair.init,              // $9B
    InstructionPair.init,              // $9C
    tuple(Opcode.STA, Addressing.INX), // $9D
    InstructionPair.init,              // $9E
    InstructionPair.init,              // $9F
    tuple(Opcode.LDY, Addressing.IMM), // $A0
    tuple(Opcode.LDA, Addressing.IDX), // $A1
    tuple(Opcode.LDX, Addressing.IMM), // $A2
    InstructionPair.init,              // $A3
    tuple(Opcode.LDY, Addressing.ZRP), // $A4
    tuple(Opcode.LDA, Addressing.ZRP), // $A5
    tuple(Opcode.LDX, Addressing.ZRP), // $A6
    InstructionPair.init,              // $A7
    tuple(Opcode.TAY, Addressing.IMP), // $A8
    tuple(Opcode.LDA, Addressing.IMM), // $A9
    tuple(Opcode.TAX, Addressing.IMP), // $AA
    InstructionPair.init,              // $AB
    tuple(Opcode.LDY, Addressing.ABS), // $AC
    tuple(Opcode.LDA, Addressing.ABS), // $AD
    tuple(Opcode.LDX, Addressing.ABS), // $AE
    InstructionPair.init,              // $AF
    tuple(Opcode.BCS, Addressing.REL), // $B0
    tuple(Opcode.LDA, Addressing.IDY), // $B1
    InstructionPair.init,              // $B2
    InstructionPair.init,              // $B3
    tuple(Opcode.LDY, Addressing.ZRX), // $B4
    tuple(Opcode.LDA, Addressing.ZRX), // $B5
    tuple(Opcode.LDX, Addressing.ZRY), // $B6
    InstructionPair.init,              // $B7
    tuple(Opcode.CLV, Addressing.IMP), // $B8
    tuple(Opcode.LDA, Addressing.INY), // $B9
    tuple(Opcode.TSX, Addressing.IMP), // $BA
    InstructionPair.init,              // $BB
    tuple(Opcode.LDY, Addressing.INX), // $BC
    tuple(Opcode.LDA, Addressing.INX), // $BD
    tuple(Opcode.LDX, Addressing.INY), // $BE
    InstructionPair.init,              // $BF
    tuple(Opcode.CPY, Addressing.IMM), // $C0
    tuple(Opcode.CMP, Addressing.IDX), // $C1
    InstructionPair.init,              // $C2
    InstructionPair.init,              // $C3
    tuple(Opcode.CPY, Addressing.ZRP), // $C4
    tuple(Opcode.CMP, Addressing.ZRP), // $C5
    tuple(Opcode.DEC, Addressing.ZRP), // $C6
    InstructionPair.init,              // $C7
    tuple(Opcode.INY, Addressing.IMP), // $C8
    tuple(Opcode.CMP, Addressing.IMM), // $C9
    tuple(Opcode.DEX, Addressing.IMP), // $CA
    InstructionPair.init,              // $CB
    tuple(Opcode.CPY, Addressing.ABS), // $CC
    tuple(Opcode.CMP, Addressing.ABS), // $CD
    tuple(Opcode.DEC, Addressing.ABS), // $CE
    InstructionPair.init,              // $CF
    tuple(Opcode.BNE, Addressing.REL), // $D0
    tuple(Opcode.CMP, Addressing.IDY), // $D1
    InstructionPair.init,              // $D2
    InstructionPair.init,              // $D3
    InstructionPair.init,              // $D4
    tuple(Opcode.CMP, Addressing.ZRX), // $D5
    tuple(Opcode.DEC, Addressing.ZRX), // $D6
    InstructionPair.init,              // $D7
    tuple(Opcode.CLD, Addressing.IMP), // $D8
    tuple(Opcode.CMP, Addressing.INY), // $D9
    tuple(Opcode.NOP, Addressing.IMP), // $DA
    InstructionPair.init,              // $DB
    InstructionPair.init,              // $DC
    tuple(Opcode.CMP, Addressing.INX), // $DD
    tuple(Opcode.DEC, Addressing.INX), // $DE
    InstructionPair.init,              // $DF
    tuple(Opcode.CPX, Addressing.IMM), // $E0
    tuple(Opcode.SBC, Addressing.IDX), // $E1
    InstructionPair.init,              // $E3
    InstructionPair.init,              // $E3
    tuple(Opcode.CPX, Addressing.ZRP), // $E4
    tuple(Opcode.SBC, Addressing.ZRP), // $E5
    tuple(Opcode.INC, Addressing.ZRP), // $E6
    InstructionPair.init,              // $E7
    tuple(Opcode.INX, Addressing.IMP), // $E8
    tuple(Opcode.SBC, Addressing.IMM), // $E9
    tuple(Opcode.NOP, Addressing.IMP), // $EA
    tuple(Opcode.SBC, Addressing.IMM), // $EB
    tuple(Opcode.CPX, Addressing.ABS), // $EC
    tuple(Opcode.SBC, Addressing.ABS), // $ED
    tuple(Opcode.INC, Addressing.ABS), // $EE
    InstructionPair.init,              // $EF
    tuple(Opcode.BEQ, Addressing.REL), // $F0
    tuple(Opcode.SBC, Addressing.IDY), // $F1
    InstructionPair.init,              // $F2
    InstructionPair.init,              // $F3
    InstructionPair.init,              // $F4
    tuple(Opcode.SBC, Addressing.ZRX), // $F5
    tuple(Opcode.INC, Addressing.ZRX), // $F6
    InstructionPair.init,              // $F7
    tuple(Opcode.SED, Addressing.IMP), // $F8
    tuple(Opcode.SBC, Addressing.INY), // $F9
    tuple(Opcode.NOP, Addressing.IMP), // $FA
    InstructionPair.init,              // $FB
    InstructionPair.init,              // $FC
    tuple(Opcode.SBC, Addressing.INX), // $FD
    tuple(Opcode.INC, Addressing.INX), // $FE
    InstructionPair.init,              // $FF
];
