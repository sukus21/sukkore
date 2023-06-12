# Entitysystem documentation

## Memory layout
An entity can have 3 different sizes: 1 chunk, 2 chunks and 4 chunks. A chunk is 16 bytes. All of an entity's memory exists in the same page.

The layout of an entity is as follows:
| byte(s) | name | purpose |
|---------|------|---------|
| 0x00 | bank | Which ROM-bank the entity has its code/data in. Cannot be ROM0, as bank #0 means the entity is not in use, and won't execute code. |
| 0x01 | size | Size of this entity slot in bytes. This is used both when allocated and when available, to figure out what can be allocated here. Default is `$40`. |
| 0x02-0x03 | code | Pointer to the code (within the entity's bank) to jump to, when executing its code. |
| 0x04-0x05 | extra data | Extended data pointer. Pointer to data/methods, that aren't important enough to be stored on the entity itself. This memory should also be within the entity's bank. |
| 0x06 | state | State of the entity. What this byte means, is up to the entity's code. |
| 0x07 | flags (physics) | Physics related flags. For non-physics entities, this byte (and the following bytes) can be used for whatever you want. |
| 0x08-0x09 | X-position (physics) | X-position for physics entities. Note that this is stored as big endian, where byte 8 is the most significant byte, and byte 9 is the least significant. |
| 0x0A-0x0B | Y-position (physics) | Y-position for physics entities. Big endian. |
| 0x0C | X-speed (physics) | Horizontal speed for physics entities. Which direction this speed is applied in, is dictated by the `flags` variable. |
| 0x0D | Y-speed (physics) | Vertical speed for physics entities. Which direction this speed is applied in, is dictated by the `flags` variable. |

Entities of bigger size can decide for themselves what to do with the extra space they allocate.

## Allocation
If next-pointer to entity slot if desired size is null, find a slot of a bigger size, and split that, until it reaches the requested size.
If a split does happen, allocate one side of the slot, and set the next-pointer to the other.

## Deallocation
Set ROM bank of the selected slot to 0, marking it as deallocated.
Check buddy-slot, if it is also empty, merge onto one slot, and set sizes accordingly.
If this slot was lower than the slot pointer, set the slot pointer to this slot.
