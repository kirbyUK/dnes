import std.getopt;
import std.stdio;
import std.typecons;

import dnes.cpu;
import dnes.ppu;
import dnes.rom;

/**
 * Print program usage
 */
void usage(string self, GetoptResult result)
{
	defaultGetoptPrinter(
		"\n" ~ self ~ ": [OPTIONS] /path/to/rom.nes",
		result.options
	);
}

/**
 * Process commandline arguments
 *
 * Params:
 *     args = The program's commandline arguments
 * Returns: A 3-element tuple containing a boolean for if the program should
 *          exit, then the path to the ROM file, then a boolean for if logging
 *          should be enabled.
 */
Tuple!(bool, string, bool) processArgs(string[] args)
{
	auto log = false;
	auto result = getopt(args, "log", "Enable logging", &log);
	if (result.helpWanted)
	{
		usage(args[0], result);
		return tuple(true, "", false);
	}
	else if (args.length < 2)
	{
		writefln("Please supply a single ROM as an argument");
		return tuple(true, "", false);
	}
	else
	{
		return tuple(false, args[1], log);
	}
}

int main(string[] args)
{
	// Process commandline arguments
	immutable auto arg = processArgs(args);
	if (arg[0])
		return 1;

	// initialise sdl2
	// initialise screen
	
	// Load the ROM from the given file
	rom = new ROM(arg[1]);

	// Run the emulation
	auto ret = 0;
	cpu = new CPU(arg[2]);
	ppu = new PPU();
	try
	{
		while (true)
		{
			cpu.tick();
			ppu.tick();
			ppu.tick();
			ppu.tick();
		}
	}
	catch (UnknownInstructionException e)
	{
		writeln(e.msg);
		ret = 1;
	}

	// sdl cleanup

	return ret;
}
