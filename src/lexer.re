/*!re2c
re2c:define:YYCTYPE = char;
re2c:define:YYCURSOR = lexer->cursor;
re2c:define:YYMARKER = lexer->marker;
re2c:yyfill:enable = 0;
re2c:indent:top = 1;
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "token.h"

// 初始化词法分析器
void lexer_init(Lexer *lexer, const char *input) {
    lexer->input = input;
    lexer->cursor = input;
    lexer->marker = input;
    lexer->line = 1;
    lexer->column = 1;
    lexer->has_newline = false;
    lexer->prev_tok_state = PREV_TOK_CAN_REGEX;
}

// 创建 token
static Token make_token(TokenType type, const char *start, const char *end, int line, int column) {
    Token token;
    token.type = type;
    token.line = line;
    token.column = column;
    
    if (start && end && end > start) {
        int len = end - start;
        token.value = (char *)malloc(len + 1);
        strncpy(token.value, start, len);
        token.value[len] = '\0';
    } else {
        token.value = NULL;
    }
    
    return token;
}

// 释放 token
void token_free(Token *token) {
    if (token->value) {
        free(token->value);
        token->value = NULL;
    }
}

static int can_start_regex(Lexer *lexer) {
    return lexer->prev_tok_state == PREV_TOK_CAN_REGEX;
}

// 获取下一个 token
Token lexer_next_token(Lexer *lexer) {
    const char *token_start;
    int token_line = lexer->line;
    int token_column = lexer->column;
    
    // 重置换行标记
    lexer->has_newline = false;
    
    while (1) {
        token_start = lexer->cursor;
        token_line = lexer->line;
        token_column = lexer->column;
        
        /*!re2c
        // 空白字符（非换行）
        [ \t\r]+ {
            lexer->column += (lexer->cursor - token_start);
            continue;
        }
        
        // 换行符
        "\n" {
            lexer->line++;
            lexer->column = 1;
            lexer->has_newline = true;
            continue;
        }
        
        // 单行注释
        "//" [^\n]* {
            lexer->column += (lexer->cursor - token_start);
            continue;
        }
        
        // 多行注释
        "/*" {
            const char *comment_start = lexer->cursor;
            while (*lexer->cursor) {
                if (lexer->cursor[0] == '*' && lexer->cursor[1] == '/') {
                    lexer->cursor += 2;
                    break;
                }
                if (*lexer->cursor == '\n') {
                    lexer->line++;
                    lexer->column = 1;
                    lexer->has_newline = true;
                } else {
                    lexer->column++;
                }
                lexer->cursor++;
            }
            continue;
        }
        
        // 关键字
        "var"        { lexer->column += 3; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_VAR, token_start, lexer->cursor, token_line, token_column); }
        "let"        { lexer->column += 3; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_LET, token_start, lexer->cursor, token_line, token_column); }
        "const"      { lexer->column += 5; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_CONST, token_start, lexer->cursor, token_line, token_column); }
        "function"   { lexer->column += 8; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_FUNCTION, token_start, lexer->cursor, token_line, token_column); }
        "if"         { lexer->column += 2; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_IF, token_start, lexer->cursor, token_line, token_column); }
        "else"       { lexer->column += 4; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_ELSE, token_start, lexer->cursor, token_line, token_column); }
        "for"        { lexer->column += 3; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_FOR, token_start, lexer->cursor, token_line, token_column); }
        "while"      { lexer->column += 5; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_WHILE, token_start, lexer->cursor, token_line, token_column); }
        "do"         { lexer->column += 2; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_DO, token_start, lexer->cursor, token_line, token_column); }
        "return"     { lexer->column += 6; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_RETURN, token_start, lexer->cursor, token_line, token_column); }
        "break"      { lexer->column += 5; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_BREAK, token_start, lexer->cursor, token_line, token_column); }
        "continue"   { lexer->column += 8; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_CONTINUE, token_start, lexer->cursor, token_line, token_column); }
        "switch"     { lexer->column += 6; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_SWITCH, token_start, lexer->cursor, token_line, token_column); }
        "case"       { lexer->column += 4; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_CASE, token_start, lexer->cursor, token_line, token_column); }
        "default"    { lexer->column += 7; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_DEFAULT, token_start, lexer->cursor, token_line, token_column); }
        "try"        { lexer->column += 3; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_TRY, token_start, lexer->cursor, token_line, token_column); }
        "catch"      { lexer->column += 5; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_CATCH, token_start, lexer->cursor, token_line, token_column); }
        "finally"    { lexer->column += 7; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_FINALLY, token_start, lexer->cursor, token_line, token_column); }
        "throw"      { lexer->column += 5; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_THROW, token_start, lexer->cursor, token_line, token_column); }
        "new"        { lexer->column += 3; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_NEW, token_start, lexer->cursor, token_line, token_column); }
        "this"       { lexer->column += 4; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_THIS, token_start, lexer->cursor, token_line, token_column); }
        "typeof"     { lexer->column += 6; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_TYPEOF, token_start, lexer->cursor, token_line, token_column); }
        "delete"     { lexer->column += 6; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_DELETE, token_start, lexer->cursor, token_line, token_column); }
        "in"         { lexer->column += 2; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_IN, token_start, lexer->cursor, token_line, token_column); }
        "instanceof" { lexer->column += 10; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_INSTANCEOF, token_start, lexer->cursor, token_line, token_column); }
        "void"       { lexer->column += 4; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_VOID, token_start, lexer->cursor, token_line, token_column); }
        "with"       { lexer->column += 4; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_WITH, token_start, lexer->cursor, token_line, token_column); }
        "debugger"   { lexer->column += 8; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_DEBUGGER, token_start, lexer->cursor, token_line, token_column); }
        
        // 字面量
        "true"       { lexer->column += 4; lexer->prev_tok_state = PREV_TOK_NO_REGEX; return make_token(TOK_TRUE, token_start, lexer->cursor, token_line, token_column); }
        "false"      { lexer->column += 5; lexer->prev_tok_state = PREV_TOK_NO_REGEX; return make_token(TOK_FALSE, token_start, lexer->cursor, token_line, token_column); }
        "null"       { lexer->column += 4; lexer->prev_tok_state = PREV_TOK_NO_REGEX; return make_token(TOK_NULL, token_start, lexer->cursor, token_line, token_column); }
        "undefined"  { lexer->column += 9; lexer->prev_tok_state = PREV_TOK_NO_REGEX; return make_token(TOK_UNDEFINED, token_start, lexer->cursor, token_line, token_column); }
        
        // 数字字面量（整数、浮点数、科学计数法）（ES5严格模式禁止前导零）
        // 无小数/指数的十进制（单个0，或1-9开头）
        ( "0" | [1-9] [0-9]* ) {
            lexer->column += (lexer->cursor - token_start);
            lexer->prev_tok_state = PREV_TOK_NO_REGEX;
            return make_token(TOK_NUMBER, token_start, lexer->cursor, token_line, token_column);
        }

        // 带小数/指数的十进制
        ( ( "0" | [1-9] [0-9]* ) "." [0-9]* | "." [0-9]+ ) ( [eE] [+-]? [0-9]+ )? {
            lexer->column += (lexer->cursor - token_start);
            lexer->prev_tok_state = PREV_TOK_NO_REGEX;
            return make_token(TOK_NUMBER, token_start, lexer->cursor, token_line, token_column);
        }
        
        // 十六进制数字
        "0" [xX] [0-9a-fA-F]+ {
            lexer->column += (lexer->cursor - token_start);
            lexer->prev_tok_state = PREV_TOK_NO_REGEX;
            return make_token(TOK_NUMBER, token_start, lexer->cursor, token_line, token_column);
        }
        
        // 字符串字面量（双引号）
        ["] {
            const char *str_start = lexer->cursor - 1;
            while (*lexer->cursor && *lexer->cursor != '"') {
                if (*lexer->cursor == '\\' && lexer->cursor[1]) {
                    lexer->cursor++;
                    lexer->column++;
                }
                if (*lexer->cursor == '\n') {
                    lexer->line++;
                    lexer->column = 1;
                } else {
                    lexer->column++;
                }
                lexer->cursor++;
            }
            if (*lexer->cursor == '"') {
                lexer->cursor++;
                lexer->column++;
            }
            lexer->prev_tok_state = PREV_TOK_NO_REGEX;
            return make_token(TOK_STRING, str_start, lexer->cursor, token_line, token_column);
        }
        
        // 字符串字面量（单引号）
        ['] {
            const char *str_start = lexer->cursor - 1;
            while (*lexer->cursor && *lexer->cursor != '\'') {
                if (*lexer->cursor == '\\' && lexer->cursor[1]) {
                    lexer->cursor++;
                    lexer->column++;
                }
                if (*lexer->cursor == '\n') {
                    lexer->line++;
                    lexer->column = 1;
                } else {
                    lexer->column++;
                }
                lexer->cursor++;
            }
            if (*lexer->cursor == '\'') {
                lexer->cursor++;
                lexer->column++;
            }
            lexer->prev_tok_state = PREV_TOK_NO_REGEX;
            return make_token(TOK_STRING, str_start, lexer->cursor, token_line, token_column);
        }

        // 正则表达字面量
        "/"  ([^/\\\r\n] | "\\" (. | "\n"))*  "/" [gimsuy]* {
            if (can_start_regex(lexer)) {
                lexer->column += (lexer->cursor - token_start);
                lexer->prev_tok_state = PREV_TOK_NO_REGEX;
                return make_token(TOK_REGEX, token_start, lexer->cursor, token_line, token_column);
            }
            lexer->cursor = token_start;
            goto slash_as_div;
        }
        
        // 标识符（支持 Unicode）
        [a-zA-Z_$][a-zA-Z0-9_$]* {
            lexer->column += (lexer->cursor - token_start);
            lexer->prev_tok_state = PREV_TOK_CAN_REGEX;
            return make_token(TOK_IDENTIFIER, token_start, lexer->cursor, token_line, token_column);
        }
        
        // 三字符运算符
        ">>>="|"==="|"!==" {
            lexer->column += lexer->cursor - token_start;;
            lexer->prev_tok_state = PREV_TOK_CAN_REGEX;
            if (strncmp(token_start, ">>>=", 4) == 0) return make_token(TOK_URSHIFT_ASSIGN, NULL, NULL, token_line, token_column);
            if (strncmp(token_start, "===", 3) == 0) return make_token(TOK_EQ_STRICT, NULL, NULL, token_line, token_column);
            if (strncmp(token_start, "!==", 3) == 0) return make_token(TOK_NE_STRICT, NULL, NULL, token_line, token_column);
        }
        
        // 双字符运算符（除除法符号）
        "++"|"--"|"<<"|">>"|">>>"|"<="|">="|"=="|"!="|"&&"|"||"|
        "+="|"-="|"*="|"/="|"%="|"&="|"|="|"^="|"<<="|">>=" {
            int len = lexer->cursor - token_start;
            lexer->column += len;
            lexer->prev_tok_state = PREV_TOK_CAN_REGEX;
            
            if (strncmp(token_start, "++", 2) == 0) return make_token(TOK_PLUS_PLUS, NULL, NULL, token_line, token_column);
            if (strncmp(token_start, "--", 2) == 0) return make_token(TOK_MINUS_MINUS, NULL, NULL, token_line, token_column);
            if (strncmp(token_start, "<<", 2) == 0) return make_token(TOK_LSHIFT, NULL, NULL, token_line, token_column);
            if (strncmp(token_start, ">>", 2) == 0) return make_token(TOK_RSHIFT, NULL, NULL, token_line, token_column);
            if (strncmp(token_start, ">>>", 3) == 0) return make_token(TOK_URSHIFT, NULL, NULL, token_line, token_column);
            if (strncmp(token_start, "<=", 2) == 0) return make_token(TOK_LE, NULL, NULL, token_line, token_column);
            if (strncmp(token_start, ">=", 2) == 0) return make_token(TOK_GE, NULL, NULL, token_line, token_column);
            if (strncmp(token_start, "==", 2) == 0) return make_token(TOK_EQ, NULL, NULL, token_line, token_column);
            if (strncmp(token_start, "!=", 2) == 0) return make_token(TOK_NE, NULL, NULL, token_line, token_column);
            if (strncmp(token_start, "&&", 2) == 0) return make_token(TOK_AND, NULL, NULL, token_line, token_column);
            if (strncmp(token_start, "||", 2) == 0) return make_token(TOK_OR, NULL, NULL, token_line, token_column);
            if (strncmp(token_start, "+=", 2) == 0) return make_token(TOK_PLUS_ASSIGN, NULL, NULL, token_line, token_column);
            if (strncmp(token_start, "-=", 2) == 0) return make_token(TOK_MINUS_ASSIGN, NULL, NULL, token_line, token_column);
            if (strncmp(token_start, "*=", 2) == 0) return make_token(TOK_STAR_ASSIGN, NULL, NULL, token_line, token_column);
            if (strncmp(token_start, "/=", 2) == 0) return make_token(TOK_SLASH_ASSIGN, NULL, NULL, token_line, token_column);
            if (strncmp(token_start, "%=", 2) == 0) return make_token(TOK_PERCENT_ASSIGN, NULL, NULL, token_line, token_column);
            if (strncmp(token_start, "&=", 2) == 0) return make_token(TOK_AND_ASSIGN, NULL, NULL, token_line, token_column);
            if (strncmp(token_start, "|=", 2) == 0) return make_token(TOK_OR_ASSIGN, NULL, NULL, token_line, token_column);
            if (strncmp(token_start, "^=", 2) == 0) return make_token(TOK_XOR_ASSIGN, NULL, NULL, token_line, token_column);
            if (strncmp(token_start, "<<=", 3) == 0) return make_token(TOK_LSHIFT_ASSIGN, NULL, NULL, token_line, token_column);
            if (strncmp(token_start, ">>=", 3) == 0) return make_token(TOK_RSHIFT_ASSIGN, NULL, NULL, token_line, token_column);
        }
        
        // 单字符运算符和分隔符（除除法符号）
        "+" { lexer->column++; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_PLUS, NULL, NULL, token_line, token_column); }
        "-" { lexer->column++; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_MINUS, NULL, NULL, token_line, token_column); }
        "*" { lexer->column++; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_STAR, NULL, NULL, token_line, token_column); }
        "/" { lexer->column++; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_SLASH, NULL, NULL, token_line, token_column); }
        "%" { lexer->column++; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_PERCENT, NULL, NULL, token_line, token_column); }
        "=" { lexer->column++; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_ASSIGN, NULL, NULL, token_line, token_column); }
        "<" { lexer->column++; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_LT, NULL, NULL, token_line, token_column); }
        ">" { lexer->column++; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_GT, NULL, NULL, token_line, token_column); }
        "!" { lexer->column++; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_NOT, NULL, NULL, token_line, token_column); }
        "&" { lexer->column++; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_BIT_AND, NULL, NULL, token_line, token_column); }
        "|" { lexer->column++; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_BIT_OR, NULL, NULL, token_line, token_column); }
        "^" { lexer->column++; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_BIT_XOR, NULL, NULL, token_line, token_column); }
        "~" { lexer->column++; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_BIT_NOT, NULL, NULL, token_line, token_column); }
        "?" { lexer->column++; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_QUESTION, NULL, NULL, token_line, token_column); }
        ":" { lexer->column++; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_COLON, NULL, NULL, token_line, token_column); }
        "(" { lexer->column++; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_LPAREN, NULL, NULL, token_line, token_column); }
        ")" { lexer->column++; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_RPAREN, NULL, NULL, token_line, token_column); }
        "{" { lexer->column++; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_LBRACE, NULL, NULL, token_line, token_column); }
        "}" { lexer->column++; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_RBRACE, NULL, NULL, token_line, token_column); }
        "[" { lexer->column++; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_LBRACKET, NULL, NULL, token_line, token_column); }
        "]" { lexer->column++; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_RBRACKET, NULL, NULL, token_line, token_column); }
        ";" { lexer->column++; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_SEMICOLON, NULL, NULL, token_line, token_column); }
        "," { lexer->column++; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_COMMA, NULL, NULL, token_line, token_column); }
        "." { lexer->column++; lexer->prev_tok_state = PREV_TOK_CAN_REGEX; return make_token(TOK_DOT, NULL, NULL, token_line, token_column); }
        
        // 文件结束
        "\x00" { return make_token(TOK_EOF, NULL, NULL, token_line, token_column); }
        
        // 错误：未识别的字符
        * {
            lexer->column++;
            lexer->prev_tok_state = PREV_TOK_NO_REGEX;
            return make_token(TOK_ERROR, token_start, lexer->cursor, token_line, token_column);
        }
        */
        slash_as_div:
            if (lexer->cursor + 1 <= lexer->input + strlen(lexer->input) &&
                lexer->cursor[0] == '/' && lexer->cursor[1] == '=') {
                // 匹配 /=
                lexer->column += 2;
                Token tok = make_token(TOK_SLASH_ASSIGN, NULL, NULL, token_line, token_column);
                lexer->prev_tok_state = PREV_TOK_CAN_REGEX;
                lexer->cursor += 2;
                return tok;
            } else if (lexer->cursor < lexer->input + strlen(lexer->input) &&
                       lexer->cursor[0] == '/') {
                // 匹配 /
                lexer->column++;
                Token tok = make_token(TOK_SLASH, NULL, NULL, token_line, token_column);
                lexer->prev_tok_state = PREV_TOK_CAN_REGEX;
                lexer->cursor++;
                return tok;
            } else {
                lexer->column++;
                lexer->cursor++;
                return make_token(TOK_ERROR, token_start, lexer->cursor, token_line, token_column);
            }
    }
}

