# sukkore
A game-project template, used in all of my games in some form.
Only the main branch should be considered stable-ish to use for new projects.
Other branches are either work-in-progress, dead stubs, or archivals of earlier versions of the core, that don't receive updates.

This code is meant to be cloned and modified to the needs of any project.
If you do decide to use it, credit would be appreciated, but is not required.

### Tools used:
- [RGBDS toolchain](https://rgbds.gbdev.io) (v0.8.0)
- [hardware.inc](https://github.com/gbdev/hardware.inc)
- [Visual Studio Code](https://code.visualstudio.com/)
- [Emulicious](https://emulicious.net/) + [Debug Adapter for VScode](https://marketplace.visualstudio.com/items?itemName=emulicious.emulicious-debugger)
- [Python](https://www.python.org/)

## Building:
Assumes that `rgbasm`, `rgblink` and `rgbfix` are available in your `path` variable.
The project is developed using v0.8.0, but anything >= v0.7.0 should work.
To build the project, run the `build.py` python file, and a file named `build.gb` will appear inside the `build` directory.
