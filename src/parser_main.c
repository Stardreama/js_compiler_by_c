// JavaScript 语法解析器入口（不改变现有风格，独立于 js_lexer.exe）
// 用法：js_parser.exe <file.js>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// bison 生成的解析函数
int yyparse(void);
extern int yydebug;

// 适配层提供：设置输入缓冲区
void parser_set_input(const char *input);

#include "ast.h"
#include "diagnostics.h"

ASTNode *parser_take_ast(void);
void parser_reset_error_count(void);
int parser_error_count(void);
void parser_set_module_mode(int enabled);

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

int main(int argc, char **argv) {
    int dump_ast = 0;
    const char *filename = NULL;
    int module_mode = 1;

    for (int i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "--dump-ast") == 0) {
            dump_ast = 1;
        } else if (strcmp(argv[i], "--module") == 0) {
            module_mode = 1;
        } else if (strcmp(argv[i], "--script") == 0) {
            module_mode = 0;
        } else if (!filename) {
            filename = argv[i];
        } else {
            fprintf(stderr, "Unknown argument: %s\n", argv[i]);
            fprintf(stderr, "Usage: %s [--dump-ast] [--module|--script] <javascript_file>\n", argv[0]);
            return 1;
        }
    }

    if (!filename) {
        printf("JavaScript Parser - Syntax Checker\n");
        printf("Usage: %s [--dump-ast] [--module|--script] <javascript_file>\n", argv[0]);
        return 1;
    }

    char *input = read_file(filename);
    if (!input) return 1;

    diag_reset();
    diag_set_current_file(filename);
    const char *log_path = getenv("JS_PARSER_ERROR_LOG");
    diag_set_error_log_path(log_path);

    parser_reset_error_count();
    parser_set_module_mode(module_mode);
    parser_set_input(input);
    // if (getenv("JS_PARSER_TRACE")) {
    //     yydebug = 1;
    // }


    int rc = yyparse();
    ASTNode *root = parser_take_ast();
    int error_count = parser_error_count();

    free(input);

    if (rc == 0 && error_count == 0) {
        if (dump_ast && root) {
            printf("=== AST Dump ===\n");
            ast_print(root);
        }
    printf("[PASS] %s - no syntax errors detected.\n", filename);
        ast_free(root);
        return 0;
    }

    fprintf(stderr, "[FAIL] %s - %d syntax error%s detected. See messages above.\n",
            filename,
            error_count,
            error_count == 1 ? "" : "s");
    ast_free(root);
    return 2;
}
