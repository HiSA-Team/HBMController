# Project name
PROJECT          := crosssim

# Directories and files
SRC              = src/
OBJ              = obj/
SRCS             = $(wildcard $(SRC)*.c)
OBJS             = $(addprefix $(OBJ), $(notdir $(SRCS:.c=.o)))
INC              = -Iinc

# Misc
RM               = rm -rf
MKDIR            = @mkdir -p $(@D)

# Compiler

# For Questa DPI, use the GCC bundled with Questa (or a compatible toolchain). Override: make CC=/path/to/gcc
CC               ?= gcc

# Flags
CFLAGS           := -c -fPIC
LDFLAGS          := -shared

all: bin/$(PROJECT).so

$(OBJ)%.o: $(SRC)%.c
	@echo "\n[OBJ]	Creating OBJs from src"
	$(MKDIR)
	$(CC) -o $@ $^ $(INC) $(CFLAGS)


bin/$(PROJECT).so: $(OBJS)
	@echo "\n[SO]	Creating Shared Object SO"
	$(MKDIR)
	$(CC) -o $@ $^ $(LDFLAGS)

clean:
	$(RM) obj
	$(RM) bin


.PHONY: all clean
