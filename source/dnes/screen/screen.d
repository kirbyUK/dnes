module dnes.screen.screen;

import bindbc.sdl;

import dnes.ppu;
import dnes.screen.palette;
import dnes.sdl;

/**
 * Class representing the screen, which manages the SDL window the emulator
 * draws to
 */
class Screen
{
public:
    /**
     * Constructor
     *
     * Throws:
     *     SDLLoadException if the library cannot be loaded
     *     SDLException if an error occurs creating the window or texture
     */
    this()
    {
        if (SDL_Init(SDL_INIT_VIDEO) != 0)
            throw new SDLException("Error initialising SDL");

        _window = SDL_CreateWindow(
            windowTitle.ptr,
            SDL_WINDOWPOS_UNDEFINED,
            SDL_WINDOWPOS_UNDEFINED,
            width,
            height,
            SDL_WINDOW_SHOWN
        );
        if (_window == null)
            throw new SDLException("Error creating window");

        _renderer = SDL_CreateRenderer(
            _window,
            -1,
            SDL_RENDERER_ACCELERATED
        );
        if (_renderer == null)
            throw new SDLException("Error creating renderer");

        _texture = SDL_CreateTexture(
            _renderer,
            SDL_PIXELFORMAT_BGRA8888,
            SDL_TEXTUREACCESS_STREAMING,
            width,
            height
        );
        if (_texture == null)
            throw new SDLException("Error creating texture");
    }

    /**
     * Called by the PPU to allow it to draw a pixel to the screen
     *
     * Params:
     *     palette = The palette number to use
     *     x       = The x co-ordinate to draw to
     *     y       = The y co-ordinate to draw to
     */
    nothrow @safe @nogc void draw(ubyte palette, int x, int y)
    in (palette >= 0 && palette < savtoolsPalette.length)
    in (x >= 0 && x < width)
    in (y >= 0 && y < height)
    {
        _pixels[y][x] = savtoolsPalette[palette];
    }

    /**
     * Returns: True if the window closed event has been fired, otherwise false
     */
    nothrow @nogc bool closed() const
    {
        return _closed;
    }

    /**
     * Closes the window
     */
    nothrow @nogc void close()
    {
        SDL_DestroyTexture(_texture);
        SDL_DestroyRenderer(_renderer);
        SDL_DestroyWindow(_window);
        SDL_Quit();
    }

    /**
     * Signal handler for the PPU event signals
     *
     * Params:
     *     event = The event type being signalled
     */
    void ppuEventHandler(PPU.Event event)
    {
        switch (event)
        {
            case PPU.Event.FRAME:
                _processSDLEvents();
                _render();
                break;
            default: break;
        }
    }

private:
    /**
     * Enumerates all SDL events and acts on any we care about
     */
    nothrow @nogc void _processSDLEvents()
    {
        while (SDL_PollEvent(&_e) != 0)
        {
            // Determine if the window is closed
            if (_e.type == SDL_QUIT)
                _closed = true;
        }
    }

    /**
     * Draws a new frame
     *
     * Throws: SDLException if an error occurs rendering the frame
     */
    void _render()
    {
        if (SDL_UpdateTexture(
            _texture,
            null,
            cast(void*) _pixels.ptr,
            cast(int) (width * ARGB.sizeof)
        ) != 0)
            throw new SDLException("Error updating texture");

        if (SDL_RenderClear(_renderer) != 0)
            throw new SDLException("Error clearing renderer");

        if (SDL_RenderCopy(_renderer, _texture, null, null) != 0)
            throw new SDLException("Error copying texture to renderer");

        SDL_RenderPresent(_renderer);
    }


    immutable string windowTitle = "dnes";
    immutable int width = 256;
    immutable int height = 240;

    static bool _sdlLibraryLoaded = false;

    SDL_Window* _window;
    SDL_Renderer* _renderer;
    SDL_Texture* _texture;
    SDL_Event _e;
    bool _closed;

    ARGB[width][height] _pixels;
}

// Export a global variable
Screen screen = null;
