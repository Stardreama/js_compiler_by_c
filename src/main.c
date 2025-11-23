#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "token.h"

// 读取文件内容
char *read_file(const char *filename) {
    FILE *file = fopen(filename, "rb");
    if (!file) {
        fprintf(stderr, "Error: Cannot open file '%s'\n", filename);
        return NULL;
    }
    
    // 获取文件大小
    fseek(file, 0, SEEK_END);
    long size = ftell(file);
    fseek(file, 0, SEEK_SET);
    
    // 分配内存并读取
    char *content = (char *)malloc(size + 1);
    if (!content) {
        fprintf(stderr, "Error: Memory allocation failed\n");
        fclose(file);
        return NULL;
    }
    
    size_t read_size = fread(content, 1, size, file);
    content[read_size] = '\0';
    
    fclose(file);
    return content;
}

int main(int argc, char *argv[]) {
    // 检查命令行参数
    if (argc < 2) {
        printf("JavaScript Lexer - Test Program\n");
        printf("Usage: %s <javascript_file>\n", argv[0]);
        printf("\nExample:\n");
        printf("  %s test.js\n", argv[0]);
        return 1;
    }
    
    const char *filename = argv[1];
    
    // 读取输入文件
    char *input = read_file(filename);
    if (!input) {
        return 1;
    }
    
    printf("=== Lexical Analysis of '%s' ===\n\n", filename);
    
    // 初始化词法分析器
    Lexer lexer;
    lexer_init(&lexer, input);
    
    // 词法分析
    int token_count = 0;
    Token token;
    
    do {
        token = lexer_next_token(&lexer);
        token_count++;
        
        // 输出 token 信息
        printf("[%3d] Line %3d, Col %3d: %-15s", 
               token_count, token.line, token.column, 
               token_type_to_string(token.type));
        
        if (token.value) {
            printf(" = '%s'", token.value);
        }
        printf("\n");
        
        // 如果是错误 token，显示详细信息
        if (token.type == TOK_ERROR) {
            fprintf(stderr, "\nLexical Error at line %d, column %d: Unexpected character '%s'\n", 
                    token.line, token.column, token.value ? token.value : "");
            token_free(&token);
            break;
        }
        
        token_free(&token);
        
    } while (token.type != TOK_EOF && token.type != TOK_ERROR);
    
    printf("\n=== Analysis Complete ===\n");
    printf("Total tokens: %d\n", token_count);
    
    // 清理
    free(input);
    
    return (token.type == TOK_ERROR) ? 1 : 0;
}
