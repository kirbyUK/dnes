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

Currently it only runs [nestest.nes](http://nickmass.com/images/nestest.nes). To
do that:

```
./dnes --log nestest.nes
```

## Known issues

[ ] SBC implementation sets wrong flags
[ ] SBC implementation relies on deprecated negation behaviour
