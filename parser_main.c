// JavaScript 语法解析器入口（不改变现有风格，独立于 js_lexer.exe）
// 用法：js_parser.exe <file.js>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// bison 生成的解析函数
int yyparse(void);

// 适配层提供：设置输入缓冲区
void parser_set_input(const char *input);

static char *read_file(const char *filename) {
    FILE *file = fopen(filename, "rb");
    if (!file) {
        fprintf(stderr, "Error: Cannot open file '%s'\n", filename);
        return NULL;
    }
    fseek(file, 0, SEEK_END);
    long size = ftell(file);
    fseek(file, 0, SEEK_SET);
    char *content = (char *)malloc(size + 1);
    if (!content) {
        fprintf(stderr, "Error: Memory allocation failed\n");
        fclose(file);
        return NULL;
    }
    size_t n = fread(content, 1, size, file);
    content[n] = '\0';
    fclose(file);
    return content;
}

int main(int argc, char **argv) {
    if (argc < 2) {
        printf("JavaScript Parser - Syntax Checker\n");
        printf("Usage: %s <javascript_file>\n", argv[0]);
        return 1;
    }

    const char *filename = argv[1];
    char *input = read_file(filename);
    if (!input) return 1;

    parser_set_input(input);

    int rc = yyparse();

    free(input);

    if (rc == 0) {
        printf("Parsing successful! Input file: %s\n", filename);
        return 0;
    } else {
        printf("Parsing failed. Input file: %s\n", filename);
        return 2;
    }
}
