module dnes.util;

/**
 * Concatenates a high and low byte into a single word
 *
 * Params:
 *     lo = The low byte
 *     hi = The high byte
 *
 * Returns $XXYY, where $XX is the high byte, and $YY the low
 */
pure nothrow @safe @nogc ushort concat(ubyte lo, ubyte hi)
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
    return x % T.max;
}