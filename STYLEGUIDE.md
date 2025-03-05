# Code conventions and style guide

The codestyle here follows the codestyle defined [Here](https://gbdev.io/guides/asmstyle.html).
There are a few alterations, so for simplicity, the most important parts are spelled out here.

## Naming convention
| Symbol type | Case convention |
|-|-|
| Instructions, registers, condition codes | lowercase |
| Labels | PascalCase |
| Constants | SCREAMING_SNAKE |
| Marcos | snake_case |
| Section declarations/names | UPPERCASE |
| Hexadecimal | UPPERCASE |

Symbols that are only used by a macro and shouldn't be tampered with outside of it, should have a double underscore (`__`) prefix (example: `DEF __ITERATION_COUNT = 0`). 

Labels are by default assumed to be in ROM. Any non-ROM labels must have a prefix, pointing out where they are located:

| Location | Prefix |
|-|-|
| WRAM | `w` |
| HRAM | `h` |
| SRAM | `s` |
| VRAM tileset | `vt` |
| VRAM tilemap | `vm` |
| RST/interrupt vector | `v` |

## Documentation
All exported labels should have appropriate docoumentation. This documentation must include a short description of what the label is for, and should contain appropriate "tags" (see list below). These tags show how the label is used, and warns of anything to watch out for.

If a label is for a routine, it must also specify what registers are saved when/if it returns. If no registers are listed, it is to be assumed that all registers are clobbered when the routine returns.

The expected parameters for the routine (registers, stack, reserved memory region...) should be specified in this documentation block as well, and should be as short as possible. The same applies to the routine's output (Stack pointer is assumed saved by default).

Here is a list of a few tags you might want to use:
* Lives in ROM0. *(if this tag is not present, label must be assumed to be in ROMX)*
* Assumes VRAM access.
* Does not return.
* Uses temporary variables.
* Disables/enables interrupts.

### Example of label documentation:
```asm
; Set the given IO register, and returns the old value.  
; Assumes palette access.  
; Lives in ROM0.
;
; Input:
; - `b`: New register value
; - `c`: I/O low-pointer ($FFXX)
;
; Returns:
; - `a`: Old value of IO register
;
; Saves: `f`, `bc`, `e`, `hl`  
; Destroys; `d`
PaletteSet::
    ldh a, [c]
    ld d, a
    ld a, b
    ldh [c], a
    ld a, d
    ret
;
```

## Indentation
Content under or "inside" a label, macro or `LOAD` section should always be indented, as you would with blocks in a high-level programming language. As ASM does not have end-block tokens, An empty comment may be used instead. This makes the code easier to visually parse, and helps your code editor with folding the code properly, if you're into that sort of thing.

Code "inside" sub-labels/anonymous labels may optionally be indented, if need be.

### Indentation example
```asm
; Documentation.
ClearBuffer::
    ld b, $80
    ld hl, w_buffer
    xor a
    .loop
        ld [hl+], a
        dec b
        jr nz, .loop
    ;
    ret
;
```

## Other one-off rules
* Files in the `source` directory should all be `.asm` files.
* The only files allowed in `INCLUDE` and `INCBIN` statements are those in the `include` durectory.
* Included files should only contain constant definitions and/or macros.
* Included files must not contain "raw data" (code/data added to ROM by just including the file). We have `RGBLINK` for cross-file code sharing, use it.
