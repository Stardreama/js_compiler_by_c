// JavaScript 语法解析器入口（不改变现有风格，独立于 js_lexer.exe）
// 用法：js_parser.exe <file.js>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

// bison 生成的解析函数
int yyparse(void);

// 适配层提供：设置输入缓冲区及词法错误查询
void parser_set_input(const char *input);
int parser_had_lex_error(void);

#include "ast.h"

ASTNode *parser_take_ast(void);
void parser_reset_error_count(void);
int parser_error_count(void);

static char *read_file(const char *filename) {
    FILE *file = fopen(filename, "rb");
    if (!file) {
        fprintf(stderr, "Error: Cannot open file '%s'\n", filename);
        return NULL;
    }
    fseek(file, 0, SEEK_END);
    long size = ftell(file);
    fseek(file, 0, SEEK_SET);

    // 追加换行符确保词法分析正确退出
    char *content = (char *)malloc(size + 2);
    if (!content) {
        fprintf(stderr, "Error: Memory allocation failed\n");
        fclose(file);
        return NULL;
    }

    size_t n = fread(content, 1, size, file);
    content[n] = '\n';
    content[n + 1] = '\0';

    fclose(file);
    return content;
}

static int equals_ignore_case(const char *a, const char *b) {
    while (*a && *b) {
        if (tolower((unsigned char)*a) != tolower((unsigned char)*b)) {
            return 0;
        }
        ++a;
        ++b;
    }
    return *a == '\0' && *b == '\0';
}

static int has_js_extension(const char *filename) {
    const char *dot = strrchr(filename, '.');
    if (!dot) {
        return 0;
    }
    if (equals_ignore_case(dot, ".js") ||
        equals_ignore_case(dot, ".mjs") ||
        equals_ignore_case(dot, ".cjs")) {
        return 1;
    }
    return 0;
}

int main(int argc, char **argv) {
    int dump_ast = 0;
    const char *filename = NULL;

    for (int i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "--dump-ast") == 0) {
            dump_ast = 1;
        } else if (!filename) {
            filename = argv[i];
        } else {
            fprintf(stderr, "Unknown argument: %s\n", argv[i]);
            fprintf(stderr, "Usage: %s [--dump-ast] <javascript_file>\n", argv[0]);
            return 1;
        }
    }

    if (!filename) {
        printf("JavaScript Parser - Syntax Checker\n");
        printf("Usage: %s [--dump-ast] <javascript_file>\n", argv[0]);
        return 1;
    }

    char *input = read_file(filename);
    if (!input) return 1;

    parser_reset_error_count();
    parser_set_input(input);

    int rc = yyparse();
    ASTNode *root = parser_take_ast();
    int error_count = parser_error_count();
    int lex_error = parser_had_lex_error();

    if (lex_error)
    {
        error_count += lex_error;
    }

    free(input);

    int has_valid_ext = has_js_extension(filename);

    if (rc == 0 && error_count == 0) {
        if (dump_ast && root) {
            printf("=== AST Dump ===\n");
            ast_print(root);
        }
        if (!has_valid_ext) {
            fprintf(stderr, "[WARN] %s - content parsed but file extension is not JS. Only .js/.mjs/.cjs are supported.\n", filename);
            ast_free(root);
            return 2;
        }
        printf("[PASS] %s - no syntax errors detected.\n", filename);
        ast_free(root);
        return 0;
    }

    fprintf(stderr, "[FAIL] %s - %d syntax error%s detected. See messages above.\n",
            filename,
            error_count,
            error_count == 1 ? "" : "s");
    if (!has_valid_ext) {
        fprintf(stderr, "[HINT] %s - unsupported file type (expected .js/.mjs/.cjs).\n", filename);
    }
    ast_free(root);
    return 2;
}
