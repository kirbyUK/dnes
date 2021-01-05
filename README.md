# dnes

A NES emulator written in D. Very much not finished yet.

## Building

Install a D compiler and `dub`, and then run

```
dub build
```

Which should pull in the dependencies for you and compile it. If you didn't
install the `dmd` compiler, you might need to use the `--compiler` flag.

## Usage

Currently it only runs mapper 0 games, and compatibility is limited. Here are
some games to try:

* [nestest.nes](http://nickmass.com/images/nestest.nes)
* [Micro Mages](https://morphcatgames.itch.io/micromages)
* Balloon Fight
* Donkey Kong
* Super Mario Bros
* Wrecking Crew

To run it, pass the path to the ROM file as the only argument:

```
./dnes roms/nestest/nestest.nes
```

Currently only player 1 is supported, and the controls are:

* `Z` - A
* `X` - B
* `A` - Start
* `S` - Select
* `Arrow keys` - D-Pad

## Tests

The tests run the emulator against the test ROMs provided in the repo. In the
project root, just run:

```
dub test
```

This should compile and run a seperate executable, `dnes-test.exe`, which runs
all the tests.