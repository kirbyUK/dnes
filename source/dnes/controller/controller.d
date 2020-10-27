module dnes.controller.controller;

import bindbc.sdl;

import dnes.ppu;

/**
 * Class representing a standard, official controller
 */
class Controller
{
public:
    /**
     * Constructor
     */
    nothrow @safe @nogc this()
    {
        _current = 0;
    }

    /**
     * Called when the controller strobe register ($4016) is written to
     *
     * Params:
     *     value = The value written to the register
     */
    nothrow @safe @nogc void strobe(ubyte value)
    {
        _current = 0;
    }

    /**
     * Called when the controller 1 register ($4016) is read
     *
     * Returns: The byte describing a button press, depending on which read
     *          this is. Bit 7 is always high.
     */
    nothrow @safe @nogc ubyte read()
    out (r; r == 0x40 || r == 0x41)
    {
        // Any reads past the first 8 return 1 on official controllers
        if (_current > 7)
            return 0x41;

        return (_buttons[_current++] & 0x01) | 0x40;
    }

    /**
     * Signal handler for the PPU event signals
     *
     * Params:
     *     event = The event type being signalled
     */
    nothrow @nogc void ppuEventHandler(PPU.Event event)
    {
        switch (event)
        {
            case PPU.Event.FRAME:
                _getSDLKeys();
                break;
            default: break;
        }
    }

private:
    /**
     * Saves the state of the keyboard
     */
    nothrow @nogc void _getSDLKeys()
    {
        const ubyte* state = SDL_GetKeyboardState(null);
        _buttons[0] = state[SDL_SCANCODE_Z]; // A
        _buttons[1] = state[SDL_SCANCODE_X]; // B
        _buttons[2] = state[SDL_SCANCODE_S]; // Select
        _buttons[3] = state[SDL_SCANCODE_A]; // Start
        _buttons[4] = state[SDL_SCANCODE_UP];
        _buttons[5] = state[SDL_SCANCODE_DOWN];
        _buttons[6] = state[SDL_SCANCODE_LEFT];
        _buttons[7] = state[SDL_SCANCODE_RIGHT];
    }

    ubyte[8] _buttons;
    int _current;
}

// Export a global variable
Controller controller = null;