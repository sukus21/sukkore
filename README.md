# sukkore
A game-project template, used in all of my games in some form.
Only main should be considered stable-ish.

### Tools used
 - RGBDS toolchain v0.5.2
 - hardware.inc
 - Visual Studio Code

### Building
 Assumes that `rgbasm`, `rgblink` and `rgbfix` are available globally on your system. Developed using v0.5.2, but other versions may work as well.
 To build the project, run `make`, and a file named `build.gb` will appear inside the `build` directory, assuming nothing goes wrong.