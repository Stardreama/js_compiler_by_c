#ifndef TOKEN_H
#define TOKEN_H

#include <stdbool.h>

// Token 类型枚举
typedef enum
{
    // 关键字
    TOK_VAR,
    TOK_LET,
    TOK_CONST,
    TOK_FUNCTION,
    TOK_IF,
    TOK_ELSE,
    TOK_FOR,
    TOK_WHILE,
    TOK_DO,
    TOK_RETURN,
    TOK_BREAK,
    TOK_CONTINUE,
    TOK_SWITCH,
    TOK_CASE,
    TOK_DEFAULT,
    TOK_TRY,
    TOK_CATCH,
    TOK_FINALLY,
    TOK_THROW,
    TOK_NEW,
    TOK_THIS,
    TOK_TYPEOF,
    TOK_DELETE,
    TOK_IN,
    TOK_INSTANCEOF,
    TOK_VOID,
    TOK_WITH,
    TOK_DEBUGGER,

    // 字面量
    TOK_TRUE,
    TOK_FALSE,
    TOK_NULL,
    TOK_UNDEFINED,
    TOK_NUMBER,
    TOK_STRING,
    TOK_REGEX,
    TOK_IDENTIFIER,

    // 运算符
    TOK_PLUS,        // +
    TOK_MINUS,       // -
    TOK_STAR,        // *
    TOK_SLASH,       // /
    TOK_PERCENT,     // %
    TOK_PLUS_PLUS,   // ++
    TOK_MINUS_MINUS, // --

    TOK_ASSIGN,         // =
    TOK_PLUS_ASSIGN,    // +=
    TOK_MINUS_ASSIGN,   // -=
    TOK_STAR_ASSIGN,    // *=
    TOK_SLASH_ASSIGN,   // /=
    TOK_PERCENT_ASSIGN, // %=

    TOK_EQ,        // ==
    TOK_NE,        // !=
    TOK_EQ_STRICT, // ===
    TOK_NE_STRICT, // !==
    TOK_LT,        // <
    TOK_LE,        // <=
    TOK_GT,        // >
    TOK_GE,        // >=

    TOK_AND, // &&
    TOK_OR,  // ||
    TOK_NOT, // !

    TOK_BIT_AND, // &
    TOK_BIT_OR,  // |
    TOK_BIT_XOR, // ^
    TOK_BIT_NOT, // ~
    TOK_LSHIFT,  // <<
    TOK_RSHIFT,  // >>
    TOK_URSHIFT, // >>>

    TOK_AND_ASSIGN,     // &=
    TOK_OR_ASSIGN,      // |=
    TOK_XOR_ASSIGN,     // ^=
    TOK_LSHIFT_ASSIGN,  // <<=
    TOK_RSHIFT_ASSIGN,  // >>=
    TOK_URSHIFT_ASSIGN, // >>>=

    TOK_QUESTION, // ?
    TOK_COLON,    // :

    // 分隔符
    TOK_LPAREN,    // (
    TOK_RPAREN,    // )
    TOK_LBRACE,    // {
    TOK_RBRACE,    // }
    TOK_LBRACKET,  // [
    TOK_RBRACKET,  // ]
    TOK_SEMICOLON, // ;
    TOK_COMMA,     // ,
    TOK_DOT,       // .

    // 特殊 token
    TOK_EOF,
    TOK_ERROR,
    TOK_NEWLINE // 用于 ASI 机制
} TokenType;

// 记录前一个Token类型
typedef enum {
    PREV_TOK_CAN_REGEX,  // 前一个Token允许后续跟正则（关键词/标识符/标点/EOF）
    PREV_TOK_NO_REGEX    // 前一个Token不允许后续跟正则（数字/字符串/正则等）
} PrevTokenState;

// Token 结构体
typedef struct
{
    TokenType type;
    char *value; // token 的字符串值（对于标识符、数字、字符串）
    int line;    // 行号
    int column;  // 列号
} Token;

// 词法分析器状态
typedef struct
{
    const char *input;  // 输入字符串
    const char *cursor; // 当前位置
    const char *marker; // re2c 使用的标记
    int line;           // 当前行号
    int column;         // 当前列号
    bool has_newline;   // 自上次 token 以来是否有换行（用于 ASI）
    PrevTokenState prev_tok_state; // 前Token状态
} Lexer;

// 函数声明
void lexer_init(Lexer *lexer, const char *input);
Token lexer_next_token(Lexer *lexer);
void token_free(Token *token);
const char *token_type_to_string(TokenType type);

#endif // TOKEN_H
