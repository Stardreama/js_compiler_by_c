// 解析器与现有 re2c 词法器的适配层
// 职责：将 token.h 中的 TokenType 映射为 Bison 的终结符，并提供 yylex()

#include <stdio.h>
#include <string.h>
#include "token.h"
#include "parser.h"  // 由 bison -d 生成，包含 VAR/LET/... 等 token 定义

static Lexer g_lexer;
static int g_initialized = 0;

// 由 parser_main.c 调用，设置输入缓冲区
void parser_set_input(const char *input) {
    lexer_init(&g_lexer, input);
    g_initialized = 1;
}

// bison 调用的词法函数
int yylex(void) {
    if (!g_initialized) {
        fprintf(stderr, "[lexer] not initialized\n");
        return 0; // 视为 EOF
    }

    while (1) {
        Token tk = lexer_next_token(&g_lexer);
        int ret = 0; // 返回给 bison 的 token 编号

        switch (tk.type) {
            // 关键字
            case TOK_VAR:        ret = VAR; break;
            case TOK_LET:        ret = LET; break;
            case TOK_CONST:      ret = CONST; break;
            case TOK_FUNCTION:   ret = FUNCTION; break;
            case TOK_IF:         ret = IF; break;
            case TOK_ELSE:       ret = ELSE; break;
            case TOK_FOR:        ret = FOR; break;
            case TOK_WHILE:      ret = WHILE; break;
            case TOK_DO:         ret = DO; break;
            case TOK_RETURN:     ret = RETURN; break;
            case TOK_BREAK:      ret = BREAK; break;
            case TOK_CONTINUE:   ret = CONTINUE; break;
            case TOK_SWITCH:     ret = SWITCH; break;
            case TOK_CASE:       ret = CASE; break;
            case TOK_DEFAULT:    ret = DEFAULT; break;
            case TOK_TRY:        ret = TRY; break;
            case TOK_CATCH:      ret = CATCH; break;
            case TOK_FINALLY:    ret = FINALLY; break;
            case TOK_THROW:      ret = THROW; break;
            case TOK_NEW:        ret = NEW; break;
            case TOK_THIS:       ret = THIS; break;
            case TOK_TYPEOF:     ret = TYPEOF; break;
            case TOK_DELETE:     ret = DELETE; break;
            case TOK_IN:         ret = IN; break;
            case TOK_INSTANCEOF: ret = INSTANCEOF; break;
            case TOK_VOID:       ret = VOID; break;
            case TOK_WITH:       ret = WITH; break;
            case TOK_DEBUGGER:   ret = DEBUGGER; break;

            // 字面量/标识符
            case TOK_TRUE:       ret = TRUE; break;
            case TOK_FALSE:      ret = FALSE; break;
            case TOK_NULL:       ret = NULL_T; break;
            case TOK_UNDEFINED:  ret = UNDEFINED; break;
            case TOK_NUMBER:     ret = NUMBER; break;
            case TOK_STRING:     ret = STRING; break;
            case TOK_IDENTIFIER: ret = IDENTIFIER; break;

            // 复合运算符与关系/逻辑
            case TOK_PLUS_PLUS:  ret = PLUS_PLUS; break;
            case TOK_MINUS_MINUS:ret = MINUS_MINUS; break;
            case TOK_EQ:         ret = EQ; break;
            case TOK_NE:         ret = NE; break;
            case TOK_EQ_STRICT:  ret = EQ_STRICT; break;
            case TOK_NE_STRICT:  ret = NE_STRICT; break;
            case TOK_LE:         ret = LE; break;
            case TOK_GE:         ret = GE; break;
            case TOK_AND:        ret = AND; break;
            case TOK_OR:         ret = OR; break;
            case TOK_LSHIFT:     ret = LSHIFT; break;
            case TOK_RSHIFT:     ret = RSHIFT; break;
            case TOK_URSHIFT:    ret = URSHIFT; break;
            case TOK_PLUS_ASSIGN:    ret = PLUS_ASSIGN; break;
            case TOK_MINUS_ASSIGN:   ret = MINUS_ASSIGN; break;
            case TOK_STAR_ASSIGN:    ret = STAR_ASSIGN; break;
            case TOK_SLASH_ASSIGN:   ret = SLASH_ASSIGN; break;
            case TOK_PERCENT_ASSIGN: ret = PERCENT_ASSIGN; break;
            case TOK_AND_ASSIGN:     ret = AND_ASSIGN; break;
            case TOK_OR_ASSIGN:      ret = OR_ASSIGN; break;
            case TOK_XOR_ASSIGN:     ret = XOR_ASSIGN; break;
            case TOK_LSHIFT_ASSIGN:  ret = LSHIFT_ASSIGN; break;
            case TOK_RSHIFT_ASSIGN:  ret = RSHIFT_ASSIGN; break;
            case TOK_URSHIFT_ASSIGN: ret = URSHIFT_ASSIGN; break;

            // 单字符运算符/分隔符：直接返回字符
            case TOK_PLUS:       ret = '+'; break;
            case TOK_MINUS:      ret = '-'; break;
            case TOK_STAR:       ret = '*'; break;
            case TOK_SLASH:      ret = '/'; break;
            case TOK_PERCENT:    ret = '%'; break;
            case TOK_ASSIGN:     ret = '='; break;
            case TOK_LT:         ret = '<'; break;
            case TOK_GT:         ret = '>' ; break;
            case TOK_NOT:        ret = '!'; break;
            case TOK_BIT_AND:    ret = '&'; break;
            case TOK_BIT_OR:     ret = '|'; break;
            case TOK_BIT_XOR:    ret = '^'; break;
            case TOK_BIT_NOT:    ret = '~'; break;
            case TOK_QUESTION:   ret = '?'; break;
            case TOK_COLON:      ret = ':'; break;
            case TOK_LPAREN:     ret = '('; break;
            case TOK_RPAREN:     ret = ')'; break;
            case TOK_LBRACE:     ret = '{'; break;
            case TOK_RBRACE:     ret = '}'; break;
            case TOK_LBRACKET:   ret = '['; break;
            case TOK_RBRACKET:   ret = ']'; break;
            case TOK_SEMICOLON:  ret = ';'; break;
            case TOK_COMMA:      ret = ','; break;
            case TOK_DOT:        ret = '.'; break;

            case TOK_EOF:
                token_free(&tk);
                return 0; // EOF

            case TOK_ERROR:
            default:
                fprintf(stderr, "Lexical error at line %d, column %d\n", tk.line, tk.column);
                token_free(&tk);
                return 0; // 终止解析
        }

        // 释放 token 持有的字符串，解析阶段不保留语义值
        token_free(&tk);
        return ret;
    }
}

// bison 的错误回调在 parser.y 中实现，这里不重复实现
