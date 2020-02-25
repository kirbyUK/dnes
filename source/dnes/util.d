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
    return x % T.max;
}

/**
 * Wraps a Fiber to continously call it and then yield when it does. This
 * allows a main Fiber to call sub-Fibers, and jump back up to the main Fiber's
 * caller when an inner one yields.
 *
 * Params:
 *     fiber = The Fiber to call
 */
void callFiber(Fiber fiber)
{
    while (fiber.state != Fiber.State.TERM)
    {
        fiber.call();
        if (fiber.state != Fiber.State.TERM)
            Fiber.yield();
    }
}