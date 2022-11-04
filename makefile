# Simple makefile for assembling and linking a .gb ROM
rwildcard		=	$(foreach d,$(wildcard $1*), $(call rwildcard,$d/,$2) $(filter $(subst *,%,$2),$d))

# RGBDS programs (assumed to be in PATH)
ASSEMBLER		:=	rgbasm
LINKER			:=	rgblink
FIXER			:=	rgbfix

# Project name/directory
PROJECT_NAME	:=	$(shell basename "$(CURDIR)")
HEADER_NAME		:=	$(shell echo $(PROJECT_NAME) | tr '[:lower:]' '[:upper:]')

# Project file directories
INC_DIR			:=	include/
SRC_DIR			:=	source
SRC_EXT			:= .asm
SRC_FILES		:=	$(call rwildcard, $(SRC_DIR)/, *$(SRC_EXT))

# Output files/directories
BUILD_DIR		:=	build
OUTPUT			:=	$(BUILD_DIR)/build
OUTPUT_EXT		:=	.gb

# Macros for assembly/linking
OBJ_FILES		:=	$(addprefix $(BUILD_DIR)/obj/, $(SRC_FILES:source/%$(SRC_EXT)=%.o))
OBJ_DIRS 		:=	$(sort $(addprefix $(BUILD_DIR)/obj/, $(dir $(SRC_FILES:source/%$(SRC_EXT)=%.o))))

# Flags for various programs
ASSEMBLER_FLAGS	:=	-p 255 -i $(INC_DIR)
FIXER_FLAGS		:=  -p 255 -v -c -t "$(HEADER_NAME)" -j -m 1



# Reserve task names
.PHONY: all clean fix

# All tasks run fix
all: fix

# Run RGBFIX on the ROM file
fix: $(OUTPUT)$(OUTPUT_EXT) $(OUTPUT).sym
	$(FIXER) $(FIXER_FLAGS) $(OUTPUT)$(OUTPUT_EXT)

# Link object files into ROM file
$(OUTPUT)$(OUTPUT_EXT): $(OBJ_FILES)
	$(LINKER) -p 255 -m "$(OUTPUT).map" -n "$(OUTPUT).sym" -o $(OUTPUT)$(OUTPUT_EXT) $(OBJ_FILES)

# Assembly source files into object files
$(BUILD_DIR)/obj/%.o : $(SRC_DIR)/%$(SRC_EXT) | $(OBJ_DIRS)
	$(ASSEMBLER) $(ASSEMBLER_FLAGS) -o $@ $<

# Create directories for object files
$(OBJ_DIRS):
	mkdir -p $@

# Cleanup function, removes build directory
clean:
	rm -rf $(BUILD_DIR)