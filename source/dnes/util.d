module dnes.util;

import core.thread;

/**
 * Concatenates a high and low byte into a single word
 *
 * Params:
 *     hi = The high byte
 *     lo = The low byte
 *
 * Returns $XXYY, where $XX is the high byte, and $YY the low
 */
pure nothrow @safe @nogc ushort concat(ubyte hi, ubyte lo)
{
    return (hi << 8) | lo;
}

/**
 * Wraps around an integer to the size limitiation of the given type
 *
 * Params:
 *     x = The integer to wrap around
 *
 * Returns x wrapped around if it is larger than the maximum size of T
 */
pure nothrow @safe @nogc T wrap(T)(uint x)
{
    return x % (T.max + 1);
}

/**
 * Flips a given byte. For example, 0b00010010 becomes 0b01001000
 *
 * Params:
 *     b = The byte to flip
 *
 * Returns The passed byte flipped
 */
pure nothrow @safe @nogc ubyte flip(ubyte b)
{
    auto flipped = b;
    flipped = (flipped & 0xf0) >> 4 | (flipped & 0x0f) << 4;
    flipped = (flipped & 0xcc) >> 2 | (flipped & 0x33) << 2;
    flipped = (flipped & 0xaa) >> 1 | (flipped & 0x55) << 1;
    return flipped;
}