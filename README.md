# sukkore
A game-project template, used in all of my games in some form.
Only the main branch should be considered stable-ish to use for new projects. Other branches are either work-in-progress, dead stubs, or archivals of earlier versions of the core, that don't receive updates.

### Tools used:
 - [RGBDS toolchain](https://rgbds.gbdev.io) (v0.6.1)
 - [hardware.inc](https://github.com/gbdev/hardware.inc)
 - [Visual Studio Code](https://code.visualstudio.com/)

### Building:
 Assumes that `rgbasm`, `rgblink` and `rgbfix` are available globally on your system. Developed using v0.6.1, but other versions may work as well.
 To build the project, run `make`, and a file named `build.gb` will appear inside the `build` directory, assuming nothing goes wrong.
 