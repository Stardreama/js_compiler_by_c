# JavaScript 词法/语法分析器 Makefile
# 适用于 Windows + MinGW 环境

CC = gcc
CFLAGS = -Wall -g -std=c99
RE2C = re2c
BISON = bison

########################
# 目标可执行文件
########################
LEXER_TARGET  = js_lexer.exe
PARSER_TARGET = js_parser.exe

########################
# 源文件
########################
LEXER_SOURCES  = main.c lexer.c
LEXER_OBJECTS  = $(LEXER_SOURCES:.c=.o)

PARSER_SOURCES = parser.c parser_main.c parser_lex_adapter.c lexer.c
PARSER_OBJECTS = $(PARSER_SOURCES:.c=.o)

# 默认目标
all: $(LEXER_TARGET)

# 单独构建语法解析器
parser: $(PARSER_TARGET)

# 生成词法分析器 C 代码
lexer.c: lexer.re
	@echo "Generating lexer.c from lexer.re..."
	$(RE2C) -o lexer.c lexer.re

# 生成语法分析器 C 代码
parser.c parser.h: parser.y
	@echo "Generating parser.c/parser.h from parser.y..."
	$(BISON) -d -o parser.c parser.y

# 编译词法分析可执行程序
$(LEXER_TARGET): $(LEXER_OBJECTS)
	@echo "Linking $(LEXER_TARGET)..."
	$(CC) $(CFLAGS) -o $(LEXER_TARGET) $(LEXER_OBJECTS)
	@echo "Build complete: $(LEXER_TARGET)"

# 确保适配层在编译时已生成 parser.h
parser_lex_adapter.o: parser_lex_adapter.c parser.h token.h
	@echo "Compiling $<..."
	$(CC) $(CFLAGS) -c $< -o $@

# 明确依赖，避免并行/顺序导致缺少头文件
parser_main.o: parser_main.c parser.h
	@echo "Compiling $<..."
	$(CC) $(CFLAGS) -c $< -o $@

# 编译语法解析可执行程序
$(PARSER_TARGET): parser.h $(PARSER_OBJECTS)
	@echo "Linking $(PARSER_TARGET)..."
	$(CC) $(CFLAGS) -o $(PARSER_TARGET) $(PARSER_OBJECTS)
	@echo "Build complete: $(PARSER_TARGET)"

# 编译 .c 文件为 .o 文件
%.o: %.c token.h
	@echo "Compiling $<..."
	$(CC) $(CFLAGS) -c $< -o $@

# 清理生成的文件
clean:
	@echo "Cleaning up..."
	@rm -f lexer.c parser.c parser.h *.o $(LEXER_TARGET) $(PARSER_TARGET)
	@echo "Clean complete"

# 创建测试目录和示例文件
test-setup:
	@mkdir -p tests
	@printf "var x = 10;\n" > tests/test_basic.js
	@printf "let y = 20;\n" >> tests/test_basic.js
	@printf "const z = 30;\n" >> tests/test_basic.js
	@printf "function add(a, b) { return a + b; }\n" >> tests/test_basic.js
	@printf "console.log(\"Test complete\");\n" >> tests/test_basic.js
	@echo Test files created in tests/ directory

# 运行测试
test-lex: $(LEXER_TARGET) test-setup
	@echo.
	@echo === Running Lexer Test: tests/test_basic.js ===
	@./$(LEXER_TARGET) tests/test_basic.js
	@echo.

TEST_PARSE_FILES = \
	tests/test_basic.js \
	tests/test_simple.js \
	tests/test_asi_basic.js \
	tests/test_asi_return.js \
	tests/test_asi_control.js

test-parse: $(PARSER_TARGET)
	@for f in $(TEST_PARSE_FILES); do \
		if [ ! -f $$f ]; then \
			echo "Missing test file: $$f"; \
			exit 1; \
		fi; \
	done
	@for f in $(TEST_PARSE_FILES); do \
		echo "=== Running Parser Test: $$f ==="; \
		./$(PARSER_TARGET) $$f || exit $$?; \
		echo; \
	done

# 帮助信息
help:
	@echo JavaScript Lexer/Parser - Makefile Commands:
	@echo   make          - Build the lexer (default)
	@echo   make all      - Same as 'make'
	@echo   make clean    - Remove generated files
	@echo   make parser   - Build the parser (js_parser.exe)
	@echo   make test-lex - Build and run lexer against sample
	@echo   make test-parse - Build and run parser against sample
	@echo   make help     - Show this help message
	@echo.
	@echo Usage:
	@echo   ./js_lexer.exe filename.js
	@echo   ./js_parser.exe filename.js

.PHONY: all clean test-lex test-parse test-setup help parser

.PHONY: all clean test test-setup help
