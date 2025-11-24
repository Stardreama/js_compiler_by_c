#ifndef AST_H
#define AST_H

#include <stdbool.h>
#include <stddef.h>

typedef enum
{
    AST_PROGRAM,
    AST_BLOCK,
    AST_VAR_DECL,
    AST_FUNCTION_DECL,
    AST_RETURN_STMT,
    AST_IF_STMT,
    AST_FOR_STMT,
    AST_WHILE_STMT,
    AST_DO_WHILE_STMT,
    AST_SWITCH_STMT,
    AST_TRY_STMT,
    AST_WITH_STMT,
    AST_LABELED_STMT,
    AST_BREAK_STMT,
    AST_CONTINUE_STMT,
    AST_THROW_STMT,
    AST_EXPR_STMT,
    AST_EMPTY_STMT,
    AST_IDENTIFIER,
    AST_LITERAL,
    AST_ASSIGN_EXPR,
    AST_BINARY_EXPR,
    AST_CONDITIONAL_EXPR,
    AST_SEQUENCE_EXPR,
    AST_UNARY_EXPR,
    AST_UPDATE_EXPR,
    AST_CALL_EXPR,
    AST_MEMBER_EXPR,
    AST_ARRAY_LITERAL,
    AST_OBJECT_LITERAL,
    AST_PROPERTY,
    AST_SWITCH_CASE,
    AST_CATCH_CLAUSE
} ASTNodeType;

typedef enum
{
    AST_VAR_KIND_VAR,
    AST_VAR_KIND_LET,
    AST_VAR_KIND_CONST
} ASTVarKind;

typedef enum
{
    AST_LITERAL_NUMBER,
    AST_LITERAL_STRING,
    AST_LITERAL_REGEX,
    AST_LITERAL_BOOLEAN,
    AST_LITERAL_NULL,
    AST_LITERAL_UNDEFINED
} ASTLiteralType;

typedef struct ASTNode ASTNode;

typedef struct ASTList
{
    ASTNode *node;
    struct ASTList *next;
} ASTList;

typedef struct
{
    char *name;
    bool is_identifier;
} ASTPropertyKey;

struct ASTNode
{
    ASTNodeType type;
    union
    {
        struct
        {
            ASTList *body;
        } program;
        struct
        {
            ASTList *body;
        } block;
        struct
        {
            ASTVarKind kind;
            char *name;
            ASTNode *init;
        } var_decl;
        struct
        {
            char *name;
            ASTList *params;
            ASTNode *body;
        } function_decl;
        struct
        {
            ASTNode *argument;
        } return_stmt;
        struct
        {
            ASTNode *test;
            ASTNode *consequent;
            ASTNode *alternate;
        } if_stmt;
        struct
        {
            ASTNode *init;
            ASTNode *test;
            ASTNode *update;
            ASTNode *body;
        } for_stmt;
        struct
        {
            ASTNode *test;
            ASTNode *body;
        } while_stmt;
        struct
        {
            ASTNode *body;
            ASTNode *test;
        } do_while_stmt;
        struct
        {
            ASTNode *discriminant;
            ASTList *cases;
        } switch_stmt;
        struct
        {
            ASTNode *block;
            ASTNode *handler;
            ASTNode *finalizer;
        } try_stmt;
        struct
        {
            ASTNode *object;
            ASTNode *body;
        } with_stmt;
        struct
        {
            char *label;
            ASTNode *body;
        } labeled_stmt;
        struct
        {
            char *label;
        } break_stmt;
        struct
        {
            char *label;
        } continue_stmt;
        struct
        {
            ASTNode *argument;
        } throw_stmt;
        struct
        {
            ASTNode *expression;
        } expr_stmt;
        struct
        {
            char *name;
        } identifier;
        struct
        {
            ASTLiteralType literal_type;
            union
            {
                double number;
                bool boolean;
                char *string;
            } value;
        } literal;
        struct
        {
            const char *op;
            ASTNode *left;
            ASTNode *right;
        } binary;
        struct
        {
            ASTNode *test;
            ASTNode *consequent;
            ASTNode *alternate;
        } conditional;
        struct
        {
            ASTList *elements;
        } sequence;
        struct
        {
            const char *op;
            ASTNode *left;
            ASTNode *right;
        } assign;
        struct
        {
            const char *op;
            ASTNode *argument;
        } unary;
        struct
        {
            const char *op;
            ASTNode *argument;
            bool prefix;
        } update;
        struct
        {
            ASTNode *callee;
            ASTList *arguments;
        } call_expr;
        struct
        {
            ASTNode *object;
            char *property;
            bool computed;
        } member_expr;
        struct
        {
            ASTList *elements;
        } array_literal;
        struct
        {
            ASTList *properties;
        } object_literal;
        struct
        {
            ASTPropertyKey key;
            ASTNode *value;
        } property;
        struct
        {
            ASTNode *test;
            ASTList *consequent;
            bool is_default;
        } switch_case;
        struct
        {
            char *param;
            ASTNode *body;
        } catch_clause;
    } data;
};

