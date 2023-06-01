# Project name(s)
PROJECT_NAME	:=	$(shell basename "$(CURDIR)")
HEADER_NAME		:=	$(shell echo $(PROJECT_NAME) | tr '[:lower:]' '[:upper:]')

# RGBDS programs (assumed to be in PATH)
ASSEMBLER		:=	rgbasm
LINKER			:=	rgblink
FIXER			:=	rgbfix

# Simple makefile for assembling and linking a .gb ROM
rwildcard		=	$(foreach d,$(wildcard $1*), $(call rwildcard,$d/,$2) $(filter $(subst *,%,$2),$d))

# Project file directories
INC_DIR			:=	include/
SRC_DIR			:=	source
SRC_EXT			:= .asm
SRC_FILES		:=	$(call rwildcard, $(SRC_DIR)/, *$(SRC_EXT))

# Output files/directories
OUTPUT_DIR		:=	build
OUTPUT			:=	$(OUTPUT_DIR)/build
OUTPUT_EXT		:=	.gb
OBJ_FILES		:=	$(addprefix $(OUTPUT_DIR)/obj/, $(SRC_FILES:source/%$(SRC_EXT)=%.o))
OBJ_DIRS 		:=	$(sort $(addprefix $(OUTPUT_DIR)/obj/, $(dir $(SRC_FILES:source/%$(SRC_EXT)=%.o))))

# Toolchain flags
ASSEMBLER_FLAGS	:=	-p 255 -H -i $(INC_DIR)
LINKER_FLAGS	:=	-p 255 -m "$(OUTPUT).map" -n "$(OUTPUT).sym"
FIXER_FLAGS		:=  -p 255 -v -t "$(HEADER_NAME)" -j -m MBC5


# Reserve task names
.PHONY: all clean fix

# All tasks run rgbfix
all: fix

# Run RGBFIX on the ROM file
fix: $(OUTPUT)$(OUTPUT_EXT) $(OUTPUT).sym
	$(FIXER) $(FIXER_FLAGS) $(OUTPUT)$(OUTPUT_EXT)

# Link object files into ROM file
$(OUTPUT)$(OUTPUT_EXT): $(OBJ_FILES)
	$(LINKER) $(LINKER_FLAGS) -o "$(OUTPUT)$(OUTPUT_EXT)" $(OBJ_FILES)

# Assembly source files into object files
$(OUTPUT_DIR)/obj/%.o : $(SRC_DIR)/%$(SRC_EXT) | $(OBJ_DIRS)
	$(ASSEMBLER) $(ASSEMBLER_FLAGS) -o $@ $<

# Create directories for object files
$(OBJ_DIRS):
	mkdir -p $@

# Cleanup function, removes build directory
clean:
	rm -rf $(OUTPUT_DIR)
