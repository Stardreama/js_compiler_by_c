# Cross-platform Makefile for the JavaScript parser front-end

UNAME_S := $(shell uname -s 2>/dev/null)

MKDIR := mkdir

ifeq ($(OS),Windows_NT)
  EXE := .exe
  PATH_SEP := ;
else ifneq (,$(findstring MINGW,$(UNAME_S)))
  EXE := .exe
  PATH_SEP := :
else
  EXE :=
  PATH_SEP := :
endif

SRC_DIR   := src
TEST_DIR  := test
BUILD_DIR := build
GEN_DIR   := $(BUILD_DIR)/generated
OBJ_DIR   := $(BUILD_DIR)/obj
BIN_DIR   := $(CURDIR)/bin

LEXER_TARGET  := js_lexer$(EXE)
PARSER_TARGET := js_parser$(EXE)

# Toolchain auto-discovery
ifeq ($(OS),Windows_NT)
	# We have already added the tools to PATH in make.cmd, so we can just use their names.
	# This avoids issues with $(CURDIR) resolving incorrectly in some environments.
	DEFAULT_GCC_BIN  := gcc.exe
	DEFAULT_RE2C     := re2c.exe
	DEFAULT_BISON    := bison.exe
else
	DEFAULT_GCC_BIN  := $(BIN_DIR)/gcc$(EXE)
	DEFAULT_RE2C     := $(BIN_DIR)/re2c$(EXE)
	DEFAULT_BISON    := $(BIN_DIR)/bison$(EXE)
	export PATH := $(BIN_DIR)$(PATH_SEP)$(PATH)
endif

GCC_BIN ?= $(DEFAULT_GCC_BIN)
RE2C    ?= $(DEFAULT_RE2C)
BISON   ?= $(DEFAULT_BISON)

CC     := $(GCC_BIN)
CFLAGS ?= -Wall -g -std=c99
CFLAGS += -I$(SRC_DIR) -I$(GEN_DIR)
LDFLAGS ?=

LEXER_C   := $(GEN_DIR)/lexer.c
PARSER_C  := $(GEN_DIR)/parser.c
PARSER_H  := $(GEN_DIR)/parser.h

LEXER_OBJECTS := \
  $(OBJ_DIR)/main.o \
  $(OBJ_DIR)/lexer.o

PARSER_OBJECTS := \
  $(OBJ_DIR)/parser_main.o \
  $(OBJ_DIR)/parser_lex_adapter.o \
  $(OBJ_DIR)/lexer.o \
  $(OBJ_DIR)/parser.o \
  $(OBJ_DIR)/ast.o