typedef void (*ASTVisitFn)(ASTNode *node, void *userdata);

ASTList *ast_list_append(ASTList *list, ASTNode *node);
ASTList *ast_list_concat(ASTList *head, ASTList *tail);
void ast_list_free(ASTList *list);

ASTNode *ast_make_program(ASTList *body);
ASTNode *ast_make_block(ASTList *body);
ASTNode *ast_make_var_decl(ASTVarKind kind, char *name, ASTNode *init);
ASTNode *ast_make_function_decl(char *name, ASTList *params, ASTNode *body);
ASTNode *ast_make_return(ASTNode *argument);
ASTNode *ast_make_if(ASTNode *test, ASTNode *consequent, ASTNode *alternate);
ASTNode *ast_make_for(ASTNode *init, ASTNode *test, ASTNode *update, ASTNode *body);
ASTNode *ast_make_while(ASTNode *test, ASTNode *body);
ASTNode *ast_make_do_while(ASTNode *body, ASTNode *test);
ASTNode *ast_make_switch(ASTNode *discriminant, ASTList *cases);
ASTNode *ast_make_switch_case(ASTNode *test, ASTList *consequent);
ASTNode *ast_make_switch_default(ASTList *consequent);
ASTNode *ast_make_try(ASTNode *block, ASTNode *handler, ASTNode *finalizer);
ASTNode *ast_make_catch(char *param, ASTNode *body);
ASTNode *ast_make_with(ASTNode *object, ASTNode *body);
ASTNode *ast_make_labeled(char *label, ASTNode *body);
ASTNode *ast_make_break(char *label);
ASTNode *ast_make_continue(char *label);
ASTNode *ast_make_throw(ASTNode *argument);
ASTNode *ast_make_expression_stmt(ASTNode *expression);
ASTNode *ast_make_empty_statement(void);
ASTNode *ast_make_identifier(char *name);
ASTNode *ast_make_number_literal(char *raw);
ASTNode *ast_make_string_literal(char *raw);
ASTNode *ast_make_regex_literal(char *raw);
ASTNode *ast_make_boolean_literal(bool value);
ASTNode *ast_make_null_literal(void);
ASTNode *ast_make_undefined_literal(void);
ASTNode *ast_make_assignment(const char *op, ASTNode *left, ASTNode *right);
ASTNode *ast_make_binary(const char *op, ASTNode *left, ASTNode *right);
ASTNode *ast_make_conditional(ASTNode *test, ASTNode *consequent, ASTNode *alternate);
ASTNode *ast_make_sequence(ASTNode *left, ASTNode *right);
ASTNode *ast_make_unary(const char *op, ASTNode *argument);
ASTNode *ast_make_update(const char *op, ASTNode *argument, bool prefix);
ASTNode *ast_make_call(ASTNode *callee, ASTList *arguments);
ASTNode *ast_make_member(ASTNode *object, char *property, bool computed);
ASTNode *ast_make_array_literal(ASTList *elements);
ASTNode *ast_make_object_literal(ASTList *properties);
ASTNode *ast_make_property(char *key, bool is_identifier, ASTNode *value);

void ast_traverse(ASTNode *node, ASTVisitFn visitor, void *userdata);
void ast_print(const ASTNode *node);
void ast_free(ASTNode *node);

#endif /* AST_H */
