// 解析器与现有 re2c 词法器的适配层
// 职责：将 token.h 中的 TokenType 映射为 Bison 的终结符，并提供 yylex()

#include <stdio.h>
#include <string.h>
#include <stdbool.h>
#include "token.h"
#include "parser.h"  // 由 bison -d 生成，包含 VAR/LET/... 等 token 定义

static Lexer g_lexer;
static int g_initialized = 0;
static int g_last_token = 0;
static bool g_last_token_closed_control = false;
static int g_prev_token = 0;
static bool g_last_token_closed_function = false;

// 跟踪括号层级及控制语句的条件括号，用于避免在 if(...) 等后面误插入分号
#define CONTROL_STACK_MAX 64
static int g_paren_depth = 0;
static int g_control_stack[CONTROL_STACK_MAX];
static int g_control_top = 0;

// 用于标记哪些括号层级是属于 function(...) 的头部（和控制语句的控制栈类似）
static int g_paren_function_stack[CONTROL_STACK_MAX];
static int g_paren_function_top = 0;

typedef enum {
    BRACE_BLOCK,
    BRACE_OBJECT
} BraceKind;

static BraceKind g_brace_stack[CONTROL_STACK_MAX];
static int g_brace_top = 0;

static bool is_control_keyword(int token) {
    return token == IF || token == FOR || token == WHILE || token == WITH || token == SWITCH;
}

static void push_control_paren(void) {
    if (g_control_top < CONTROL_STACK_MAX) {
        g_control_stack[g_control_top++] = g_paren_depth;
    }
}

static void pop_control_paren_if_needed(void) {
    if (g_control_top > 0 && g_control_stack[g_control_top - 1] == g_paren_depth) {
        g_control_top--;
        g_last_token_closed_control = true;
    }
}

static void push_function_paren(void) {
    if (g_paren_function_top < CONTROL_STACK_MAX) {
        g_paren_function_stack[g_paren_function_top++] = g_paren_depth;
    }
}

static void pop_function_paren_if_needed(void) {
    if (g_paren_function_top > 0 && g_paren_function_stack[g_paren_function_top - 1] == g_paren_depth) {
        g_paren_function_top--;
        g_last_token_closed_function = true;
    }
}

static void update_token_state(int token) {
    g_last_token_closed_control = false;
    g_last_token_closed_function = false;

    if (token == '(') {
        // 先增加深度，确保栈中记录的是“括号内”的层级
        g_paren_depth++;

        // 检查是否为函数头部的括号
        // 情况A: function foo (...)  -> prev: FUNCTION, last: IDENTIFIER
        // 情况B: function (...)      -> last: FUNCTION (匿名函数)
        bool is_named_func = (g_prev_token == FUNCTION && g_last_token == IDENTIFIER);
        bool is_anon_func  = (g_last_token == FUNCTION);

        if (is_named_func || is_anon_func) {
            push_function_paren(); // 现在存入的是 increment 后的深度
        }

        // 3. 检查控制语句
        if (is_control_keyword(g_last_token)) {
            push_control_paren(); // 存入 increment 后的深度
        }

    } else if (token == ')') {
        if (g_paren_depth > 0) {
            // 先检查函数栈（如果匹配就设置函数关闭标志）
            pop_function_paren_if_needed();
            // 再检查控制语句栈
            pop_control_paren_if_needed();
            g_paren_depth--;
        }
    } else if (token == '{') {
        bool is_block = true;
        if (g_last_token > 0) {
            switch (g_last_token) {
                case IF:
                case ELSE:
                case FOR:
                case WHILE:
                case DO:
                case SWITCH:
                case TRY:
                case CATCH:
                case FINALLY:
                case WITH:
                case FUNCTION:
                case CASE:
                case DEFAULT:
                case ')':
                case ';':
                case '{':
                case '}':
                    is_block = true;
                    break;
                case ':':
                    if (g_brace_top > 0 && g_brace_stack[g_brace_top - 1] == BRACE_OBJECT) {
                        is_block = false;
                    } else {
                        is_block = true;
                    }
                    break;
                default:
                    is_block = false;
                    break;
            }
        }
        if (g_brace_top < CONTROL_STACK_MAX) {
            g_brace_stack[g_brace_top++] = is_block ? BRACE_BLOCK : BRACE_OBJECT;
        }
    } else if (token == '}') {
        if (g_brace_top > 0) {
            g_brace_top--;
        }
    }

    g_prev_token = g_last_token;
    g_last_token = token;
}

