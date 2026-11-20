CC      := gcc
CFLAGS  := -std=c99 -D_POSIX_C_SOURCE=200809L -D_XOPEN_SOURCE=700 \
           -Wall -Wextra -Werror -Wno-unused-parameter -fno-asm \
           -Iinclude

SRC_DIR := src
OBJ_DIR := build
TARGET  := shell.out

SRCS := $(wildcard $(SRC_DIR)/*.c)
OBJS := $(patsubst $(SRC_DIR)/%.c,$(OBJ_DIR)/%.o,$(SRCS))

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) -o $@ $^

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.c | $(OBJ_DIR)
	$(CC) $(CFLAGS) -MMD -MP -c $< -o $@

$(OBJ_DIR):
	mkdir -p $(OBJ_DIR)

clean:
	rm -rf $(OBJ_DIR) $(TARGET)

-include $(OBJS:.o=.d)