// Token 类型转字符串
const char *token_type_to_string(TokenType type) {
    switch (type) {
        case TOK_VAR: return "VAR";
        case TOK_LET: return "LET";
        case TOK_CONST: return "CONST";
        case TOK_FUNCTION: return "FUNCTION";
        case TOK_IF: return "IF";
        case TOK_ELSE: return "ELSE";
        case TOK_FOR: return "FOR";
        case TOK_WHILE: return "WHILE";
        case TOK_DO: return "DO";
        case TOK_RETURN: return "RETURN";
        case TOK_BREAK: return "BREAK";
        case TOK_CONTINUE: return "CONTINUE";
        case TOK_SWITCH: return "SWITCH";
        case TOK_CASE: return "CASE";
        case TOK_DEFAULT: return "DEFAULT";
        case TOK_TRY: return "TRY";
        case TOK_CATCH: return "CATCH";
        case TOK_FINALLY: return "FINALLY";
        case TOK_THROW: return "THROW";
        case TOK_NEW: return "NEW";
        case TOK_THIS: return "THIS";
        case TOK_TYPEOF: return "TYPEOF";
        case TOK_DELETE: return "DELETE";
        case TOK_IN: return "IN";
        case TOK_INSTANCEOF: return "INSTANCEOF";
        case TOK_VOID: return "VOID";
        case TOK_WITH: return "WITH";
        case TOK_DEBUGGER: return "DEBUGGER";
        case TOK_TRUE: return "TRUE";
        case TOK_FALSE: return "FALSE";
        case TOK_NULL: return "NULL";
        case TOK_UNDEFINED: return "UNDEFINED";
        case TOK_NUMBER: return "NUMBER";
        case TOK_STRING: return "STRING";
        case TOK_REGEX: return "REGEX";
        case TOK_IDENTIFIER: return "IDENTIFIER";
        case TOK_PLUS: return "+";
        case TOK_MINUS: return "-";
        case TOK_STAR: return "*";
        case TOK_SLASH: return "/";
        case TOK_PERCENT: return "%";
        case TOK_PLUS_PLUS: return "++";
        case TOK_MINUS_MINUS: return "--";
        case TOK_ASSIGN: return "=";
        case TOK_PLUS_ASSIGN: return "+=";
        case TOK_MINUS_ASSIGN: return "-=";
        case TOK_STAR_ASSIGN: return "*=";
        case TOK_SLASH_ASSIGN: return "/=";
        case TOK_PERCENT_ASSIGN: return "%=";
        case TOK_EQ: return "==";
        case TOK_NE: return "!=";
        case TOK_EQ_STRICT: return "===";
        case TOK_NE_STRICT: return "!==";
        case TOK_LT: return "<";
        case TOK_LE: return "<=";
        case TOK_GT: return ">";
        case TOK_GE: return ">=";
        case TOK_AND: return "&&";
        case TOK_OR: return "||";
        case TOK_NOT: return "!";
        case TOK_BIT_AND: return "&";
        case TOK_BIT_OR: return "|";
        case TOK_BIT_XOR: return "^";
        case TOK_BIT_NOT: return "~";
        case TOK_LSHIFT: return "<<";
        case TOK_RSHIFT: return ">>";
        case TOK_URSHIFT: return ">>>";
        case TOK_AND_ASSIGN: return "&=";
        case TOK_OR_ASSIGN: return "|=";
        case TOK_XOR_ASSIGN: return "^=";
        case TOK_LSHIFT_ASSIGN: return "<<=";
        case TOK_RSHIFT_ASSIGN: return ">>=";
        case TOK_URSHIFT_ASSIGN: return ">>>=";
        case TOK_QUESTION: return "?";
        case TOK_COLON: return ":";
        case TOK_LPAREN: return "(";
        case TOK_RPAREN: return ")";
        case TOK_LBRACE: return "{";
        case TOK_RBRACE: return "}";
        case TOK_LBRACKET: return "[";
        case TOK_RBRACKET: return "]";
        case TOK_SEMICOLON: return ";";
        case TOK_COMMA: return ",";
        case TOK_DOT: return ".";
        case TOK_EOF: return "EOF";
        case TOK_ERROR: return "ERROR";
        case TOK_NEWLINE: return "NEWLINE";
        default: return "UNKNOWN";
    }
}