static bool is_restricted_token(int token) {
    return token == RETURN || token == BREAK || token == CONTINUE || token == THROW;
}

static bool can_end_statement(int token) {
    switch (token) {
        case IDENTIFIER:
        case NUMBER:
        case STRING:
        case REGEX:
        case TRUE:
        case FALSE:
        case NULL_T:
        case UNDEFINED:
        case ')':
        case ']':
        case '}':
        case PLUS_PLUS:
        case MINUS_MINUS:
            return true;
        default:
            return false;
    }
}

static bool suppress_newline_insertion(int token) {
    return token == '(' || token == '[' || token == '.';
}

static bool should_insert_semicolon(int last_token, bool last_closed_control, bool last_token_closed_function, int next_token, bool newline_before, bool is_eof) {
    if (last_token <= 0) {
        return false;
    }

    if (last_token == ';' || last_token == '{') {
        return false;
    }

    if (last_closed_control || last_token_closed_function) {
        return false;
    }

    if (is_restricted_token(last_token)) {
        if (newline_before || is_eof || next_token == '}') {
            return true;
        }
        return false;
    }

    if (!can_end_statement(last_token)) {
        return false;
    }

    if (is_eof) {
        return true;
    }

    if (next_token == '}') {
        bool is_block_closing = true;
        if (g_brace_top > 0) {
            is_block_closing = (g_brace_stack[g_brace_top - 1] == BRACE_BLOCK);
        }
        if (!is_block_closing) {
            return false;
        }
        return true;
    }

    if (newline_before && !suppress_newline_insertion(next_token) && next_token != ';') {
        return true;
    }

    return false;
}

static int convert_token_type(TokenType type) {
    switch (type) {
        case TOK_VAR:        return VAR;
        case TOK_LET:        return LET;
        case TOK_CONST:      return CONST;
        case TOK_FUNCTION:   return FUNCTION;
        case TOK_IF:         return IF;
        case TOK_ELSE:       return ELSE;
        case TOK_FOR:        return FOR;
        case TOK_WHILE:      return WHILE;
        case TOK_DO:         return DO;
        case TOK_RETURN:     return RETURN;
        case TOK_BREAK:      return BREAK;
        case TOK_CONTINUE:   return CONTINUE;
        case TOK_SWITCH:     return SWITCH;
        case TOK_CASE:       return CASE;
        case TOK_DEFAULT:    return DEFAULT;
        case TOK_TRY:        return TRY;
        case TOK_CATCH:      return CATCH;
        case TOK_FINALLY:    return FINALLY;
        case TOK_THROW:      return THROW;
        case TOK_NEW:        return NEW;
        case TOK_THIS:       return THIS;
        case TOK_TYPEOF:     return TYPEOF;
        case TOK_DELETE:     return DELETE;
        case TOK_IN:         return IN;
        case TOK_INSTANCEOF: return INSTANCEOF;
        case TOK_VOID:       return VOID;
        case TOK_WITH:       return WITH;
        case TOK_DEBUGGER:   return DEBUGGER;

        case TOK_TRUE:       return TRUE;
        case TOK_FALSE:      return FALSE;
        case TOK_NULL:       return NULL_T;
        case TOK_UNDEFINED:  return UNDEFINED;
        case TOK_NUMBER:     return NUMBER;
        case TOK_STRING:     return STRING;
        case TOK_REGEX:      return REGEX;
        case TOK_IDENTIFIER: return IDENTIFIER;

        case TOK_PLUS_PLUS:  return PLUS_PLUS;
        case TOK_MINUS_MINUS:return MINUS_MINUS;
        case TOK_EQ:         return EQ;
        case TOK_NE:         return NE;
        case TOK_EQ_STRICT:  return EQ_STRICT;
        case TOK_NE_STRICT:  return NE_STRICT;
        case TOK_LE:         return LE;
        case TOK_GE:         return GE;
        case TOK_AND:        return AND;
        case TOK_OR:         return OR;
        case TOK_LSHIFT:     return LSHIFT;
        case TOK_RSHIFT:     return RSHIFT;
        case TOK_URSHIFT:    return URSHIFT;
        case TOK_PLUS_ASSIGN:    return PLUS_ASSIGN;
        case TOK_MINUS_ASSIGN:   return MINUS_ASSIGN;
        case TOK_STAR_ASSIGN:    return STAR_ASSIGN;
        case TOK_SLASH_ASSIGN:   return SLASH_ASSIGN;
        case TOK_PERCENT_ASSIGN: return PERCENT_ASSIGN;
        case TOK_AND_ASSIGN:     return AND_ASSIGN;
        case TOK_OR_ASSIGN:      return OR_ASSIGN;
        case TOK_XOR_ASSIGN:     return XOR_ASSIGN;
        case TOK_LSHIFT_ASSIGN:  return LSHIFT_ASSIGN;
        case TOK_RSHIFT_ASSIGN:  return RSHIFT_ASSIGN;
        case TOK_URSHIFT_ASSIGN: return URSHIFT_ASSIGN;

        case TOK_PLUS:       return '+';
        case TOK_MINUS:      return '-';
        case TOK_STAR:       return '*';
        case TOK_SLASH:      return '/';
        case TOK_PERCENT:    return '%';
        case TOK_ASSIGN:     return '=';
        case TOK_LT:         return '<';
        case TOK_GT:         return '>';
        case TOK_NOT:        return '!';
        case TOK_BIT_AND:    return '&';
        case TOK_BIT_OR:     return '|';
        case TOK_BIT_XOR:    return '^';
        case TOK_BIT_NOT:    return '~';
        case TOK_QUESTION:   return '?';
        case TOK_COLON:      return ':';
        case TOK_LPAREN:     return '(';
        case TOK_RPAREN:     return ')';
        case TOK_LBRACE:     return '{';
        case TOK_RBRACE:     return '}';
        case TOK_LBRACKET:   return '[';
        case TOK_RBRACKET:   return ']';
        case TOK_SEMICOLON:  return ';';
        case TOK_COMMA:      return ',';
        case TOK_DOT:        return '.';

        case TOK_EOF:        return 0;

        case TOK_ERROR:
        default:
            return -1;
    }
}

