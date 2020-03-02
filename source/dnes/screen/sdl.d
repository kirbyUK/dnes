module dnes.screen.sdl;

import std.ascii;
import std.exception;
import std.format;
import std.string;

import bindbc.sdl;
import loader = bindbc.loader.sharedlib;

/**
 * Performs the initial load of the SDL library
 *
 * Throws: SDLLoadException if the library cannot be loaded
 */
void initialiseSDL()
{
    const auto ret = loadSDL();
    if (ret != sdlSupport)
        throw new SDLLoadException(loader.errors);
}


/**
 * An exception representing errors when loading SDL
 */
class SDLLoadException : Exception
{
    /**
     * Constructor
     *
     * Params:
     *     errors: The loader errors
     */
    this(const loader.ErrorInfo[] errors)
    {
        auto error = format("Failed to load SDL library:%s", newline);
        foreach (info; errors)
        {
            error = error ~ format(
                "\t%s: %s%s",
                fromStringz(info.error),
                fromStringz(info.message),
                newline
            );
        }
        super(error, __FILE__, __LINE__);
    }
}

/**
 * An exception to represent errors within SDL
 */
class SDLException : Exception
{
    /**
     * Constructor
     *
     * Params:
     *     reason: String explaining what failed
     */
    this(string reason)
    {
        super(format("%s: %s", reason, fromStringz(SDL_GetError())), __FILE__, __LINE__);
    }
}