TEST_FILES := $(wildcard $(TEST_DIR)/*.js)

.PHONY: all parser test clean distclean help toolchain-check debug-vars debug-path

all: $(LEXER_TARGET) $(PARSER_TARGET)

parser: $(PARSER_TARGET)

toolchain-check:
	@echo "Shell PATH: $$PATH"
	@for tool in "$(CC)" "$(RE2C)" "$(BISON)"; do \
		if ! command -v $$tool >/dev/null 2>&1; then \
			echo "error: missing tool $$tool. Ensure it is in your PATH or under $(BIN_DIR)."; \
			exit 1; \
		fi; \
	done

$(LEXER_TARGET): $(GEN_DIR) $(OBJ_DIR) $(LEXER_OBJECTS)
	@echo "Linking $@"
	$(CC) $(CFLAGS) -o $@ $(LEXER_OBJECTS) $(LDFLAGS)
	@echo "Build complete: $@"

$(PARSER_TARGET): $(GEN_DIR) $(OBJ_DIR) $(PARSER_OBJECTS)
	@echo "Linking $@"
	$(CC) $(CFLAGS) -o $@ $(PARSER_OBJECTS) $(LDFLAGS)
	@echo "Build complete: $@"

$(OBJ_DIR)/main.o: $(SRC_DIR)/main.c $(SRC_DIR)/token.h | $(OBJ_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJ_DIR)/parser_main.o: $(SRC_DIR)/parser_main.c $(PARSER_H) $(SRC_DIR)/ast.h | $(OBJ_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJ_DIR)/parser_lex_adapter.o: $(SRC_DIR)/parser_lex_adapter.c $(PARSER_H) $(SRC_DIR)/token.h | $(OBJ_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJ_DIR)/ast.o: $(SRC_DIR)/ast.c $(SRC_DIR)/ast.h | $(OBJ_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJ_DIR)/lexer.o: $(LEXER_C) $(SRC_DIR)/token.h | $(OBJ_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJ_DIR)/parser.o: $(PARSER_C) $(PARSER_H) | $(OBJ_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(LEXER_C): $(SRC_DIR)/lexer.re | $(GEN_DIR)
	@tool="$(RE2C)"; if ! command -v "$$tool" >/dev/null 2>&1; then \
		echo "error: missing re2c binary $$tool. Ensure it is in your PATH."; \
		exit 1; \
	fi
	"$(RE2C)" -o $@ $<

$(PARSER_C) $(PARSER_H): $(SRC_DIR)/parser.y | $(GEN_DIR)
	@tool="$(BISON)"; if ! command -v "$$tool" >/dev/null 2>&1; then \
		echo "error: missing bison binary $$tool. Ensure it is in your PATH."; \
		exit 1; \
	fi
	"$(BISON)" -d -o $(PARSER_C) $<

$(GEN_DIR):
	@$(MKDIR) -p $@

$(OBJ_DIR):
	@$(MKDIR) -p $@

test: $(PARSER_TARGET)
	@if [ -z "$(TEST_FILES)" ]; then \
		echo "No test files found under $(TEST_DIR)/"; \
		exit 1; \
	fi
	@echo ""
	@echo "================================================"
	@echo "Running All Tests in $(TEST_DIR)/"
	@echo "================================================"
	@echo ""
	@total=0; passed=0; failed=0; \
	for f in $(TEST_FILES); do \
		total=$$((total + 1)); \
		echo "Running parser test: $$f"; \
		if echo "$$f" | grep "error" > /dev/null; then \
			if ./$(PARSER_TARGET) $$f; then \
				echo "  [result] FAIL (Expected error, but parsed successfully)"; \
				failed=$$((failed + 1)); \
			else \
				echo "  [result] PASS (Expected error caught)"; \
				passed=$$((passed + 1)); \
			fi; \
		else \
			if ./$(PARSER_TARGET) $$f; then \
				echo "  [result] PASS"; \
				passed=$$((passed + 1)); \
			else \
				echo "  [result] FAIL"; \
				failed=$$((failed + 1)); \
			fi; \
		fi; \
	done; \
	echo ""; \
	echo "================================================"; \
	echo "Test Results Summary"; \
	echo "================================================"; \
	echo "Total files:     $$total"; \
	echo "Passed:          $$passed"; \
	echo "Failed:          $$failed"; \
	echo "================================================"; \
	echo ""; \
	if [ $$failed -gt 0 ]; then \
		echo "TEST SUITE FAILED - $$failed test(s) failed"; \
		exit 1; \
	else \
		echo "TEST SUITE PASSED - All $$passed test(s) passed"; \
	fi

clean:
	@echo "Cleaning build artifacts"
	@rm -rf $(BUILD_DIR) $(LEXER_TARGET) $(PARSER_TARGET)

distclean: clean
	@echo "Removing generated intermediates"
	@rm -rf $(TEST_DIR)/tmp

help:
	@echo "Available targets:"
	@echo "  make            Build $(LEXER_TARGET)"
	@echo "  make parser     Build $(PARSER_TARGET)"
	@echo "  make test       Run parser regression tests"
	@echo "  make clean      Remove build outputs"
	@echo "  make distclean  Perform clean plus extra temp removal"

debug-vars:
	@echo "CURDIR=$(CURDIR)"
	@echo "BIN_DIR=$(BIN_DIR)"
	@echo "MSYS_USER_BIN=$(MSYS_USER_BIN)"
	@echo "SHELL=$(SHELL)"

debug-path:
	@cmd //c echo %PATH%