typedef struct PendingToken {
    int token;
    YYSTYPE semantic;
    bool has_semantic;
    bool valid;
} PendingToken;

static PendingToken g_pending = {0};

// 由 parser_main.c 调用，设置输入缓冲区
void parser_set_input(const char *input) {
    lexer_init(&g_lexer, input);
    g_initialized = 1;
    g_last_token = 0;
    g_last_token_closed_control = false;
    g_paren_depth = 0;
    g_control_top = 0;
    g_pending.valid = false;
    g_brace_top = 0;
}

// bison 调用的词法函数
int yylex(void) {
    if (!g_initialized) {
        fprintf(stderr, "[lexer] not initialized\n");
        return 0; // 视为 EOF
    }

    if (g_pending.valid) {
        int tok = g_pending.token;
        if (g_pending.has_semantic) {
            yylval = g_pending.semantic;
            g_pending.has_semantic = false;
        } else {
            memset(&yylval, 0, sizeof(yylval));
        }
        g_pending.valid = false;
        update_token_state(tok);
        return tok;
    }

    while (1) {
        Token tk = lexer_next_token(&g_lexer);
        bool newline_before = g_lexer.has_newline;
        int mapped = convert_token_type(tk.type);
        bool is_eof = (tk.type == TOK_EOF);

        YYSTYPE semantic;
        memset(&semantic, 0, sizeof(semantic));
        bool has_semantic = false;

        if (tk.type == TOK_IDENTIFIER || tk.type == TOK_STRING || tk.type == TOK_NUMBER) {
            semantic.str = tk.value;
            tk.value = NULL;
            has_semantic = (semantic.str != NULL);
        }

        if (mapped < 0) {
            fprintf(stderr, "Lexical error at line %d, column %d\n", tk.line, tk.column);
            token_free(&tk);
            return 0;
        }

        token_free(&tk);

        if (should_insert_semicolon(g_last_token, g_last_token_closed_control, g_last_token_closed_function, mapped, newline_before, is_eof)) {
            g_pending.token = mapped;
            g_pending.valid = true;
            g_pending.has_semantic = has_semantic;
            if (has_semantic) {
                g_pending.semantic = semantic;
            }
            update_token_state(';');
            memset(&yylval, 0, sizeof(yylval));
            return ';';
        }

        if (has_semantic) {
            yylval = semantic;
        } else {
            memset(&yylval, 0, sizeof(yylval));
        }

        update_token_state(mapped);
        return mapped;
    }
}

// bison 的错误回调在 parser.y 中实现，这里不重复实现
