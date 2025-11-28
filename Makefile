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

.PHONY: all parser test clean distclean help toolchain-check debug-vars debug-path FORCE

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

# Helper to handle "make test <path>"
KNOWN_TARGETS := all parser test clean distclean help toolchain-check debug-vars debug-path FORCE
# Replace backslashes with forward slashes in arguments to avoid shell escaping issues
TEST_ARGS := $(subst \,/,$(filter-out $(KNOWN_TARGETS),$(MAKECMDGOALS)))

define RUN_TESTS_BODY
	RED='\033[0;31m'; \
	GREEN='\033[0;32m'; \
	BLUE='\033[0;34m'; \
	YELLOW='\033[1;33m'; \
	NC='\033[0m'; \
	files_list=$$files; \
	total=0; \
	for f in $$files_list; do total=$$((total+1)); done; \
	current=0; \
	passed=0; \
	failed=0; \
	echo ""; \
	printf "$${BLUE}Starting execution of $$total tests...$${NC}\n"; \
	echo "----------------------------------------------------------------------"; \
	for f in $$files_list; do \
		current=$$((current + 1)); \
		percent=$$((current * 100 / total)); \
		bar_len=20; \
		filled=$$((percent * bar_len / 100)); \
		empty=$$((bar_len - filled)); \
		bar="["; \
		i=0; while [ $$i -lt $$filled ]; do bar="$${bar}="; i=$$((i+1)); done; \
		if [ $$filled -lt $$bar_len ]; then bar="$${bar}>"; empty=$$((empty - 1)); fi; \
		i=0; while [ $$i -lt $$empty ]; do bar="$${bar}."; i=$$((i+1)); done; \
		bar="$${bar}]"; \
		fname=$$(basename "$$f"); \
		printf "$$bar $${YELLOW}%3d%%$${NC} %-35s " "$$percent" "$$fname"; \
		is_expected_error=0; \
		if echo "$$f" | grep -E "(test_error|temp)" > /dev/null; then \
			is_expected_error=1; \
		fi; \
		output=$$(./$(PARSER_TARGET) "$$f" 2>&1); \
		status=$$?; \
		if [ $$is_expected_error -eq 1 ]; then \
			if [ $$status -ne 0 ]; then \
				printf "$${GREEN}PASS$${NC} (Caught)\n"; \
				passed=$$((passed + 1)); \
			else \
				printf "$${RED}FAIL$${NC} (Unexpected Success)\n"; \
				failed=$$((failed + 1)); \
				echo "$$output" | sed 's/^/    /'; \
			fi; \
		else \
			if [ $$status -eq 0 ]; then \
				printf "$${GREEN}PASS$${NC}\n"; \
				passed=$$((passed + 1)); \
			else \
				printf "$${RED}FAIL$${NC}\n"; \
				failed=$$((failed + 1)); \
				echo "$$output" | sed 's/^/    /'; \
			fi; \
		fi; \
	done; \
	echo "----------------------------------------------------------------------"; \
	if [ $$failed -eq 0 ]; then \
		printf "$${GREEN}SUCCESS: All $$total tests passed.$${NC}\n"; \
	else \
		printf "$${RED}FAILURE: $$failed out of $$total tests failed.$${NC}\n"; \
		exit 1; \
	fi
endef

test: $(PARSER_TARGET)
	@if [ -z "$(TEST_ARGS)" ]; then \
		files=$$(find $(TEST_DIR) -type f); \
		if [ -z "$$files" ]; then \
			echo "No test files found under $(TEST_DIR)/"; \
			exit 1; \
		fi; \
		echo ""; \
		echo "================================================"; \
		echo "Running All Tests in $(TEST_DIR)/"; \
		echo "================================================"; \
		echo ""; \
		$(RUN_TESTS_BODY) \
	else \
		for target in $(TEST_ARGS); do \
			echo ""; \
			echo "================================================"; \
			echo "Running Tests in: $$target"; \
			echo "================================================"; \
			if [ -d "$$target" ]; then \
				files=$$(find "$$target" -type f); \
			elif [ -f "$$target" ]; then \
				files="$$target"; \
			else \
				echo "Error: Target '$$target' not found."; \
				exit 1; \
			fi; \
			if [ -z "$$files" ]; then \
				echo "No files found in $$target"; \
				continue; \
			fi; \
			$(RUN_TESTS_BODY) \
		done; \
	fi

# If we are running tests with arguments, silence the "No rule to make target" error for the arguments
ifneq (,$(findstring test,$(MAKECMDGOALS)))
%:
	@:
endif

FORCE:

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
