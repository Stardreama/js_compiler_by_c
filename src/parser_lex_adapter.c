// 解析器与现有 re2c 词法器的适配层
// 职责：将 token.h 中的 TokenType 映射为 Bison 的终结符，并提供 yylex()

#include <stdio.h>
#include <string.h>
#include <stdbool.h>
#include <stdlib.h>
#include "token.h"
#include "parser.h"  // 由 bison -d 生成，包含 VAR/LET/... 等 token 定义
#include "diagnostics.h"

extern int parser_is_module_mode(void);

extern void yyerror(const char *s);

static Lexer g_lexer;
static int g_initialized = 0;
static int g_last_token = 0;
static bool g_last_token_closed_control = false;
static int g_prev_token = 0;
static bool g_last_token_closed_function = false;
static bool g_last_token_closed_paren = false;
static bool g_skip_arrow_detection_once = false;
static bool g_async_allows_function_decl = false;

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
    BRACE_OBJECT,
    BRACE_FUNCTION
} BraceKind;

static BraceKind g_brace_stack[CONTROL_STACK_MAX];
static int g_brace_top = 0;
static bool g_pending_function_body = false;

static bool is_control_keyword(int token) {
    return token == IF || token == FOR || token == WHILE || token == WITH || token == SWITCH || token == CATCH;
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
        g_pending_function_body = true;
    }
}

static void update_token_state(int token) {
    g_last_token_closed_control = false;
    g_last_token_closed_function = false;
    g_last_token_closed_paren = false;

    if (token == '(') {
        // 先增加深度，确保栈中记录的是“括号内”的层级
        g_paren_depth++;

        // 检查是否为函数头部的括号
        // 情况A: function foo (...)  -> prev: FUNCTION, last: IDENTIFIER
        // 情况B: function (...)      -> last: FUNCTION (匿名函数)
        bool last_is_function = (g_last_token == FUNCTION || g_last_token == FUNCTION_DECL);
        bool prev_is_function = (g_prev_token == FUNCTION || g_prev_token == FUNCTION_DECL);
        bool is_named_func = (prev_is_function && g_last_token == IDENTIFIER);
        bool is_anon_func  = last_is_function;

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
            g_last_token_closed_paren = true;
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
                case FUNCTION_DECL:
                case CASE:
                case DEFAULT:
                case ')':
                case ';':
                case '{':
                case '}':
                case ARROW:
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
            BraceKind kind = is_block ? BRACE_BLOCK : BRACE_OBJECT;
            if (g_pending_function_body) {
                kind = BRACE_FUNCTION;
                g_pending_function_body = false;
            }
            g_brace_stack[g_brace_top++] = kind;
        }
    } else if (token == '}') {
        if (g_brace_top > 0) {
            BraceKind kind = g_brace_stack[--g_brace_top];
            if (kind == BRACE_FUNCTION) {
                g_last_token_closed_function = true;
            }
        }
    }

    g_prev_token = g_last_token;
    g_last_token = token;
}

static bool is_restricted_token(int token) {
    return token == RETURN || token == BREAK || token == CONTINUE || token == THROW || token == YIELD;
}

