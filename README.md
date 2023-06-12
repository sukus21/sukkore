# !!! ARCHIVAL BRANCH !!!
 **DO NOT USE THE CODE IN THIS BRANCH FOR ANY NEW PROJECTS!!!**
 
 This branch exists only for archival purposes. It is an insight into how the core looked while I was developing [GBC-spelunky](https://github.com/sukus21/GBC-spelunky). A lot has happened since, and this version of the core will no longer receive any updates.

# sukkore
 More or less a project template, used in some form in all of my games.

### Tools used
 - [RGBDS toolchain](https://rgbds.gbdev.io) (v0.5.2)
 - [hardware.inc](https://github.com/gbdev/hardware.inc)
 - [Visual Studio Code](https://code.visualstudio.com/)

### Building
 Assumes that `rgbasm`, `rgblink` and `rgbfix` are available globally on your system. Developed using v0.5.2, but other versions may work as well.
 To build the project, run `make`, and a file named `build.gb` will appear inside the `build` directory, assuming nothing goes wrong.