static bool newline_allowed_after_yield(int next_token, bool is_eof) {
    if (is_eof) {
        return true;
    }

    switch (next_token) {
        case ';':
        case '}':
        case ')':
        case ']':
        case ',':
        case ':':
            return true;
        default:
            return false;
    }
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
        case THIS:
        case SUPER:
        case TEMPLATE_NO_SUB:
        case TEMPLATE_TAIL:
        case DEFAULT:
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

static bool paren_starts_function_literal(void);

static bool suppress_newline_insertion(int token, bool paren_is_function_literal) {
    if (token == '(') {
        return !paren_is_function_literal;
    }

    switch (token) {
        case '[':
        case ')':
        case '.':
        case '?':
        case ':':
        case ARROW:
            return true;
        default:
            return false;
    }
}

static bool in_statement_context(void) {
    if (g_last_token == 0) {
        return true;
    }

    if (g_last_token_closed_control) {
        return true;
    }

    switch (g_last_token) {
        case ';':
        case '{':
        case '}':
        case ELSE:
        case DO:
        case FINALLY:
        case TRY:
        case CATCH:
        case CASE:
        case DEFAULT:
        case EXPORT:
            return true;
        default:
            return false;
    }
}

static bool should_insert_semicolon(int last_token, bool last_closed_control, bool last_token_closed_function, bool last_token_closed_paren, int next_token, bool newline_before, bool is_eof, bool next_starts_function_literal) {
    if (last_token <= 0) {
        return false;
    }

    if (last_token == ';' || last_token == '{') {
        return false;
    }

    if (last_closed_control) {
        return false;
    }

    if (last_token_closed_function) {
        if (next_token == '{' || next_token == '(' || next_token == '[' || next_token == '.') {
            return false;
        }
    }

    if (last_token_closed_paren && next_token == ARROW) {
        return false;
    }

    if (is_restricted_token(last_token)) {
        if (newline_before || is_eof || next_token == '}') {
            return true;
        }
        return false;
    }

	if (next_token == CATCH || next_token == FINALLY) {
        return false;
    }

    if (last_token == '}' && (next_token == ELSE || next_token == WHILE)) {
        return false;
    }

    if (!can_end_statement(last_token)) {
        return false;
    }

    if (is_eof) {
        return true;
    }

    if (next_token == '}') {
        if (g_brace_top > 0) {
            BraceKind kind = g_brace_stack[g_brace_top - 1];
            if (kind == BRACE_OBJECT) {
                return false; // object literal braces stay within expressions
            }
        }
        return true;
    }

    if (newline_before && next_token == '(' && next_starts_function_literal) {
        return true;
    }

    if (newline_before && !suppress_newline_insertion(next_token, next_starts_function_literal) && next_token != ';') {
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
        case TOK_CLASS:      return CLASS;
        case TOK_EXTENDS:    return EXTENDS;
        case TOK_SUPER:      return SUPER;
        case TOK_IMPORT:     return parser_is_module_mode() ? IMPORT : IDENTIFIER;
        case TOK_EXPORT:     return parser_is_module_mode() ? EXPORT : IDENTIFIER;
        case TOK_YIELD:      return YIELD;
        case TOK_ASYNC:      return ASYNC;
        case TOK_AWAIT:      return AWAIT;

        case TOK_TRUE:       return TRUE;
        case TOK_FALSE:      return FALSE;
        case TOK_NULL:       return NULL_T;
        case TOK_UNDEFINED:  return IDENTIFIER; //UNDEFINED 语法层面可以被看作ID TOKEN，但在语义上与ID不一致，
        case TOK_NUMBER:     return NUMBER;
        case TOK_STRING:     return STRING;
        case TOK_REGEX:      return REGEX;
        case TOK_IDENTIFIER: return IDENTIFIER;
        case TOK_TEMPLATE_NO_SUB: return TEMPLATE_NO_SUB;
        case TOK_TEMPLATE_HEAD:   return TEMPLATE_HEAD;
        case TOK_TEMPLATE_MIDDLE: return TEMPLATE_MIDDLE;
        case TOK_TEMPLATE_TAIL:   return TEMPLATE_TAIL;

        case TOK_PLUS_PLUS:  return PLUS_PLUS;
        case TOK_MINUS_MINUS:return MINUS_MINUS;
        case TOK_EQ:         return EQ;
        case TOK_NE:         return NE;
        case TOK_EQ_STRICT:  return EQ_STRICT;
        case TOK_NE_STRICT:  return NE_STRICT;
        case TOK_ARROW:      return ARROW;
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
        case TOK_ELLIPSIS:  return ELLIPSIS;

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

#define PENDING_QUEUE_MAX 32

typedef struct PendingToken {
    int token;
    YYSTYPE semantic;
    bool has_semantic;
    bool skip_arrow_detection;
} PendingToken;

static PendingToken g_pending_queue[PENDING_QUEUE_MAX];
static int g_pending_head = 0;
static int g_pending_tail = 0;

static bool pending_is_empty(void) {
    return g_pending_head == g_pending_tail;
}

static bool pending_pop(PendingToken *out) {
    if (pending_is_empty()) {
        return false;
    }
    *out = g_pending_queue[g_pending_head];
    g_pending_head = (g_pending_head + 1) % PENDING_QUEUE_MAX;
    return true;
}

static void pending_push(int token, const YYSTYPE *semantic, bool has_semantic, bool skip_arrow_detection) {
    int next_tail = (g_pending_tail + 1) % PENDING_QUEUE_MAX;
    if (next_tail == g_pending_head) {
        fprintf(stderr, "[parser_lex_adapter] pending queue overflow\n");
        exit(EXIT_FAILURE);
    }
    PendingToken *slot = &g_pending_queue[g_pending_tail];
    slot->token = token;
    if (has_semantic && semantic) {
        slot->semantic = *semantic;
    } else {
        memset(&slot->semantic, 0, sizeof(slot->semantic));
    }
    slot->has_semantic = has_semantic;
    slot->skip_arrow_detection = skip_arrow_detection;
    g_pending_tail = next_tail;
}

static bool lookahead_is_arrow_head(void) {
    Lexer snapshot = g_lexer;
    int depth = 1;

    while (depth > 0) {
        Token tk = lexer_next_token(&snapshot);
        if (tk.type == TOK_EOF || tk.type == TOK_ERROR) {
            token_free(&tk);
            return false;
        }

        if (tk.type == TOK_LPAREN) {
            depth++;
        } else if (tk.type == TOK_RPAREN) {
            depth--;
            if (depth == 0) {
                token_free(&tk);
                Token next = lexer_next_token(&snapshot);
                bool result = (next.type == TOK_ARROW);
                token_free(&next);
                return result;
            }
        }

        token_free(&tk);
    }

    return false;
}

static bool paren_starts_function_literal(void) {
    Lexer snapshot = g_lexer;
    Token next = lexer_next_token(&snapshot);
    bool starts_function = (next.type == TOK_FUNCTION);
    token_free(&next);
    return starts_function;
}

// 由 parser_main.c 调用，设置输入缓冲区
void parser_set_input(const char *input) {
    lexer_init(&g_lexer, input);
    g_initialized = 1;
    g_last_token = 0;
    g_last_token_closed_control = false;
    g_paren_depth = 0;
    g_control_top = 0;
    g_pending_head = 0;
    g_pending_tail = 0;
    g_skip_arrow_detection_once = false;
    g_brace_top = 0;
}

// bison 调用的词法函数
int yylex(void) {
    if (!g_initialized) {
        fprintf(stderr, "[lexer] not initialized\n");
        return 0; // 视为 EOF
    }

    PendingToken queued;
    if (pending_pop(&queued)) {
        if (queued.skip_arrow_detection) {
            g_skip_arrow_detection_once = true;
        }
        if (queued.has_semantic) {
            yylval = queued.semantic;
        } else {
            memset(&yylval, 0, sizeof(yylval));
        }
        if (queued.token != ARROW_HEAD) {
            update_token_state(queued.token);
        }
        return queued.token;
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

        int token_line = tk.line;
        int token_column = tk.column;
        diag_set_last_token_location(token_line, token_column);
        token_free(&tk);

        if (mapped == ASYNC) {
            g_async_allows_function_decl = in_statement_context();
        }

        if (mapped == FUNCTION) {
            bool should_be_decl = in_statement_context() || g_async_allows_function_decl;
            if (should_be_decl) {
                mapped = FUNCTION_DECL;
            }
            g_async_allows_function_decl = false;
        } else if (mapped != ASYNC) {
            g_async_allows_function_decl = false;
        }

        bool skip_detection = g_skip_arrow_detection_once;
        g_skip_arrow_detection_once = false;
        bool arrow_candidate = false;
        if (mapped == '(' && !skip_detection) {
            arrow_candidate = lookahead_is_arrow_head();
        }
        if (arrow_candidate) {
            pending_push('(', &semantic, has_semantic, true);
            mapped = ARROW_HEAD;
            has_semantic = false;
        }

        bool next_starts_function_literal = false;
        if (mapped == '(') {
            next_starts_function_literal = paren_starts_function_literal();
        }

        if (g_last_token == YIELD && newline_before && !newline_allowed_after_yield(mapped, is_eof)) {
            yyerror("LineTerminator not allowed after 'yield'");
        }

        if (should_insert_semicolon(g_last_token, g_last_token_closed_control, g_last_token_closed_function, g_last_token_closed_paren, mapped, newline_before, is_eof, next_starts_function_literal)) {
            pending_push(mapped, &semantic, has_semantic, false);
            update_token_state(';');
            memset(&yylval, 0, sizeof(yylval));
            return ';';
        }

        if (mapped == ARROW && newline_before) {
            yyerror("LineTerminator not allowed before '=>'");
        }

        if (has_semantic) {
            yylval = semantic;
        } else {
            memset(&yylval, 0, sizeof(yylval));
        }

        if (mapped != ARROW_HEAD) {
            update_token_state(mapped);
        }
        return mapped;
    }
}

// bison 的错误回调在 parser.y 中实现，这里不重复实现
